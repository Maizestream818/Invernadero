# Pruebas Fase 6

## Que cambio

La Fase 6 unifica el diseno visual del panel web y la app Android con una paleta verde comun, tarjetas redondeadas, botones verdes y etiquetas de estado tipo badge.

Tambien cambia la URL por defecto de la app Android a:

```text
https://irregular-mothball-flyover.ngrok-free.dev/api
```

La URL sigue siendo editable desde la app y se conserva si el usuario ya guardo otra URL en `SharedPreferences`.

## Probar panel web

1. Levantar backend:

```powershell
docker compose up -d --build
```

2. Abrir:

```text
http://localhost:8080/web/
```

El panel debe cargar datos y mantener las secciones de monitoreo.

## Probar app Android

1. Abrir `android-app/` en Android Studio.
2. Ejecutar en emulador o dispositivo.
3. Confirmar que el campo `URL base de API` muestra por defecto:

```text
https://irregular-mothball-flyover.ngrok-free.dev/api
```

4. Confirmar que la URL se puede editar y guardar manualmente.
5. Presionar `Probar conexion`.
6. Presionar `Actualizar datos`.

## Probar ngrok

ngrok debe estar corriendo con:

```powershell
ngrok http 8080
```

La URL ngrok configurada debe apuntar al puerto 8080 local.

## Checklist visual

- La app y la web usan mismos colores.
- Ambas tienen tarjetas similares.
- Ambas tienen botones similares.
- La app muestra la URL ngrok por defecto.
- La app sigue permitiendo editar la URL.
- La web sigue cargando datos.
- La app sigue cargando datos.
- No hay controles remotos nuevos.

## Prueba automatica

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase6_diseno.ps1
```

Resultado esperado: todas las validaciones muestran `[PASO]` o `[PASÓ]`.
