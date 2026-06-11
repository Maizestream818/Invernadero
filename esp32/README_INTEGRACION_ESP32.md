# Integracion ESP32

## Flujo general

El flujo oficial del sistema es:

```text
ESP32 -> API REST PHP -> MySQL
```

El ESP32 debe:

- Enviar lecturas de sensores.
- Enviar estados de actuadores.
- Registrar accesos RFID.
- Consultar comandos pendientes.
- Marcar comandos como ejecutados o fallidos.
- Registrar eventos de actuadores.

La app Android no habla directo con el ESP32. La base de datos no habla directo con el ESP32. Todo pasa por la API REST PHP.

## Prueba sin hardware

Para simular el comportamiento basico del ESP32:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1
```

Para ejecutar una prueba limpia completa:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase8_esp32_simulado.ps1
```

La prueba limpia ejecuta:

```powershell
docker compose down -v
```

Por eso elimina datos previos del volumen MySQL y reconstruye la base desde `sql/init.sql`.

## Datos semilla tras reconstruir

Despues de reconstruir la base deben quedar solo estos datos iniciales:

- Una configuracion inicial en `configuracion_automatizacion`.
- Una tarjeta RFID demo en `tarjetas_rfid` con UID `A1B2C3D4`.

Las tablas operativas deben iniciar vacias antes del simulador.

## Uso con ngrok

Con Docker levantado:

```powershell
ngrok http 8080
```

URL base publica actual:

```text
https://irregular-mothball-flyover.ngrok-free.dev/api
```

Si se reinicia ngrok gratuito, la URL puede cambiar y debe actualizarse en `config.h` o en el script de simulacion.

## Firmware base

La carpeta `esp32/firmware_base/` contiene una plantilla para Arduino IDE o PlatformIO.

Antes de usarla:

1. Copiar `config.example.h` como `config.h`.
2. Escribir el nombre y contrasena de Wi-Fi local.
3. Ajustar `API_BASE_URL` si se usa otra URL.

No se sube `config.h` al repositorio porque puede contener credenciales reales.

## Pines reales

Los pines finales, sensores reales y cableado se definiran cuando se conecte la electronica fisica. Esta fase solo valida el contrato de integracion con la API.
