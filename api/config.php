<?php
declare(strict_types=1);

ini_set('display_errors', '0');
ini_set('html_errors', '0');
error_reporting(E_ALL);

function obtener_variable_entorno(string $clave): string
{
    $valor = getenv($clave);

    if ($valor === false || $valor === '') {
        throw new RuntimeException("Variable de entorno requerida no configurada: {$clave}");
    }

    return $valor;
}

function obtener_conexion_bd(): PDO
{
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $host = obtener_variable_entorno('DB_HOST');
    $baseDatos = obtener_variable_entorno('DB_NAME');
    $usuario = obtener_variable_entorno('DB_USER');
    $password = obtener_variable_entorno('DB_PASSWORD');

    $dsn = "mysql:host={$host};dbname={$baseDatos};charset=utf8mb4";

    $pdo = new PDO($dsn, $usuario, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);

    return $pdo;
}
