# Integracion ESP32

## Arquitectura

El flujo oficial del sistema es:

```text
ESP32 -> API REST PHP -> MySQL
App/Web -> API REST PHP -> MySQL
```

No se debe conectar el ESP32 directo a MySQL. La app Android y el panel web tampoco se conectan directo al ESP32 ni a MySQL. Todo intercambio pasa por la API REST usando HTTP y JSON.

## Responsabilidades del ESP32

- Conectar a WiFi.
- Consultar configuracion remota desde `GET /api/configuracion.php`.
- Leer sensores reales.
- Enviar lecturas con `POST /api/lecturas.php`.
- Aplicar reglas automaticas con la configuracion remota.
- Actualizar actuadores con `POST /api/actuadores.php`.
- Consultar comandos pendientes con `GET /api/comandos.php?estado=pendiente&limite=50`.
- Ejecutar comandos manuales de `ventilador`, `bomba` y `lampara`.
- Marcar comandos con `PUT /api/comandos.php`.
- Registrar eventos con `POST /api/eventos.php`.
- Registrar RFID con `POST /api/accesos.php` si se integra el lector.

## Componentes previstos

- ESP32.
- DHT11 para temperatura y humedad ambiente.
- YL-69 para humedad de suelo analogica.
- BH1750 para luz por I2C.
- RFID RC522.
- Ventilador.
- Bomba de agua.
- Lampara LED.
- Servo de acceso.
- Modulos relay, MOSFET o drivers para cargas.
- Fuente externa para cargas y servo cuando aplique.

## Mapa de pines sugerido

Este mapa es sugerido. Debe confirmarse fisicamente con el cableado real antes de alimentar cargas.

| Componente | Conexion | Pin sugerido |
|---|---|---|
| DHT11 | VCC | 3.3V |
| DHT11 | GND | GND |
| DHT11 | DATA | GPIO 4 |
| YL-69 humedad de suelo | VCC | 3.3V |
| YL-69 humedad de suelo | GND | GND |
| YL-69 humedad de suelo | AO | GPIO 34 |
| BH1750 | VCC | 3.3V |
| BH1750 | GND | GND |
| BH1750 | SDA | GPIO 21 |
| BH1750 | SCL | GPIO 22 |
| RFID RC522 | SDA/SS | GPIO 5 |
| RFID RC522 | SCK | GPIO 18 |
| RFID RC522 | MOSI | GPIO 23 |
| RFID RC522 | MISO | GPIO 19 |
| RFID RC522 | RST | GPIO 27 |
| RFID RC522 | VCC | 3.3V |
| RFID RC522 | GND | GND |
| Servo acceso | Senal | GPIO 13 |
| Servo acceso | VCC | Fuente externa 5V |
| Servo acceso | GND | GND comun con ESP32 |
| Ventilador | Control relay/MOSFET | GPIO 25 |
| Ventilador | Alimentacion | Fuente externa segun ventilador |
| Ventilador | GND | GND comun con ESP32 si aplica |
| Bomba de agua | Control relay/MOSFET | GPIO 26 |
| Bomba de agua | Alimentacion | Fuente externa segun bomba |
| Bomba de agua | GND | GND comun con ESP32 si aplica |
| Lampara LED | Control relay/MOSFET | GPIO 33 |
| Lampara LED | Alimentacion | Fuente externa segun lampara |
| Lampara LED | GND | GND comun con ESP32 si aplica |

## Advertencias electricas

- No conectar bomba, ventilador ni lampara directo a GPIO.
- Usar modulo relay, MOSFET o driver segun la carga.
- Usar fuente externa para cargas.
- Compartir GND entre ESP32 y fuente externa cuando el circuito lo requiera.
- El RC522 debe trabajar a 3.3V, no a 5V.
- El servo debe usar alimentacion externa si consume mas corriente de la que entrega el ESP32.
- Verificar si el relay es activo en `HIGH` o activo en `LOW` y ajustar `RELAY_ON_LEVEL` / `RELAY_OFF_LEVEL`.

## Librerias Arduino necesarias

Instalar desde Arduino IDE Library Manager o PlatformIO:

- WiFi.
- HTTPClient.
- ArduinoJson.
- DHT sensor library.
- Adafruit Unified Sensor.
- BH1750.
- Wire.
- SPI.
- MFRC522.
- ESP32Servo.

Tambien se requiere tener instalada la placa ESP32 en Arduino IDE.

## Configuracion local

La carpeta `esp32/firmware_base/` contiene:

- `firmware_base.ino`
- `config.example.h`

Pasos:

1. Copiar `config.example.h` como `config.h`.
2. Editar `config.h`.
3. Configurar `WIFI_SSID`.
4. Configurar `WIFI_PASSWORD`.
5. Configurar `API_BASE_URL`.
6. Revisar pines sugeridos y ajustarlos al cableado real.

Ejemplos de `API_BASE_URL`:

```cpp
#define API_BASE_URL "http://192.168.1.50:8080/api"
#define API_BASE_URL "https://TU-URL.ngrok-free.app/api"
```

`config.h` esta ignorado por Git para no subir credenciales reales.

## Cargar en Arduino IDE

1. Abrir `esp32/firmware_base/firmware_base.ino`.
2. Instalar las librerias listadas.
3. Seleccionar la placa ESP32 correspondiente.
4. Seleccionar el puerto serial.
5. Crear y configurar `config.h`.
6. Compilar.
7. Cargar al ESP32.
8. Abrir Monitor Serial a `115200`.

## Flujo del firmware base

El firmware ejecuta este ciclo cada 2 segundos para demo:

```text
conectarWiFi()
obtenerConfiguracion()
leerSensores()
enviarLectura()
aplicarAutomatizacion()
actualizarActuadores()
procesarComandosPendientes()
actualizarActuadores() si hubo comandos manuales
registrarAccesoRFID() si hay tarjeta
```

No usa `intervalo_lectura_seg` porque esa configuracion se oculto en la interfaz. El intervalo queda fijo en `CICLO_DEMO_MS = 2000` para la demo.

## Reglas de automatizacion

El ESP32 usa la configuracion remota:

- `temperatura_max_c`
- `humedad_suelo_min_pct`
- `luz_min_lux`
- `ventilacion_automatica`
- `riego_automatico`
- `iluminacion_automatica`
- `duracion_riego_seg`

Reglas:

- Si `temperatura_c > temperatura_max_c` y `ventilacion_automatica = 1`, enciende ventilador.
- Si `temperatura_c <= temperatura_max_c` y `ventilacion_automatica = 1`, apaga ventilador.
- Si `humedad_suelo_pct < humedad_suelo_min_pct` y `riego_automatico = 1`, enciende bomba.
- Si `humedad_suelo_pct >= humedad_suelo_min_pct` y `riego_automatico = 1`, apaga bomba.
- Si `intensidad_luz_lux < luz_min_lux` y `iluminacion_automatica = 1`, enciende lampara.
- Si `intensidad_luz_lux >= luz_min_lux` y `iluminacion_automatica = 1`, apaga lampara.

Si una automatizacion esta desactivada, ese actuador no se cambia automaticamente.

## Riego por duracion

El firmware usa `duracion_riego_seg` como limite de seguridad para no dejar la bomba encendida indefinidamente cuando el suelo sigue seco. Si el suelo esta seco, enciende la bomba y calcula hasta cuando puede permanecer encendida. Si la duracion se cumple, apaga la bomba. En el siguiente ciclo puede volver a evaluar el suelo y decidir de nuevo.

El simulador aplica las reglas por umbral directamente para que la prueba sea deterministica.

## Comandos manuales y automatizacion

En cada ciclo:

1. Primero se aplica la automatizacion.
2. Luego se consultan comandos pendientes.
3. Los comandos manuales de app/web tienen prioridad en ese ciclo.

Esto significa que si la automatizacion enciende la bomba, pero existe un comando pendiente para apagarla, el comando manual se ejecuta despues y la bomba queda apagada.

El servo `servo_acceso` no se controla por comandos manuales. Se mantiene asociado a RFID.

## Prueba sin hardware

Para simular el comportamiento del ESP32:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1
```

Modo continuo:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1 -ModoContinuo
```

Crear un comando de prueba:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1 -CrearComandoPrueba
```

Prueba de automatizacion:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase9_automatizacion.ps1
```

## Como probar con hardware

1. Levantar Docker:

```powershell
docker compose up -d --build
```

2. Probar API:

```text
http://localhost:8080/api/status.php
```

3. Si el ESP32 esta en la misma red, usar la IP LAN de la PC en `API_BASE_URL`.
4. Si se usa ngrok, ejecutar:

```powershell
ngrok http 8080
```

5. Copiar la URL publica a `API_BASE_URL`.
6. Cargar el firmware.
7. Revisar Monitor Serial:
   - conexion WiFi
   - respuesta de API
   - lectura de sensores
   - envio de lecturas
   - decisiones automaticas
   - comandos pendientes
   - RFID
   - estados de actuadores

## Diferencia entre simulador y ESP32 real

El simulador PowerShell usa lecturas generadas con variacion y sirve para validar la API, base de datos, comandos, eventos y automatizacion sin hardware.

El ESP32 real usa sensores fisicos y salidas reales. Si algun sensor falla durante la demo, el firmware tiene valores de respaldo para no detener el ciclo, pero en instalacion final se deben validar cableado, calibracion y alimentacion.
