# Guia de ngrok

## Que es ngrok dentro del proyecto

ngrok permite exponer temporalmente el servidor local del proyecto a internet. En este proyecto se usa para compartir el panel web y la API REST que corren en Docker sobre el puerto `8080`.

ngrok no reemplaza Docker, PHP, Apache ni MySQL. Solo crea una URL publica que apunta al servidor local.

## Puerto expuesto

El servicio `app` de Docker publica Apache en:

```text
http://localhost:8080
```

Por eso ngrok debe exponer el puerto `8080`.

## Comando

Con Docker levantado, ejecutar:

```powershell
ngrok http 8080
```

ngrok mostrara una URL publica parecida a:

```text
https://ejemplo.ngrok-free.app
```

## Probar el panel web con la URL publica

Si la URL publica es:

```text
https://ejemplo.ngrok-free.app
```

Abrir:

```text
https://ejemplo.ngrok-free.app/web/
```

## Probar la API con la URL publica

Estado de la API:

```text
https://ejemplo.ngrok-free.app/api/status.php
```

Lecturas:

```text
https://ejemplo.ngrok-free.app/api/lecturas.php
```

Actuadores:

```text
https://ejemplo.ngrok-free.app/api/actuadores.php
```

Accesos RFID:

```text
https://ejemplo.ngrok-free.app/api/accesos.php
```

## Nota importante

En el plan gratuito de ngrok, la URL puede cambiar cada vez que se reinicia ngrok. Si la URL cambia, hay que compartir la nueva URL.
