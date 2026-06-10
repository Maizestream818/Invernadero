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
```

## Guias

- [Guia de ejecucion](docs/guia_ejecucion.md)
- [Guia de ngrok](docs/guia_ngrok.md)
- [Guia de entrega](docs/guia_entrega.md)

## Nota de alcance

El proyecto actual incluye backend, base de datos, API REST, phpMyAdmin y panel web de monitoreo. La aplicacion Android y el codigo ESP32 se implementaran despues.

No se implementan login, roles, frameworks, MQTT, WebSockets, control manual desde web ni nuevas tablas en esta etapa.
