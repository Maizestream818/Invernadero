# Invernadero Inteligente IoT

## Estado actual

Fase 1: Base de datos + backend base.

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
```

## Nota de alcance

En esta fase no se implementa panel web, app Android ni endpoints funcionales completos. Solo se implementa la base de datos, infraestructura Docker y backend base de verificacion.
