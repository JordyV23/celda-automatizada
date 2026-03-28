PROGRAM clasificador
  VAR
    Sensor_Feeder AT %QX0.0 : BOOL;
    Sensor_Vision AT %QX0.1 : BOOL;
    Vision_OK AT %QX0.2 : BOOL;
    Sensor_ATE AT %QX0.3 : BOOL;
    
    Cmd_Move_Feeder AT %QX1.0 : BOOL;
    Cmd_Move_Vision AT %QX1.1 : BOOL;
    Cmd_Move_ATE AT %QX1.2 : BOOL;
    Cmd_Move_BinA AT %QX1.3 : BOOL;
    Cmd_Move_BinB AT %QX1.4 : BOOL;
    Cmd_Move_BinC AT %QX1.5 : BOOL;
    Cmd_Move_Scrap AT %QX1.6 : BOOL;
    
    Val_RDSon AT %QW0 : INT;
    Val_Vth AT %QW1 : INT;
    Val_IDSS AT %QW2 : INT;
  END_VAR

  (* Lógica de prueba para verificar la conexión Modbus TCP con Python *)
  IF Sensor_ATE THEN
    (* Si Python nos manda TRUE en el sensor ATE, leemos los registros *)
    IF Val_RDSon <= 1200 AND Val_Vth >= 250 THEN
        (* Simula que es Grado A y manda la señal de vuelta a Python *)
        Cmd_Move_BinA := TRUE;
        Cmd_Move_Scrap := FALSE;
    ELSE
        (* Si falla, manda la señal de Scrap *)
        Cmd_Move_BinA := FALSE;
        Cmd_Move_Scrap := TRUE;
    END_IF;
  ELSE
    (* Reposo *)
    Cmd_Move_BinA := FALSE;
    Cmd_Move_Scrap := FALSE;
  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#20ms,PRIORITY := 0);
    PROGRAM instance0 WITH task0 : clasificador;
  END_RESOURCE
END_CONFIGURATION