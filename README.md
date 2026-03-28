# Celda Automatizada

## Manual Paso a Paso para Levantar el Entorno

Este proyecto integra una celda de manufactura simulada con estos componentes:

- OpenPLC (lógica PLC y Modbus TCP)
- Mosquitto (broker MQTT)
- InfluxDB (métricas)
- Grafana (visualización)
- Python Gateway (orquestación entre simulación, PLC y mensajería)
- CoppeliaSim (simulación 3D, se ejecuta fuera de Docker)

## 1. Prerrequisitos

### Requisitos generales

1. Docker Desktop instalado y en ejecución.
2. Docker Compose v2 disponible.
3. CoppeliaSim instalado localmente.
4. Puertos libres en tu máquina:
    - 502 (Modbus TCP)
    - 1883 (MQTT)
    - 3000 (Grafana)
    - 8080 (OpenPLC Web)
    - 8086 (InfluxDB)

### Verificar instalación en Windows (PowerShell)

```powershell
docker --version
docker compose version
```

### Verificar instalación en Linux/macOS (bash/zsh)

```bash
docker --version
docker compose version
```

Si los comandos responden con versión, todo está listo.

## 2. Levantar los servicios Docker

Ubícate en la carpeta raíz del proyecto (donde está docker-compose.yaml).

### Windows (PowerShell)

```powershell
cd "/ruta/al/proyecto/Pruebas"
docker compose up -d
```

### Linux/macOS (bash/zsh)

```bash
cd /ruta/al/proyecto/Pruebas
docker compose up -d
```

## 3. Verificar que todo subió correctamente

### Estado de contenedores

```powershell
docker compose ps
```

Debes ver al menos estos contenedores en estado Up:

- openplc_runtime
- mosquitto_broker
- influxdb_metrics
- grafana_dashboard
- python_gateway

### Revisar logs del gateway (recomendado)

```powershell
docker compose logs -f python-gateway
```

Mensajes esperados (similares):

- "Iniciando Gateway Python..."
- "Conectando a CoppeliaSim..."
- "Conectando a OpenPLC..."
- "Conectando a MQTT..."

Para salir de la vista de logs: Ctrl + C (no detiene los contenedores).

## 4. Cargar la lógica PLC en OpenPLC

1. Abre OpenPLC Web: <http://localhost:8080>
2. Inicia sesión (si tu imagen lo solicita).
3. Importa el archivo:
    - open-plc-scripts/prueba_conexion.st
4. Compila y ejecuta el programa.

Nota: el gateway escribe registros Modbus y lee bobinas de decisión desde OpenPLC para clasificar piezas.

## 5. Abrir la simulación en CoppeliaSim

1. Abre CoppeliaSim localmente.
2. Carga la escena:
    - simulacion-coppeliaslim/Simulacion.ttt
3. Inicia la simulación (botón Play).

Importante:

- El contenedor python_gateway se conecta a CoppeliaSim usando host.docker.internal.
- Por eso CoppeliaSim debe estar corriendo en tu host, no dentro de Docker.

## 6. Validación funcional (checklist)

Confirma estos puntos:

1. `docker compose ps` muestra todos los servicios en Up.
2. OpenPLC responde en <http://localhost:8080>.
3. InfluxDB responde en <http://localhost:8086>.
4. Grafana responde en <http://localhost:3000>.
5. En logs de python_gateway no hay errores críticos de conexión persistentes.
6. Con CoppeliaSim en ejecución, el flujo de ciclo comienza (movimientos/reposo en logs).

## 7. Credenciales y configuración inicial

### InfluxDB (según docker-compose actual)

- URL: <http://localhost:8086>
- Usuario inicial: admin
- Contraseña inicial: adminpassword
- Organización: celda_org
- Bucket: binning_data

### Grafana

- URL: <http://localhost:3000>
- Usuario por defecto: admin
- Contraseña por defecto: admin

Recomendación: cambiar contraseñas por defecto si se usará fuera de pruebas locales.

## 8. Troubleshooting

### Problema: un contenedor reinicia constantemente

```powershell
docker compose ps
docker compose logs --tail=200 python-gateway
docker compose logs --tail=200 openplc
```

Acciones:

1. Verifica puertos ocupados en tu máquina.
2. Asegura que CoppeliaSim esté abierto si falla conexión ZMQ.
3. Reinicia servicios:

```powershell
docker compose restart
```

### Problema: no abre OpenPLC/Grafana/InfluxDB en navegador

1. Revisa que Docker Desktop esté activo.
2. Verifica `docker compose ps`.
3. Revisa si otro proceso usa los puertos 8080, 3000 o 8086.

### Problema: error de escritura a InfluxDB en logs

El gateway usa la variable de entorno INFLUX_TOKEN.

Si no está configurada, la celda puede arrancar pero fallará el guardado de métricas en InfluxDB.

## 9. Apagar, reiniciar y limpiar

### Detener sin borrar datos

```powershell
docker compose down
```

### Reiniciar todo

```powershell
docker compose up -d
```

### Borrar contenedores y datos del entorno (reset completo)

```powershell
docker compose down -v
```

## 10. Flujo recomendado de primera ejecución

1. Levanta Docker con `docker compose up -d`.
2. Carga y ejecuta `prueba_conexion.st` en OpenPLC.
3. Abre `Simulacion.ttt` en CoppeliaSim y pon Play.
4. Monitorea logs de `python-gateway`.
5. Verifica dashboards y estado de servicios.

Con eso el entorno queda listo para pruebas iniciales de integración.
