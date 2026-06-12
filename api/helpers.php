<?php
declare(strict_types=1);

ini_set('display_errors', '0');
ini_set('html_errors', '0');
error_reporting(E_ALL);

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

function obtener_limite(int $valorPorDefecto = 20, int $maximo = 100): int
{
    if (!isset($_GET['limite']) || $_GET['limite'] === '') {
        return $valorPorDefecto;
    }

    $limite = filter_var($_GET['limite'], FILTER_VALIDATE_INT);

    if ($limite === false || $limite < 1 || $limite > $maximo) {
        responder_error_json("El parametro limite debe ser un entero entre 1 y {$maximo}", 400);
    }

    return $limite;
}

function validar_campos_requeridos(array $datos, array $campos): void
{
    $faltantes = [];

    foreach ($campos as $campo) {
        if (!array_key_exists($campo, $datos) || $datos[$campo] === null || $datos[$campo] === '') {
            $faltantes[] = $campo;
        }
    }

    if ($faltantes !== []) {
        responder_error_json('Faltan campos obligatorios', 400, [
            'campos' => $faltantes,
        ]);
    }
}

function es_binario(mixed $valor): bool
{
    if (is_int($valor)) {
        return $valor === 0 || $valor === 1;
    }

    if (is_string($valor)) {
        return $valor === '0' || $valor === '1';
    }

    return false;
}

function obtener_binario(array $datos, string $campo): int
{
    if (!array_key_exists($campo, $datos) || !es_binario($datos[$campo])) {
        responder_error_json("El campo {$campo} debe ser 0 o 1", 400);
    }

    return (int) $datos[$campo];
}

function validar_enum(mixed $valor, array $permitidos, string $campo): string
{
    if (!is_string($valor) || !in_array($valor, $permitidos, true)) {
        responder_error_json("El campo {$campo} tiene un valor no permitido", 400, [
            'permitidos' => $permitidos,
        ]);
    }

    return $valor;
}

function obtener_numero(array $datos, string $campo, ?float $minimo = null, ?float $maximo = null): float
{
    if (!array_key_exists($campo, $datos) || !is_numeric($datos[$campo])) {
        responder_error_json("El campo {$campo} debe ser numerico", 400);
    }

    $valor = (float) $datos[$campo];

    if ($minimo !== null && $valor < $minimo) {
        responder_error_json("El campo {$campo} debe ser mayor o igual a {$minimo}", 400);
    }

    if ($maximo !== null && $valor > $maximo) {
        responder_error_json("El campo {$campo} debe ser menor o igual a {$maximo}", 400);
    }

    return $valor;
}

function obtener_entero(array $datos, string $campo, ?int $minimo = null, ?int $maximo = null): int
{
    if (!array_key_exists($campo, $datos)) {
        responder_error_json("El campo {$campo} debe ser entero", 400);
    }

    $valor = filter_var($datos[$campo], FILTER_VALIDATE_INT);

    if ($valor === false) {
        responder_error_json("El campo {$campo} debe ser entero", 400);
    }

    if ($minimo !== null && $valor < $minimo) {
        responder_error_json("El campo {$campo} debe ser mayor o igual a {$minimo}", 400);
    }

    if ($maximo !== null && $valor > $maximo) {
        responder_error_json("El campo {$campo} debe ser menor o igual a {$maximo}", 400);
    }

    return $valor;
}

function obtener_entero_opcional(array $datos, string $campo, ?int $minimo = null, ?int $maximo = null): ?int
{
    if (!array_key_exists($campo, $datos) || $datos[$campo] === null || $datos[$campo] === '') {
        return null;
    }

    return obtener_entero($datos, $campo, $minimo, $maximo);
}

function obtener_texto(array $datos, string $campo, int $maximoCaracteres, bool $permitirVacio = false): string
{
    if (!array_key_exists($campo, $datos) || !is_string($datos[$campo])) {
        responder_error_json("El campo {$campo} debe ser texto", 400);
    }

    $valor = trim($datos[$campo]);

    if (!$permitirVacio && $valor === '') {
        responder_error_json("El campo {$campo} no puede estar vacio", 400);
    }

    if (strlen($valor) > $maximoCaracteres) {
        responder_error_json("El campo {$campo} no puede superar {$maximoCaracteres} caracteres", 400);
    }

    return $valor;
}

function obtener_texto_opcional(array $datos, string $campo, int $maximoCaracteres): ?string
{
    if (!array_key_exists($campo, $datos) || $datos[$campo] === null) {
        return null;
    }

    return obtener_texto($datos, $campo, $maximoCaracteres, true);
}

function recurso_existe(PDO $pdo, string $tabla, int $id): bool
{
    $tablasPermitidas = [
        'lecturas',
        'accesos_rfid',
        'comandos_actuadores',
        'cola_automatizacion',
    ];

    if (!in_array($tabla, $tablasPermitidas, true)) {
        throw new InvalidArgumentException('Tabla no permitida para validacion');
    }

    $consulta = $pdo->prepare("SELECT 1 FROM {$tabla} WHERE id = :id LIMIT 1");
    $consulta->bindValue(':id', $id, PDO::PARAM_INT);
    $consulta->execute();

    return $consulta->fetchColumn() !== false;
}

function obtener_ultimo_estado_actuadores(PDO $pdo): ?array
{
    $consulta = $pdo->query(
        'SELECT id, lectura_id, ventilador, bomba, lampara, servo_acceso,
                control_ventilador, control_bomba, control_lampara,
                modo_control, origen, fecha
         FROM estados_actuadores
         ORDER BY fecha DESC, id DESC
         LIMIT 1'
    );

    $estado = $consulta !== false ? $consulta->fetch() : false;

    return convertir_fila_enteros($estado ?: null, [
        'id',
        'lectura_id',
        'ventilador',
        'bomba',
        'lampara',
        'servo_acceso',
    ]);
}

function obtener_cola_automatizacion(PDO $pdo, string $estadoTarea = 'pendiente'): array
{
    $consulta = $pdo->prepare(
        'SELECT id, actuador, accion, motivo, lectura_id, estado_tarea,
                fecha_creacion, fecha_cierre, detalle
         FROM cola_automatizacion
         WHERE estado_tarea = :estado_tarea
         ORDER BY fecha_creacion ASC, id ASC'
    );
    $consulta->bindValue(':estado_tarea', $estadoTarea);
    $consulta->execute();

    return array_map(
        static fn (array $fila): array => convertir_fila_enteros($fila, [
            'id',
            'lectura_id',
        ]),
        $consulta->fetchAll()
    );
}

function convertir_fila_enteros(?array $fila, array $campos): ?array
{
    if ($fila === null || $fila === false) {
        return null;
    }

    foreach ($campos as $campo) {
        if (array_key_exists($campo, $fila) && $fila[$campo] !== null) {
            $fila[$campo] = (int) $fila[$campo];
        }
    }

    return $fila;
}
