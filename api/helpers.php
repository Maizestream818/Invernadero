<?php
declare(strict_types=1);

function configurar_headers_json(): void
{
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');

    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function responder_json(array $datos, int $codigoHttp = 200): void
{
    http_response_code($codigoHttp);
    echo json_encode($datos, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function responder_error_json(string $mensaje, int $codigoHttp = 400, array $extra = []): void
{
    responder_json(array_merge([
        'ok' => false,
        'mensaje' => $mensaje,
    ], $extra), $codigoHttp);
}

function leer_json_body(): array
{
    $contenido = file_get_contents('php://input');

    if ($contenido === false || trim($contenido) === '') {
        return [];
    }

    $datos = json_decode($contenido, true);

    if (json_last_error() !== JSON_ERROR_NONE || !is_array($datos)) {
        responder_error_json('JSON invalido', 400);
    }

    return $datos;
}

function validar_metodo_http(array $metodosPermitidos): void
{
    $metodo = $_SERVER['REQUEST_METHOD'] ?? '';
    $metodosPermitidos = array_map('strtoupper', $metodosPermitidos);

    if (!in_array(strtoupper($metodo), $metodosPermitidos, true)) {
        responder_error_json('Metodo HTTP no permitido', 405, [
            'metodos_permitidos' => $metodosPermitidos,
        ]);
    }
}
