# Invernadero Inteligente IoT

## Estado actual

Fase 2: Endpoints funcionales del backend.

## Tecnologias

- Docker Compose
- PHP
- Apache
- MySQL
- phpMyAdmin
- PowerShell para pruebas

## Requisitos

- Docker Desktop
- Git
- PowerShell

## Configuracion inicial

```powershell
copy .env.example .env
docker compose up -d --build
```

## URLs

API status:

```text
http://localhost:8080/api/status.php
```

phpMyAdmin:

```text
http://localhost:8081
```

## Base de datos

Nombre:

```text
invernadero_iot
```

Tablas:

- lecturas
- configuracion_automatizacion
- estados_actuadores
- tarjetas_rfid
- accesos_rfid
- eventos_actuadores
- comandos_actuadores
- calibraciones_sensores

## Pruebas

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase1.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase2.ps1
```

## Fase 2: Endpoints funcionales del backend

Endpoints disponibles:

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

### Ejemplos curl

Crear lectura:

```bash
curl -X POST http://localhost:8080/api/lecturas.php \
  -H "Content-Type: application/json" \
  -d "{\"temperatura_c\":28.5,\"humedad_ambiente_pct\":62,\"humedad_suelo_pct\":41.3,\"humedad_suelo_raw\":2870,\"intensidad_luz_lux\":780.5}"
```

Consultar lecturas:

```bash
curl http://localhost:8080/api/lecturas.php?limite=10
```

Crear estado de actuadores:

```bash
curl -X POST http://localhost:8080/api/actuadores.php \
  -H "Content-Type: application/json" \
  -d "{\"ventilador\":1,\"bomba\":0,\"lampara\":1,\"servo_acceso\":0,\"modo_control\":\"automatico\",\"origen\":\"esp32\"}"
```

Registrar acceso RFID:

```bash
curl -X POST http://localhost:8080/api/accesos.php \
  -H "Content-Type: application/json" \
  -d "{\"uid\":\"A1B2C3D4\",\"servo_abierto\":1}"
```

Crear comando para bomba:

```bash
curl -X POST http://localhost:8080/api/comandos.php \
  -H "Content-Type: application/json" \
  -d "{\"actuador\":\"bomba\",\"estado_solicitado\":1,\"origen\":\"app\"}"
```

Consultar comandos pendientes:

```bash
curl http://localhost:8080/api/comandos.php?estado=pendiente
```

## Nota de alcance

En esta fase no se implementa panel web, app Android, codigo ESP32, ngrok, login, roles, frameworks, MQTT, WebSockets, graficas ni notificaciones. Solo se implementa backend PHP puro con endpoints JSON funcionales.
