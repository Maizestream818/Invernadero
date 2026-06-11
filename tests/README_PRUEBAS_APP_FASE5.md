# Pruebas App Android Fase 5

## Requisitos

- Backend levantado con Docker.
- Android Studio instalado.
- Emulador Android disponible.
- PowerShell para la validacion estructural.

## Validacion automatica

Ejecutar desde la raiz del repositorio:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase5_app.ps1
```

Esta prueba revisa:

- Existencia de `android-app/`.
- Existencia de `MainActivity.java`.
- Existencia de `AndroidManifest.xml`.
- Permiso `INTERNET`.
- `usesCleartextTraffic="true"`.
- Uso de `ApiClient.java`.
- Referencias a endpoints requeridos.
- Uso de `HttpURLConnection`, `org.json` y `SharedPreferences`.
- Ausencia de Retrofit, Volley y Jetpack Compose.

## Pruebas manuales en Android Studio

1. Levantar backend:

```powershell
docker compose up -d --build
```

2. Probar API local:

```text
http://localhost:8080/api/status.php
```

3. Abrir `android-app/` en Android Studio.

4. Ejecutar la app en un emulador Android.

5. En la app usar esta URL:

```text
http://10.0.2.2:8080/api
```

6. Presionar `Probar conexion`.

Resultado esperado:

```text
API conectada
```

7. Presionar `Actualizar datos`.

Debe mostrar:

- Sensores.
- Actuadores.
- Configuracion.
- Accesos RFID recientes.
- Comandos recientes.

8. Cambiar la URL a una incorrecta y presionar `Probar conexion`.

La app debe mostrar error sin cerrarse.

## Nota

La app de Fase 5 es solo de monitoreo. No crea comandos, no controla actuadores, no se conecta directo a MySQL y no se conecta directo al ESP32.
