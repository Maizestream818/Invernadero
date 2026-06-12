# Pruebas Fase 8.1 - UX app/web y actualizacion automatica

## Que se cambio

La Fase 8.1 mejora la experiencia de usuario de la app Android y la visualizacion de datos en app/web.

Cambios principales:

- Se elimino el boton `Guardar URL`.
- La URL base de API se guarda automaticamente.
- Bomba, ventilador y lampara usan un solo boton dinamico cada uno.
- La app actualiza datos automaticamente cada 5 segundos.
- Sensores y actuadores se muestran como tarjetas individuales con icono y valor.
- El mismo concepto visual se aplica en la web.
- El estado superior de API es estable y solo muestra `API conectada` o `API desconectada`.

No se modifico backend, base de datos, Docker ni endpoints.

## Guardado automatico de URL

La URL se puede seguir editando en el campo de texto.

Se guarda automaticamente cuando:

- El campo pierde foco.
- Se presiona `Probar conexion`.
- Se presiona `Actualizar datos`.

Si no existe una URL guardada, la app usa:

```text
https://irregular-mothball-flyover.ngrok-free.dev/api
```

## Controles dinamicos de actuadores

La app consulta `/api/actuadores.php` para conocer el estado actual de `bomba`, `ventilador` y `lampara`.

Reglas:

- Si un actuador esta apagado, su boton permite encenderlo.
- Si un actuador esta encendido, su boton permite apagarlo.
- Si el estado es desconocido, su boton queda deshabilitado con `ESPERANDO ESTADO`.
- Si hay un comando pendiente para un actuador, solo ese actuador queda bloqueado con `ESPERANDO EJECUCION`.
- Los botones bloqueados siguen visibles, usan fondo de advertencia claro, borde de advertencia y texto oscuro para mantener contraste.
- El mensaje general de la seccion muestra `Sin comandos pendientes` cuando no hay pendientes y `Comandos pendientes detectados` o `Esperando ejecucion de comandos` cuando hay comandos por ejecutar.
- La app no usa el mensaje contradictorio `Sin comandos enviados desde la app`.

Al presionar el boton, la app crea un comando pendiente con:

```text
POST /api/comandos.php
```

La app no crea comandos para `servo_acceso`.

## Actualizacion automatica

La app actualiza cada 5 segundos de forma silenciosa, sin banners ni cuadros variables que muevan la interfaz:

- Estado de API.
- Ultima lectura.
- Actuadores.
- Configuracion.
- Accesos RFID.
- Comandos recientes.
- Estado actual de bomba.
- Estado actual de ventilador.
- Estado actual de lampara.

Tambien sigue existiendo el boton `Actualizar datos` para refrescar manualmente.

El bloque de estado superior conserva tamano estable y solo muestra:

- `API conectada`
- `API desconectada`

## Tarjetas visuales

En la app Android y en la web:

- Cada sensor se muestra como tarjeta individual.
- Cada actuador se muestra como tarjeta individual.
- Las tarjetas incluyen icono, titulo y valor.
- Se mantiene la paleta verde del proyecto.

## Ejecutar prueba automatica

Desde la raiz del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase8_1_app_actualizacion.ps1
```

La prueba valida:

- Que ya no exista boton `Guardar URL`.
- Que existan `btnToggleBomba`, `btnToggleVentilador` y `btnToggleLampara`.
- Que existan `txtEstadoBombaControl`, `txtEstadoVentiladorControl` y `txtEstadoLamparaControl`.
- Que no existan botones dobles antiguos de encender/apagar.
- Que la app tenga `Handler`, `Runnable`, `onResume`, `onPause` e `isRefreshing`.
- Que exista logica de comando pendiente por actuador.
- Que el estado API sea estable y no use mensajes `Actualizando...`.
- Que los botones pendientes usen contraste suficiente.
- Que el mensaje general de control remoto sea coherente.
- Que el simulador procese todos los comandos pendientes y no cree comandos nuevos sin `-CrearComandoPrueba`.
- Que app/web tengan tarjetas visuales.
- Que la API siga respondiendo.
- Que la API permita comandos de bomba, ventilador y lampara.
- Que la API rechace comandos de `servo_acceso`.

## Prueba manual recomendada

1. Levantar Docker:

```powershell
docker compose up -d --build
```

2. Abrir la app en Android Studio.

3. Verificar que no exista boton `Guardar URL`.

4. Editar la URL y presionar `Probar conexion`.

5. Verificar que la app se actualice sola cada 5 segundos.

6. Confirmar que sensores y actuadores se ven como tarjetas.

7. Verificar los botones dinamicos:

- Si un actuador esta apagado, debe mostrar `Encender ...`.
- Si un actuador esta encendido, debe mostrar `Apagar ...`.
- Si hay comando pendiente, solo debe bloquearse ese actuador y debe mostrar `ESPERANDO EJECUCION`.
- Si el estado todavia no se conoce, debe mostrar `ESPERANDO ESTADO`.
- El texto debe seguir siendo legible en los botones bloqueados.

8. Abrir la web:

```text
http://localhost:8080/web/
```

9. Confirmar que sensores y actuadores se ven como tarjetas con iconos.
