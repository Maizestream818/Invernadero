# Pruebas Fase 2

## Requisitos

- Docker Desktop instalado y en ejecucion.
- Git.
- PowerShell.
- Archivo `.env` creado desde `.env.example`.

## Levantar Docker

```powershell
docker compose up -d --build
```

Servicios esperados:

- `app`
- `db`
- `phpmyadmin`

## Ejecutar pruebas

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase2.ps1
```

## Endpoints probados

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

Tambien se prueban entradas invalidas para:

- Lecturas.
- Estados de actuadores.
- Comandos no permitidos para `servo_acceso`.

## Resultado esperado

El script debe mostrar `[PASO]` o `[PASÓ]` en cada prueba, segun la codificacion de la consola, y terminar con un mensaje de exito general.

Si alguna prueba falla, revisar:

- Que Docker Desktop este ejecutandose.
- Que el puerto `8080` este libre para la API.
- Que el puerto `8081` este libre para phpMyAdmin.
- Que el puerto `3306` este libre para MySQL.
