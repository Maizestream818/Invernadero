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
        $limite = obtener_limite();
        $consulta = $pdo->prepare(
            'SELECT a.id, a.uid, a.tarjeta_id, t.nombre_usuario, a.autorizado,
                    a.servo_abierto, a.fecha
             FROM accesos_rfid a
             LEFT JOIN tarjetas_rfid t ON t.id = a.tarjeta_id
             ORDER BY a.fecha DESC, a.id DESC
             LIMIT :limite'
        );
        $consulta->bindValue(':limite', $limite, PDO::PARAM_INT);
        $consulta->execute();

        $accesos = array_map(
            static fn (array $fila): array => convertir_fila_enteros($fila, [
                'id',
                'tarjeta_id',
                'autorizado',
                'servo_abierto',
            ]),
            $consulta->fetchAll()
        );

        responder_json([
            'ok' => true,
            'accesos' => $accesos,
        ]);
    }

    $datos = leer_json_body();
    validar_campos_requeridos($datos, ['uid']);

    $uid = obtener_texto($datos, 'uid', 50);

    $consultaTarjeta = $pdo->prepare(
        'SELECT id, activa FROM tarjetas_rfid WHERE uid = :uid LIMIT 1'
    );
    $consultaTarjeta->bindValue(':uid', $uid);
    $consultaTarjeta->execute();
    $tarjeta = $consultaTarjeta->fetch();

    $tarjetaId = $tarjeta !== false ? (int) $tarjeta['id'] : null;
    $autorizado = $tarjeta !== false && (int) $tarjeta['activa'] === 1 ? 1 : 0;

    if (array_key_exists('servo_abierto', $datos) && $datos['servo_abierto'] !== null && $datos['servo_abierto'] !== '') {
        $servoAbierto = obtener_binario($datos, 'servo_abierto');
    } else {
        $servoAbierto = $autorizado === 1 ? 1 : 0;
    }

    $consulta = $pdo->prepare(
        'INSERT INTO accesos_rfid (uid, tarjeta_id, autorizado, servo_abierto)
         VALUES (:uid, :tarjeta_id, :autorizado, :servo_abierto)'
    );
    $consulta->bindValue(':uid', $uid);

    if ($tarjetaId === null) {
        $consulta->bindValue(':tarjeta_id', null, PDO::PARAM_NULL);
    } else {
        $consulta->bindValue(':tarjeta_id', $tarjetaId, PDO::PARAM_INT);
    }

    $consulta->bindValue(':autorizado', $autorizado, PDO::PARAM_INT);
    $consulta->bindValue(':servo_abierto', $servoAbierto, PDO::PARAM_INT);
    $consulta->execute();

    responder_json([
        'ok' => true,
        'mensaje' => 'Acceso RFID registrado',
        'autorizado' => $autorizado === 1,
        'servo_abierto' => $servoAbierto,
        'id' => (int) $pdo->lastInsertId(),
    ], 201);
} catch (Throwable $e) {
    error_log($e->getMessage());
    responder_error_json('Error interno del servidor', 500);
}
