<?php
declare(strict_types=1);

ini_set('display_errors', '0');
ini_set('html_errors', '0');
error_reporting(E_ALL);

require_once __DIR__ . '/helpers.php';

configurar_headers_json();
validar_metodo_http(['GET']);

try {
    require_once __DIR__ . '/config.php';

    $pdo = obtener_conexion_bd();
    $consulta = $pdo->query('SELECT DATABASE() AS base_datos');
    $resultado = $consulta !== false ? $consulta->fetch() : false;

    responder_json([
        'ok' => true,
        'mensaje' => 'API funcionando correctamente',
        'servicio' => 'Invernadero Inteligente IoT',
        'base_datos' => $resultado['base_datos'] ?? null,
        'conexion_bd' => true,
    ]);
} catch (Throwable $e) {
    error_log($e->getMessage());

    responder_json([
        'ok' => false,
        'mensaje' => 'Error de conexión a la base de datos',
        'conexion_bd' => false,
    ], 500);
}
