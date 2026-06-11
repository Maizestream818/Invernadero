# Invernadero Inteligente IoT

## Descripcion

Proyecto academico para un invernadero inteligente IoT. La version actual incluye base de datos MySQL, API REST en PHP puro, phpMyAdmin, panel web de monitoreo y documentacion para acceso externo con ngrok.

El panel web consume datos reales desde la API y permite monitorear lecturas, actuadores, configuracion, accesos RFID, eventos y comandos recientes. El panel no controla actuadores.

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

El panel web no controla actuadores. Solo monitorea. El control remoto se reserva para la App Android en etapa posterior.

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

La app no crea comandos todavia y no controla actuadores. El control remoto se implementara despues.

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

## Nota de alcance

El proyecto actual incluye backend, base de datos, API REST, phpMyAdmin, panel web de monitoreo y app Android base de monitoreo. La frase App Android en etapa posterior aplica al control remoto pendiente. El codigo ESP32 se implementara despues.

No se implementan login, roles, frameworks, MQTT, WebSockets, control manual desde web ni nuevas tablas en esta etapa.
