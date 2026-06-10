# Modelo base de datos

## Proposito

La base de datos `invernadero_iot` guarda la informacion inicial del sistema Invernadero Inteligente IoT. En esta fase se prepara la estructura para registrar lecturas, estados, accesos RFID, eventos, comandos futuros y calibraciones.

Esta base no se comunica directamente con el ESP32. La comunicacion esperada es:

App/Web/ESP32 -> API REST PHP -> MySQL

La API PHP es la capa responsable de validar datos, consultar MySQL y responder JSON.

## Tablas

### lecturas

Guarda lecturas ambientales y de sensores:

- Temperatura en grados Celsius.
- Humedad ambiente en porcentaje.
- Humedad de suelo en porcentaje.
- Valor raw opcional de humedad de suelo.
- Intensidad de luz en lux.
- Fecha de registro.

### configuracion_automatizacion

Guarda parametros base para automatizacion:

- Temperatura maxima.
- Humedad minima del suelo.
- Luz minima.
- Activacion automatica de ventilacion, riego e iluminacion.
- Duracion de riego.
- Intervalo de lectura.

### estados_actuadores

Guarda el estado reportado de actuadores:

- Ventilador.
- Bomba.
- Lampara.
- Servo de acceso.
- Modo de control.
- Origen del registro.
- Lectura asociada opcional.

### tarjetas_rfid

Guarda tarjetas RFID registradas:

- UID unico.
- Nombre de usuario opcional.
- Estado activo/inactivo.
- Fecha de alta.

### accesos_rfid

Guarda intentos de acceso por RFID:

- UID leido.
- Tarjeta asociada opcional.
- Si fue autorizado.
- Si el servo se abrio.
- Fecha del evento.

### eventos_actuadores

Guarda eventos de cambio de actuadores:

- Actuador afectado.
- Estado anterior.
- Estado nuevo.
- Motivo.
- Lectura o acceso RFID asociado opcional.
- Fecha del evento.

### comandos_actuadores

Guarda comandos preparados para control futuro desde app o web. En esta fase no se implementan endpoints completos para ejecutar comandos.

Esta tabla solo permite comandos para:

- ventilador
- bomba
- lampara

El servo de acceso se controla principalmente mediante RFID en el alcance inicial, no mediante comando remoto inicial.

### calibraciones_sensores

Guarda parametros de calibracion de sensores:

- Tipo de sensor.
- Valor raw minimo.
- Valor raw maximo.
- Descripcion.
- Estado activo/inactivo.
- Fecha de registro.

## Flujo de comunicacion

1. El ESP32, la app o una futura web enviaran solicitudes HTTP a la API REST en PHP.
2. La API validara la solicitud y usara PDO para consultar o escribir datos en MySQL.
3. MySQL guardara la informacion en las tablas correspondientes.
4. La API devolvera respuestas JSON al cliente.

En esta fase solo se implementa la verificacion base mediante `/api/status.php`.
