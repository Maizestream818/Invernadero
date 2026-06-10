# Pruebas Fase 1

## Requisitos

- Docker Desktop instalado y en ejecucion.
- Git.
- PowerShell.

## Crear archivo `.env`

Copiar el archivo de ejemplo:

```powershell
copy .env.example .env
```

El archivo `.env` no debe subirse a Git.

## Levantar Docker

```powershell
docker compose up -d --build
```

Servicios esperados:

- `app`
- `db`
- `phpmyadmin`

## Entrar a phpMyAdmin

Abrir:

```text
http://localhost:8081
```

Datos de acceso:

- Servidor: `db`
- Usuario: `invernadero_user`
- Password: `invernadero_pass`

Tambien se puede entrar como root usando `root_pass`.

## Probar endpoint de estado

Abrir:

```text
http://localhost:8080/api/status.php
```

Respuesta esperada:

```json
{
  "ok": true,
  "mensaje": "API funcionando correctamente",
  "servicio": "Invernadero Inteligente IoT",
  "base_datos": "invernadero_iot",
  "conexion_bd": true
}
```

## Ejecutar prueba automatica

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase1.ps1
```

## Resultado esperado

El script debe mostrar `PASÓ` en:

- Docker disponible.
- Servicios levantados.
- MySQL listo.
- Servicios requeridos existentes.
- Tablas requeridas existentes.
- Insercion de lectura de prueba.
- Insercion de estado de actuadores de prueba.
- Insercion de acceso RFID de prueba.
- Endpoint `/api/status.php` con `conexion_bd: true`.
