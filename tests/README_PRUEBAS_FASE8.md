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
- Solo crea un comando pendiente si se ejecuta con `-CrearComandoPrueba`.
- Consulta comandos pendientes en `/comandos.php?estado=pendiente&limite=50`.
- Ejecuta todos los comandos pendientes procesables de forma simulada.
- Registra un evento en `/eventos.php`.
- Marca los comandos procesados como `ejecutado`.
- Verifica que no queden comandos pendientes procesables para `bomba`, `ventilador` o `lampara`.

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

Este comando procesa comandos pendientes existentes. No crea comandos nuevos.

Para crear un comando de prueba y procesar todos los pendientes:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1 -CrearComandoPrueba
```

Para dejar el simulador corriendo mientras se prueba la app Android:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1 -ModoContinuo
```

En modo continuo, el simulador consulta cada 5 segundos:

```text
/api/comandos.php?estado=pendiente&limite=50
```

Cuando encuentra comandos pendientes de `bomba`, `ventilador` o `lampara`, actualiza `/api/actuadores.php`, registra el evento en `/api/eventos.php` y marca el comando como `ejecutado`. Se detiene con `Ctrl + C`.

## Ejecutar prueba limpia completa

Desde la raiz del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase8_esp32_simulado.ps1
```

La prueba limpia usa `simular_esp32.ps1 -CrearComandoPrueba` para generar un comando inicial y validar que el simulador procesa todos los pendientes.

## Resultado esperado

Todas las validaciones deben mostrar:

```text
[PASO] nombre de prueba
```

En PowerShell puede mostrarse `PASO` con acento segun la configuracion regional.
