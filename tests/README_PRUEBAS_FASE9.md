# Pruebas Fase 9 - Automatizacion real

## Objetivo

Validar que el simulador ESP32 ya no solo envia datos y procesa comandos, sino que tambien consulta la configuracion remota de automatizacion y aplica reglas reales sobre ventilador, bomba y lampara.

El flujo probado es:

```text
simulador ESP32 -> API REST PHP -> MySQL
```

La prueba tambien revisa que el firmware base tenga la misma estructura logica preparada para Arduino IDE.

## Comando

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase9_automatizacion.ps1
```

La prueba reconstruye la base con Docker Compose para iniciar desde un estado conocido.

## Validaciones principales

- El simulador consulta `GET /api/configuracion.php`.
- El simulador usa:
  - `temperatura_max_c`
  - `humedad_suelo_min_pct`
  - `luz_min_lux`
  - `ventilacion_automatica`
  - `riego_automatico`
  - `iluminacion_automatica`
  - `duracion_riego_seg`
- El simulador genera lectura simulada con variacion.
- El simulador aplica automatizacion:
  - temperatura alta enciende ventilador
  - temperatura normal apaga ventilador
  - humedad baja enciende bomba
  - humedad suficiente apaga bomba
  - luz baja enciende lampara
  - luz suficiente apaga lampara
- El simulador registra eventos automaticos en `/api/eventos.php`.
- El simulador procesa comandos pendientes desde `/api/comandos.php?estado=pendiente&limite=50`.
- Los comandos manuales tienen prioridad al final del ciclo.
- `servo_acceso` no se controla por comandos manuales.
- El firmware base contiene la estructura equivalente.
- `config.example.h` usa placeholders y `config.h` sigue ignorado por Git.
- La documentacion contiene mapa de pines sugerido y advertencias electricas.
- No hay cambios en `api/`, `sql/`, `Dockerfile` ni `docker-compose.yml`.

## Automatizacion probada

La prueba ajusta la configuracion para forzar que la lectura simulada active los tres actuadores:

```text
temperatura_max_c = 20
humedad_suelo_min_pct = 90
luz_min_lux = 1000
ventilacion_automatica = 1
riego_automatico = 1
iluminacion_automatica = 1
```

Despues ejecuta el simulador y valida que el ultimo estado tenga:

```text
ventilador = 1
bomba = 1
lampara = 1
```

Luego crea un comando manual para apagar la bomba y vuelve a ejecutar el simulador. Como los comandos manuales se procesan despues de la automatizacion, la bomba debe quedar apagada y el comando debe marcarse como `ejecutado`.

## Alcance del firmware

La prueba no compila el firmware ESP32 porque el entorno local puede no tener Arduino IDE, placas ESP32 ni librerias instaladas. Solo valida estructura, endpoints, configuracion y documentacion.
