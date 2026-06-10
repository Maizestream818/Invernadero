# Pruebas Fase 4

## Requisitos

- Docker Desktop instalado y en ejecucion.
- Git.
- PowerShell.
- Archivo `.env` creado desde `.env.example`.
- ngrok instalado si se quiere probar acceso externo manualmente.

## Ejecutar pruebas automaticas

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase4.ps1
```

La prueba valida:

- Docker disponible.
- Servicios levantados con Docker Compose.
- API status disponible.
- Panel web disponible.
- phpMyAdmin disponible.
- Existencia de guias de entrega.
- Menciones obligatorias de ngrok y URLs locales en `README.md`.

## Probar ngrok manualmente

Con Docker levantado:

```powershell
ngrok http 8080
```

Si ngrok genera:

```text
https://ejemplo.ngrok-free.app
```

Probar:

```text
https://ejemplo.ngrok-free.app/web/
https://ejemplo.ngrok-free.app/api/status.php
https://ejemplo.ngrok-free.app/api/lecturas.php
```

## Resultado esperado

El script debe mostrar `[PASO]` o `[PASÓ]` en todas las pruebas, segun la codificacion de la consola.

El panel web debe abrir localmente y, si ngrok esta activo, tambien mediante la URL publica generada.
