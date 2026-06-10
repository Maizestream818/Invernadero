# Guia de ejecucion

## Clonar el repositorio

```powershell
git clone https://github.com/Maizestream818/Invernadero.git
cd Invernadero
```

## Crear archivo `.env`

```powershell
copy .env.example .env
```

El archivo `.env` contiene valores locales de conexion y no debe subirse a Git.

## Levantar Docker

```powershell
docker compose up -d --build
```

Servicios esperados:

- `app`
- `db`
- `phpmyadmin`

## Detener Docker

```powershell
docker compose down
```

## Reiniciar desde cero

Este comando elimina tambien el volumen de MySQL y vuelve a crear la base de datos desde `sql/init.sql`.

```powershell
docker compose down -v
docker compose up -d --build
```

## Entrar a phpMyAdmin

Abrir:

```text
http://localhost:8081
```

Credenciales:

- Servidor: `db`
- Usuario: `invernadero_user`
- Contrasena: `invernadero_pass`
- Base de datos: `invernadero_iot`

## Abrir panel web

```text
http://localhost:8080/web/
```

## Probar API status

```text
http://localhost:8080/api/status.php
```

## Correr pruebas

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase1.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase2.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase3.ps1
powershell -ExecutionPolicy Bypass -File .\tests\probar_fase4.ps1
```
