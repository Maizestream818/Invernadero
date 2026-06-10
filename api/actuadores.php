<?php
declare(strict_types=1);

require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/config.php';

configurar_headers_json();
validar_metodo_http(['GET', 'POST']);

try {
    $pdo = obtener_conexion_bd();
    $metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';

    if ($metodo === 'GET') {
        $consulta = $pdo->query(
            'SELECT id, lectura_id, ventilador, bomba, lampara, servo_acceso,
                    modo_control, origen, fecha
             FROM estados_actuadores
             ORDER BY fecha DESC, id DESC
             LIMIT 1'
        );
        $estado = $consulta !== false ? $consulta->fetch() : false;

        responder_json([
            'ok' => true,
            'estado' => convertir_fila_enteros($estado ?: null, [
                'id',
                'lectura_id',
                'ventilador',
                'bomba',
                'lampara',
                'servo_acceso',
            ]),
        ]);
    }

    $datos = leer_json_body();
    validar_campos_requeridos($datos, [
        'ventilador',
        'bomba',
        'lampara',
        'servo_acceso',
        'modo_control',
        'origen',
    ]);

    $lecturaId = obtener_entero_opcional($datos, 'lectura_id', 1);

    if ($lecturaId !== null && !recurso_existe($pdo, 'lecturas', $lecturaId)) {
        responder_error_json('La lectura indicada no existe', 400);
    }

    $ventilador = obtener_binario($datos, 'ventilador');
    $bomba = obtener_binario($datos, 'bomba');
    $lampara = obtener_binario($datos, 'lampara');
    $servoAcceso = obtener_binario($datos, 'servo_acceso');
    $modoControl = validar_enum($datos['modo_control'], ['automatico', 'manual'], 'modo_control');
    $origen = validar_enum($datos['origen'], ['esp32', 'web', 'app', 'sistema'], 'origen');

    $consulta = $pdo->prepare(
        'INSERT INTO estados_actuadores
            (lectura_id, ventilador, bomba, lampara, servo_acceso, modo_control, origen)
         VALUES
            (:lectura_id, :ventilador, :bomba, :lampara, :servo_acceso, :modo_control, :origen)'
    );

    if ($lecturaId === null) {
        $consulta->bindValue(':lectura_id', null, PDO::PARAM_NULL);
    } else {
        $consulta->bindValue(':lectura_id', $lecturaId, PDO::PARAM_INT);
    }

    $consulta->bindValue(':ventilador', $ventilador, PDO::PARAM_INT);
    $consulta->bindValue(':bomba', $bomba, PDO::PARAM_INT);
    $consulta->bindValue(':lampara', $lampara, PDO::PARAM_INT);
    $consulta->bindValue(':servo_acceso', $servoAcceso, PDO::PARAM_INT);
    $consulta->bindValue(':modo_control', $modoControl);
    $consulta->bindValue(':origen', $origen);
    $consulta->execute();

    responder_json([
        'ok' => true,
        'mensaje' => 'Estado de actuadores guardado correctamente',
        'id' => (int) $pdo->lastInsertId(),
    ], 201);
} catch (Throwable $e) {
    error_log($e->getMessage());
    responder_error_json('Error interno del servidor', 500);
}
