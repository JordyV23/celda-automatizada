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

  (* 1. Reiniciar todas las salidas al inicio del ciclo por seguridad *)
  Cmd_Move_BinA := FALSE;
  Cmd_Move_BinB := FALSE;
  Cmd_Move_BinC := FALSE;
  Cmd_Move_Scrap := FALSE;

  (* 2. Lógica de Clasificación *)
  IF Sensor_ATE THEN
    
    (* GRADO A: RDSon excelente (<= 10.00 mOhm) y Vth aceptable *)
    IF Val_RDSon <= 1000 AND Val_Vth >= 250 THEN
        Cmd_Move_BinA := TRUE;
        
    (* GRADO B: RDSon regular (10.01 a 12.00 mOhm) y Vth aceptable *)
    ELSIF Val_RDSon <= 1200 AND Val_Vth >= 250 THEN
        Cmd_Move_BinB := TRUE;
        
    (* GRADO C: RDSon marginal (12.01 a 15.00 mOhm) y Vth aceptable *)
    ELSIF Val_RDSon <= 1500 AND Val_Vth >= 250 THEN
        Cmd_Move_BinC := TRUE;
        
    (* SCRAP: RDSon > 15.00 mOhm o Vth < 2.50V (Fallo catastrófico) *)
    ELSE
        Cmd_Move_Scrap := TRUE;
    END_IF;

  END_IF;
END_PROGRAM

CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#20ms,PRIORITY := 0);
    PROGRAM instance0 WITH task0 : clasificador;
  END_RESOURCE
END_CONFIGURATION