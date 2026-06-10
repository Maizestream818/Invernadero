# Guia de entrega

## Partes implementadas

El proyecto actual cumple con:

- API REST propia en PHP.
- Conexion a MySQL mediante PDO.
- Base de datos MySQL.
- phpMyAdmin para administracion.
- Almacenamiento historico de lecturas, accesos, eventos, comandos y estados.
- Panel web HTML/CSS/JS para monitoreo.
- Comunicacion JSON entre frontend y backend.
- Preparacion para envio futuro de datos desde ESP32.
- Preparacion para app Android futura.
- Exposicion externa mediante ngrok.

## Partes fuera de esta etapa

No estan implementados en esta etapa:

- App Android.
- Codigo ESP32.
- Electronica fisica.
- Login.
- Roles.
- Control manual desde web.
- Frameworks frontend o backend.
- MQTT.
- WebSockets.

## Alcance actual

El sistema permite levantar una infraestructura portable con Docker, consultar y registrar datos mediante API REST, revisar la base con phpMyAdmin y monitorear el invernadero desde un panel web.

La App Android y el codigo ESP32 quedan para una etapa posterior.
