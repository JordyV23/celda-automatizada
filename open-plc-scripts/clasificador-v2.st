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
    
    Val_RDSon AT %QW10 : INT;  (* Movido al registro 10 para evitar colisión *)
    Val_Vth AT %QW11 : INT;    (* Movido al registro 11 *)
    Val_IDSS AT %QW12 : INT;   (* Movido al registro 12 *)
  END_VAR

  (* 1. Reiniciar todas las salidas al inicio del ciclo por seguridad *)
  Cmd_Move_BinA := FALSE;
  Cmd_Move_BinB := FALSE;
  Cmd_Move_BinC := FALSE;
  Cmd_Move_Scrap := FALSE;

  (* 2. Lógica de Clasificación Estricta *)
  IF Sensor_ATE THEN
    
    (* GRADO A: RDSon <= 10.00, Vth entre 2.80 y 3.20, IDSS <= 0.50 *)
    IF (Val_RDSon <= 1000) AND (Val_Vth >= 280) AND (Val_Vth <= 320) AND (Val_IDSS <= 50) THEN
        Cmd_Move_BinA := TRUE;
        
    (* GRADO B: RDSon <= 12.00, Vth entre 2.60 y 3.40, IDSS <= 1.00 *)
    ELSIF (Val_RDSon <= 1200) AND (Val_Vth >= 260) AND (Val_Vth <= 340) AND (Val_IDSS <= 100) THEN
        Cmd_Move_BinB := TRUE;
        
    (* GRADO C: RDSon <= 15.00, Vth entre 2.50 y 3.50, IDSS <= 2.00 *)
    ELSIF (Val_RDSon <= 1500) AND (Val_Vth >= 250) AND (Val_Vth <= 350) AND (Val_IDSS <= 200) THEN
        Cmd_Move_BinC := TRUE;
        
    (* SCRAP: Cualquier pieza que exceda los límites de Grado C cae aquí automáticamente *)
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