# Pruebas Fase 7 - Control remoto desde app Android

## Que se agrego

La app Android ahora tiene una seccion `Control remoto` para crear comandos pendientes usando la API REST PHP.

Los comandos se guardan en MySQL mediante:

```text
POST /api/comandos.php
```

En esta fase no se implementa codigo ESP32. Los comandos no ejecutan hardware todavia; quedan pendientes para que el ESP32 los consuma en una fase posterior.

## Actuadores permitidos

- `ventilador`
- `bomba`
- `lampara`

El servo no se controla desde la app. El acceso por servo se mantiene principalmente mediante RFID.

## Requisitos

- Docker Desktop.
- PowerShell.
- Android Studio para validar compilacion y pruebas manuales de la app.

## Ejecutar prueba automatica

Desde la raiz del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase7_control_app.ps1
```

La prueba valida:

- Existencia de `android-app/`.
- Soporte de POST JSON en `ApiClient.java`.
- Botones de control remoto en `activity_main.xml`.
- Referencias a `ventilador`, `bomba`, `lampara` y `comandos.php`.
- Que la app no intente crear comandos para `servo_acceso`.
- Que el backend responda.
- Que la API permita crear un comando pendiente para `bomba`.
- Que la API rechace un comando para `servo_acceso`.

## Prueba manual en Android Studio

1. Levantar backend:

```powershell
docker compose up -d --build
```

2. Probar API:

```text
http://localhost:8080/api/status.php
```

3. Abrir `android-app/` en Android Studio.

4. Ejecutar la app en un emulador o dispositivo.

5. Verificar que la URL base sea editable.

6. Para emulador local, usar:

```text
http://10.0.2.2:8080/api
```

7. Presionar `Probar conexion`.

8. Presionar `Actualizar datos`.

9. En la seccion `Control remoto`, probar:

- `Encender ventilador`
- `Apagar ventilador`
- `Encender bomba`
- `Apagar bomba`
- `Encender lampara`
- `Apagar lampara`

10. Confirmar que se muestra `Comando creado correctamente` y que se actualiza `Comandos recientes`.

## Resultado esperado

Todas las validaciones deben mostrar:

```text
[PASO] nombre de prueba
```

En consola puede verse `PASO` con acento segun la configuracion de PowerShell.
