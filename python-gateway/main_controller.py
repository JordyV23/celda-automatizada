from coppeliasim_zmqremoteapi_client import RemoteAPIClient
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS
from pymodbus.client import ModbusTcpClient
from scipy.stats import truncnorm
import json
import paho.mqtt.client as mqtt
import random
import time
import traceback

ZMQ_HOST = 'host.docker.internal' 
PLC_HOST = 'openplc'
MQTT_HOST = 'mosquitto'

INFLUX_URL = "http://influxdb:8086"
INFLUX_TOKEN = "-9_nL8KgtuINmtqGbXQ3172mnf22a2e8tHpCHX708xEs9T7z-VnzdEts1Hd9cNJJbFyEcLgn2UoatO1UQCxYkQ=="
INFLUX_ORG = "celda_org"
INFLUX_BUCKET = "binning_data"

def get_truncated_normal(mean, sd, low, upp):
    return truncnorm((low - mean) / sd, (upp - mean) / sd, loc=mean, scale=sd)

def simulate_ate_test():
    rds_gen = get_truncated_normal(mean=10.0, sd=1.5, low=7.0, upp=15.0)
    vth_gen = get_truncated_normal(mean=3.0, sd=0.3, low=2.0, upp=4.0)
    return {
        "RDS_on": round(rds_gen.rvs(), 2),
        "V_th": round(vth_gen.rvs(), 2),
        "I_DSS": round(random.uniform(0.1, 1.0), 3)
    }

def main():
    # flush=True fuerza a Python a enviar el texto a los logs de Docker inmediatamente
    print("Iniciando Gateway Python...", flush=True)
    
    try:
        # 1. ZMQ
        print(f"1. Conectando a CoppeliaSim en {ZMQ_HOST}...", flush=True)
        client_zmq = RemoteAPIClient(ZMQ_HOST)
        sim = client_zmq.require('sim')
        print("-> OK: Conectado a CoppeliaSim.", flush=True)

        # 2. Modbus
        print(f"2. Conectando a OpenPLC en {PLC_HOST}...", flush=True)
        plc_client = ModbusTcpClient(PLC_HOST, port=502)
        plc_conn = plc_client.connect()
        if not plc_conn:
            print("-> ERROR: No se pudo conectar a OpenPLC (Revisa que el contenedor esté corriendo).", flush=True)
        else:
            print("-> OK: Conectado a OpenPLC.", flush=True)

        # 3. MQTT
        print(f"3. Conectando a MQTT en {MQTT_HOST}...", flush=True)
        mqtt_client = mqtt.Client()
        mqtt_client.connect(MQTT_HOST, 1883, 60)
        mqtt_client.loop_start()
        print("-> OK: Conectado a MQTT.", flush=True)

        print("\n--- INICIANDO BUCLE DE CONTROL ---", flush=True)
        # --- Obtener Handles de CoppeliaSim ---
        robot_target = sim.getObject('/IRB140/manipulationSphere/target')
        wp_reposo = sim.getObject('/Waypoint_Reposo')
        wp_feeder = sim.getObject('/Waypoint_Feeder')
        wp_ate = sim.getObject('/Waypoint_ATE')
        wp_bina = sim.getObject('/Waypoint_BinA')
        wp_scrap = sim.getObject('/Waypoint_Scrap')

        def mover_robot(waypoint_handle):
            """Lee la posición del Dummy y teletransporta el Target ahí"""
            # Leer SOLO la posición (X,Y,Z) del Dummy respecto al mundo
            pos = sim.getObjectPosition(waypoint_handle, sim.handle_world)
            
            # Aplicar SOLO la posición al Target del robot (mantiene su orientación original)
            sim.setObjectPosition(robot_target, sim.handle_world, pos)
            
            time.sleep(1.5) # Tiempo simulado para que el brazo llegue físicamente

        print("\n--- INICIANDO BUCLE DE CONTROL Y MOVIMIENTO ---", flush=True)
        mover_robot(wp_reposo) # Iniciar en posición segura

        while True:
            # 1. Búsqueda de Pieza
            print("Moviendo a Feeder para recoger pieza...", flush=True)
            mover_robot(wp_feeder)
            
            # 2. Mover a ATE
            print("Moviendo a estación ATE...", flush=True)
            mover_robot(wp_ate)
            
            # 3. Prueba ATE (Comunicación Modbus con PLC)
            if plc_conn:
                mosfet_data = simulate_ate_test()
                rds_modbus = int(mosfet_data["RDS_on"] * 100)
                vth_modbus = int(mosfet_data["V_th"] * 100)
                
                # Escribir registros al PLC
                plc_client.write_register(0, rds_modbus)
                plc_client.write_register(1, vth_modbus)
                plc_client.write_coil(3, True) # Simular Sensor_ATE ON
                
                # Publicar en MQTT
                mqtt_client.publish("celda/ate/resultados", json.dumps(mosfet_data))
                print(f"Prueba ATE: {mosfet_data}", flush=True)

                # Darle 0.5s al PLC para procesar la lógica SFC
                time.sleep(0.5)
                
                # Leer la respuesta del PLC (Bobinas 11 a 14)
                # %QX1.3 = Coil 11 (BinA), %QX1.6 = Coil 14 (Scrap)
                respuesta_plc = plc_client.read_coils(11, 4)
                
                if respuesta_plc.bits[0]: # BinA es TRUE
                    categoria_final = "Grado A"
                    print("-> PLC DECIDE: GRADO A. Moviendo a bandeja.", flush=True)
                    mover_robot(wp_bina)
                elif respuesta_plc.bits[3]: # Scrap es TRUE
                    categoria_final = "Scrap"
                    print("-> PLC DECIDE: SCRAP. Descartando pieza.", flush=True)
                    mover_robot(wp_scrap)
                else:
                    categoria_final = "No Clasificado"
                    print("-> PLC DECIDE: Sin clasificar. Devolviendo a Reposo.", flush=True)
                    mover_robot(wp_reposo)

                # NUEVO: Guardar métricas en InfluxDB
                try:
                    client_influx = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)
                    write_api = client_influx.write_api(write_options=SYNCHRONOUS)

                    punto = Point("clasificacion_mosfet") \
                        .tag("categoria", categoria_final) \
                        .field("rds_on", mosfet_data["RDS_on"]) \
                        .field("v_th", mosfet_data["V_th"]) \
                        .field("i_dss", mosfet_data["I_DSS"])

                    write_api.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=punto)
                    print("-> Dato guardado en InfluxDB correctamente.", flush=True)
                    client_influx.close()
                except Exception as db_err:
                    print(f"Error al guardar en BD: {db_err}", flush=True)
                
                # Limpiar sensor ATE
                plc_client.write_coil(3, False)
            
            print("Ciclo terminado. Regresando a Reposo...", flush=True)
            mover_robot(wp_reposo)
            
    except Exception as e:
        print("\n!!! ERROR CRÍTICO EN LA EJECUCIÓN !!!", flush=True)
        print(traceback.format_exc(), flush=True)
        print("\nManteniendo el contenedor encendido en modo reposo para leer los logs...", flush=True)
        while True:
            time.sleep(10) # Evita que el contenedor muera

if __name__ == "__main__":
    print("Esperando 5 segundos para que los demás servicios arranquen...", flush=True)
    time.sleep(5)
    main()