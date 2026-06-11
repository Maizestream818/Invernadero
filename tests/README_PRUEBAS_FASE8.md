# Pruebas Fase 8 - ESP32 simulado

## Que valida la Fase 8

La Fase 8 valida el flujo completo sin hardware fisico:

```text
ESP32 simulado -> API REST PHP -> MySQL
```

El simulador:

- Prueba conexion con `/status.php`.
- Envia una lectura a `/lecturas.php`.
- Envia estado de actuadores a `/actuadores.php`.
- Registra un acceso RFID demo en `/accesos.php`.
- Crea un comando pendiente para simular una peticion de la app.
- Consulta comandos pendientes en `/comandos.php?estado=pendiente&limite=1`.
- Ejecuta el comando pendiente de forma simulada.
- Registra un evento en `/eventos.php`.
- Marca el comando como `ejecutado`.

## Advertencia importante

La prueba limpia ejecuta:

```powershell
docker compose down -v
```

Esto borra el volumen de MySQL y elimina datos previos. Se hace para garantizar que los datos vistos fueron generados por el simulador y no por pruebas anteriores.

## Datos semilla al inicio

Despues de reconstruir la base desde `sql/init.sql`, deben existir unicamente estos datos semilla:

- 1 configuracion inicial en `configuracion_automatizacion`.
- 1 tarjeta RFID demo en `tarjetas_rfid` con UID `A1B2C3D4`.

## Tablas vacias antes del simulador

Antes de ejecutar el simulador deben estar vacias:

- `lecturas`
- `estados_actuadores`
- `accesos_rfid`
- `eventos_actuadores`
- `comandos_actuadores`
- `calibraciones_sensores`

## Datos generados por el simulador

Despues de ejecutar el simulador deben existir datos nuevos en:

- `lecturas`
- `estados_actuadores`
- `accesos_rfid`
- `comandos_actuadores`
- `eventos_actuadores`

Tambien debe existir:

- Al menos un comando con estado `ejecutado`.
- Al menos un evento del actuador `bomba`.
- Ningun comando para `servo_acceso`.

## Ejecutar simulador simple

Con Docker levantado:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1
```

## Ejecutar prueba limpia completa

Desde la raiz del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase8_esp32_simulado.ps1
```

## Resultado esperado

Todas las validaciones deben mostrar:

```text
[PASO] nombre de prueba
```

En PowerShell puede mostrarse `PASO` con acento segun la configuracion regional.
