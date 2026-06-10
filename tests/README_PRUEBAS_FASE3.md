# Pruebas Fase 3

## Requisitos

- Docker Desktop instalado y en ejecucion.
- Git.
- PowerShell.
- Archivo `.env` creado desde `.env.example`.

## Levantar Docker

```powershell
docker compose up -d --build
```

## Abrir la web

Abrir en el navegador:

```text
http://localhost:8080/web/
```

## Ejecutar pruebas automaticas

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase3.ps1
```

El script valida:

- Docker disponible.
- Servicios levantados.
- `/api/status.php`.
- Endpoints principales de Fase 2.
- Insercion de datos de prueba mediante endpoints existentes.
- Respuesta HTTP 200 de `/web/`.
- Respuesta HTTP 200 de `/web/estilos.css`.
- Respuesta HTTP 200 de `/web/app.js`.
- Referencias a `estilos.css` y `app.js` en `web/index.html`.
- Uso de `const API_BASE_URL = "/api";` en `web/app.js`.

## Pruebas manuales

Abrir:

```text
http://localhost:8080/web/
```

Confirmar que se vea:

- Estado de API.
- Ultima lectura.
- Ultimo estado de actuadores.
- Configuracion.
- Tabla de lecturas.
- Tabla de accesos RFID.
- Tabla de eventos.
- Tabla de comandos.

Abrir la consola del navegador y confirmar que no hay errores JavaScript.

Presionar `Actualizar datos` y confirmar que no se rompe la pagina.

Esperar 5 segundos y confirmar que los datos se actualizan automaticamente.

## Resultado esperado

Todas las pruebas automaticas deben mostrar `[PASO]` o `[PASÓ]`, segun la codificacion de la consola, y terminar con un mensaje de exito general.

Visualmente debe verse un panel simple, claro y de solo monitoreo. No debe haber botones para encender o apagar actuadores ni para abrir o cerrar el servo.
