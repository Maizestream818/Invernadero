# Invernadero Inteligente IoT

## Descripcion

Proyecto academico para un invernadero inteligente IoT. La version actual incluye base de datos MySQL, API REST en PHP puro, phpMyAdmin, panel web, app Android, simulador ESP32 con automatizacion real y firmware base ESP32 preparado para Arduino IDE.

El panel web consume datos reales desde la API y permite monitorear lecturas, actuadores, configuracion, accesos RFID, eventos y comandos recientes. El control manual se realiza creando comandos pendientes mediante la API.

## Tecnologias

- Docker Compose
- PHP
- Apache
- MySQL
- phpMyAdmin
- HTML
- CSS
- JavaScript
- ngrok
- PowerShell para pruebas
- Java
- XML Views
- Arduino ESP32 para firmware base

## Requisitos

- Docker Desktop
- Git
- PowerShell
- ngrok para acceso externo

## Instalacion desde cero

```powershell
git clone https://github.com/Maizestream818/Invernadero.git
cd Invernadero
copy .env.example .env
docker compose up -d --build
```

## URLs locales

- Panel web: http://localhost:8080/web/
- API status: http://localhost:8080/api/status.php
- phpMyAdmin: http://localhost:8081

## Credenciales de phpMyAdmin

- Servidor: `db`
- Usuario: `invernadero_user`
- Contrasena: `invernadero_pass`
- Base de datos: `invernadero_iot`

## Base de datos

Nombre:

```text
invernadero_iot
```

Tablas:

- `lecturas`
- `configuracion_automatizacion`
- `estados_actuadores`
- `tarjetas_rfid`
- `accesos_rfid`
- `eventos_actuadores`
- `comandos_actuadores`
- `calibraciones_sensores`

## Endpoints principales

- `GET /api/status.php`
- `GET /api/lecturas.php`
- `POST /api/lecturas.php`
- `GET /api/actuadores.php`
- `POST /api/actuadores.php`
- `GET /api/accesos.php`
- `POST /api/accesos.php`
- `GET /api/configuracion.php`
- `PUT /api/configuracion.php`
- `GET /api/comandos.php`
- `POST /api/comandos.php`
- `PUT /api/comandos.php`
- `GET /api/eventos.php`
- `POST /api/eventos.php`

## Panel web

URL:

```text
http://localhost:8080/web/
```

El panel web HTML/CSS/JS monitorea el estado del invernadero usando la API REST PHP.

Muestra:

- Estado de la API.
- Ultima lectura de sensores.
- Ultimo estado de actuadores.
- Configuracion de automatizacion.
- Ultimas lecturas.
- Ultimos accesos RFID.
- Ultimos eventos de actuadores.
- Comandos recientes.

El panel web no controla actuadores. Solo monitorea. La frase App Android en etapa posterior queda como referencia historica de fases previas; desde Fase 7 el control remoto permitido se hace desde la app Android mediante comandos pendientes.

## Uso con ngrok

Con Docker levantado, ejecutar:

```powershell
ngrok http 8080
```

Si ngrok genera esta URL:

```text
https://ejemplo.ngrok-free.app
```

Entonces las rutas publicas seran:

- Panel web: https://ejemplo.ngrok-free.app/web/
- API status: https://ejemplo.ngrok-free.app/api/status.php
- Lecturas: https://ejemplo.ngrok-free.app/api/lecturas.php
- Actuadores: https://ejemplo.ngrok-free.app/api/actuadores.php
- Accesos RFID: https://ejemplo.ngrok-free.app/api/accesos.php

La URL gratuita de ngrok puede cambiar cada vez que se reinicia ngrok.

## Pruebas

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase1.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase2.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase3.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase4.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase5_app.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase6_diseno.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase7_control_app.ps1
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1 -ModoContinuo
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1 -CrearComandoPrueba
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase8_esp32_simulado.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase8_1_app_actualizacion.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase9_automatizacion.ps1
```

## Guias

- [Guia de ejecucion](docs/guia_ejecucion.md)
- [Guia de ngrok](docs/guia_ngrok.md)
- [Guia de entrega](docs/guia_entrega.md)

## Fase 5: App Android de monitoreo

- Ubicacion: `android-app/`
- Tecnologia: Java + XML Views.
- URL para emulador: `http://10.0.2.2:8080/api`
- URL local desde navegador: `http://localhost:8080/api`
- URL con ngrok: `https://TU-URL.ngrok-free.app/api`

La app consume la API REST PHP. La app no se conecta directamente a MySQL y no se conecta directamente al ESP32.

En esta fase la app solo monitorea:

- Estado de API mediante `/status.php`.
- Ultima lectura de sensores mediante `/lecturas.php?limite=1`.
- Ultimo estado de actuadores mediante `/actuadores.php`.
- Configuracion mediante `/configuracion.php`.
- Accesos RFID recientes mediante `/accesos.php?limite=5`.
- Comandos recientes mediante `/comandos.php?limite=5`.

Desde Fase 7 la app puede crear comandos pendientes para ventilador, bomba y lampara. La ejecucion fisica por ESP32 se implementara despues.

Pruebas manuales esperadas:

1. Levantar backend:

```powershell
docker compose up -d --build
```

2. Probar API:

```text
http://localhost:8080/api/status.php
```

3. Ejecutar la app en emulador Android.

4. En la app usar:

```text
http://10.0.2.2:8080/api
```

5. Presionar `Probar conexion`; debe mostrar `API conectada`.

6. Presionar `Actualizar datos`; debe mostrar sensores, actuadores, configuracion, accesos RFID y comandos recientes.

7. Cambiar la URL a una incorrecta; debe mostrar error sin cerrar la app.

## Fase 6: Diseno visual unificado y URL ngrok por defecto

Se unifico el diseno visual de web y app Android con una paleta verde inspirada en el invernadero, tarjetas redondeadas, botones verdes, fondos claros y etiquetas de estado consistentes.

La app usa por defecto:

```text
https://irregular-mothball-flyover.ngrok-free.dev/api
```

Esa URL requiere que ngrok este corriendo con:

```powershell
ngrok http 8080
```

La URL puede editarse manualmente desde la app y se conserva si el usuario ya guardo otra direccion.

No se agrego control remoto nuevo en esta fase.

## Fase 7: Control remoto desde app Android

La app Android puede crear comandos para:

- `ventilador`
- `bomba`
- `lampara`

Los comandos se envian con `POST /api/comandos.php` y se guardan en la API como pendientes. El ESP32 ejecutara esos comandos en una fase posterior.

La app no se conecta directamente a MySQL. La app no se conecta directamente al ESP32. El flujo sigue siendo:

```text
Android -> API REST PHP -> MySQL
```

El servo se mantiene controlado principalmente por RFID y no se controla desde la app.

Prueba de Fase 7:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase7_control_app.ps1
```

## Fase 8: Simulador ESP32 e integracion con API

Se agrego una integracion simulada del ESP32 para validar el flujo completo sin hardware fisico.

Incluye:

- Simulador PowerShell del ESP32.
- Contrato de comunicacion `ESP32 -> API REST PHP -> MySQL`.
- Firmware base documentado para ESP32.
- Prueba limpia que reconstruye la base desde cero.

Despues de reconstruir, la base conserva unicamente estos datos semilla:

- Configuracion inicial.
- Tarjeta RFID demo con UID `A1B2C3D4`.

El simulador genera datos nuevos en:

- `lecturas`
- `estados_actuadores`
- `accesos_rfid`
- `comandos_actuadores`
- `eventos_actuadores`

La comunicacion sigue siendo HTTP JSON hacia la API REST PHP. El ESP32 real se implementara despues con pines, sensores y cableado reales.

Ejecutar simulador sin reiniciar base:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1
```

Este comando procesa comandos pendientes existentes. No crea comandos nuevos por defecto.

Para crear un comando de prueba y luego procesar todos los comandos pendientes:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1 -CrearComandoPrueba
```

Para dejar el simulador procesando comandos mientras se prueba la app Android:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\simular_esp32.ps1 -ModoContinuo
```

El modo continuo consulta configuracion, genera lectura simulada, aplica automatizacion, procesa comandos pendientes cada 2 segundos, actualiza actuadores, registra eventos y marca los comandos como `ejecutado`. Se detiene con `Ctrl + C`.

Ejecutar prueba limpia completa:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase8_esp32_simulado.ps1
```

`probar_fase8_esp32_simulado.ps1` ejecuta `docker compose down -v`, por lo tanto borra la base de datos persistida del volumen MySQL.

## Fase 8.1: UX mejorada en app y tarjetas visuales en app/web

Se aplicaron mejoras de experiencia de usuario en la app Android y en el panel web.

Cambios:

- Se elimino el boton `Guardar URL`.
- La URL base de API se guarda automaticamente al perder foco, probar conexion o actualizar datos.
- Bomba, ventilador y lampara ahora se controlan desde un unico boton dinamico por actuador.
- Si un actuador esta apagado, su boton permite encenderlo.
- Si un actuador esta encendido, su boton permite apagarlo.
- Si el estado es desconocido o hay comando pendiente, se bloquea solo el actuador afectado.
- Los botones bloqueados siguen visibles con texto oscuro, borde de advertencia y mensajes `ESPERANDO ESTADO` o `ESPERANDO EJECUCION`.
- El mensaje general de control remoto muestra `Sin comandos pendientes` cuando no hay pendientes y `Comandos pendientes detectados` o `Esperando ejecucion de comandos` cuando corresponde.
- El estado superior de API es estable y solo muestra `API conectada` o `API desconectada`.
- La app se actualiza automaticamente cada 5 segundos sin banners que muevan la interfaz.
- El boton `Actualizar datos` sigue funcionando.
- Sensores y actuadores ahora se muestran en tarjetas individuales con icono y valor.
- El mismo concepto visual se aplica en app y web.
- El simulador ESP32 procesa todos los comandos pendientes consultando `/api/comandos.php?estado=pendiente&limite=50` y solo crea un comando de prueba cuando se ejecuta con `-CrearComandoPrueba`.

No se modificaron endpoints ni base de datos.

Prueba de Fase 8.1:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase8_1_app_actualizacion.ps1
```

## Fase 9: Automatizacion real en simulador y firmware ESP32 base

El simulador ESP32 ahora consulta `GET /api/configuracion.php` y aplica reglas automaticas antes de procesar comandos manuales.

Reglas implementadas:

- Si `temperatura_c > temperatura_max_c` y `ventilacion_automatica = 1`, enciende ventilador.
- Si `temperatura_c <= temperatura_max_c` y `ventilacion_automatica = 1`, apaga ventilador.
- Si `humedad_suelo_pct < humedad_suelo_min_pct` y `riego_automatico = 1`, enciende bomba.
- Si `humedad_suelo_pct >= humedad_suelo_min_pct` y `riego_automatico = 1`, apaga bomba.
- Si `intensidad_luz_lux < luz_min_lux` y `iluminacion_automatica = 1`, enciende lampara.
- Si `intensidad_luz_lux >= luz_min_lux` y `iluminacion_automatica = 1`, apaga lampara.

Si una automatizacion esta desactivada, ese actuador no se cambia automaticamente. Los comandos manuales de app/web se procesan despues de la automatizacion, por lo que tienen prioridad al final del ciclo. `servo_acceso` no se controla por comandos manuales.

El firmware base en `esp32/firmware_base/firmware_base.ino` queda preparado para:

- conectar WiFi
- consultar configuracion
- leer DHT11, YL-69, BH1750 y RFID RC522
- enviar lecturas
- aplicar automatizacion
- actualizar actuadores
- procesar comandos pendientes
- registrar eventos y accesos RFID

El intervalo queda fijo en 2 segundos para demo. No se usa `intervalo_lectura_seg` porque esa configuracion se oculto en la interfaz.

La guia completa del ESP32 esta en:

```text
esp32/README_INTEGRACION_ESP32.md
```

Prueba de Fase 9:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase9_automatizacion.ps1
```

## Nota de alcance

El proyecto actual incluye backend, base de datos, API REST, phpMyAdmin, panel web, app Android con monitoreo/control por comandos pendientes, simulador ESP32 con automatizacion y firmware base ESP32. Los pines documentados son sugeridos y deben confirmarse con el cableado fisico final.

No se implementan login, roles, frameworks, MQTT, WebSockets, control manual desde web ni nuevas tablas en esta etapa.
