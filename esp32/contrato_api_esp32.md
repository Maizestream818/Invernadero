# Contrato API ESP32

## Flujo oficial

La comunicacion oficial del sistema es:

```text
ESP32 -> API REST PHP -> MySQL
```

No se permite:

- `ESP32 -> MySQL` directo.
- `App Android -> ESP32` directo.
- `App Android -> MySQL` directo.

Todo intercambio debe pasar por la API REST usando HTTP y JSON.

## URLs base

Local:

```text
http://localhost:8080/api
```

Publica con ngrok:

```text
https://irregular-mothball-flyover.ngrok-free.dev/api
```

## Probar conexion

```http
GET /api/status.php
```

## Enviar lectura de sensores

```http
POST /api/lecturas.php
```

```json
{
  "temperatura_c": 28.5,
  "humedad_ambiente_pct": 62.0,
  "humedad_suelo_pct": 41.3,
  "humedad_suelo_raw": 2870,
  "intensidad_luz_lux": 780.5
}
```

## Enviar estado de actuadores

```http
POST /api/actuadores.php
```

```json
{
  "ventilador": 1,
  "bomba": 0,
  "lampara": 1,
  "servo_acceso": 0,
  "modo_control": "automatico",
  "origen": "esp32"
}
```

## Registrar acceso RFID

```http
POST /api/accesos.php
```

```json
{
  "uid": "A1B2C3D4",
  "servo_abierto": 1
}
```

## Consultar comandos pendientes

```http
GET /api/comandos.php?estado=pendiente&limite=1
```

El ESP32 debe ejecutar solo estos actuadores:

- `ventilador`
- `bomba`
- `lampara`

El comando `servo_acceso` no debe ejecutarse desde la app. El servo se mantiene principalmente por RFID.

## Marcar comando como ejecutado

```http
PUT /api/comandos.php
```

```json
{
  "id": 1,
  "estado_comando": "ejecutado",
  "respuesta_esp32": "Comando ejecutado por ESP32 simulado"
}
```

## Marcar comando como fallido

```http
PUT /api/comandos.php
```

```json
{
  "id": 1,
  "estado_comando": "fallido",
  "respuesta_esp32": "No se pudo ejecutar el comando"
}
```

## Registrar evento de actuador

```http
POST /api/eventos.php
```

```json
{
  "actuador": "bomba",
  "estado_anterior": 0,
  "estado_nuevo": 1,
  "motivo": "comando_manual",
  "lectura_id": null,
  "acceso_rfid_id": null
}
```

## Reglas de integracion

- El ESP32 debe enviar JSON valido.
- La API es responsable de validar y guardar datos en MySQL.
- La base de datos no se comunica directamente con el ESP32.
- La app Android crea comandos pendientes mediante la API.
- El ESP32 consulta comandos pendientes y reporta el resultado mediante la API.
