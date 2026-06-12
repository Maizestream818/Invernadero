<?php
declare(strict_types=1);

require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/config.php';

configurar_headers_json();
validar_metodo_http(['GET', 'POST', 'PUT']);

try {
    $pdo = obtener_conexion_bd();
    $metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';

    if ($metodo === 'GET') {
        $estado = $_GET['estado'] ?? 'pendiente';
        $estado = validar_enum((string) $estado, ['pendiente', 'ejecutada', 'cancelada'], 'estado');

        responder_json([
            'ok' => true,
            'cola' => obtener_cola_automatizacion($pdo, $estado),
        ]);
    }

    if ($metodo === 'POST') {
        $datos = leer_json_body();
        validar_campos_requeridos($datos, [
            'actuador',
            'accion',
            'motivo',
        ]);

        $actuador = validar_enum($datos['actuador'], ['ventilador', 'bomba', 'lampara'], 'actuador');
        $accion = validar_enum($datos['accion'], ['encender'], 'accion');
        $motivo = validar_enum($datos['motivo'], ['temperatura_alta', 'suelo_seco', 'luz_baja'], 'motivo');
        $lecturaId = obtener_entero_opcional($datos, 'lectura_id', 1);
        $detalle = obtener_texto_opcional($datos, 'detalle', 255);

        if ($lecturaId !== null && !recurso_existe($pdo, 'lecturas', $lecturaId)) {
            responder_error_json('La lectura indicada no existe', 400);
        }

        $existente = $pdo->prepare(
            'SELECT id
             FROM cola_automatizacion
             WHERE actuador = :actuador
               AND accion = :accion
               AND estado_tarea = "pendiente"
             LIMIT 1'
        );
        $existente->bindValue(':actuador', $actuador);
        $existente->bindValue(':accion', $accion);
        $existente->execute();
        $idExistente = $existente->fetchColumn();

        if ($idExistente !== false) {
            responder_json([
                'ok' => true,
                'mensaje' => 'La tarea ya estaba en cola',
                'id' => (int) $idExistente,
                'duplicada' => true,
            ], 201);
        }

        $consulta = $pdo->prepare(
            'INSERT INTO cola_automatizacion (actuador, accion, motivo, lectura_id, detalle)
             VALUES (:actuador, :accion, :motivo, :lectura_id, :detalle)'
        );
        $consulta->bindValue(':actuador', $actuador);
        $consulta->bindValue(':accion', $accion);
        $consulta->bindValue(':motivo', $motivo);

        if ($lecturaId === null) {
            $consulta->bindValue(':lectura_id', null, PDO::PARAM_NULL);
        } else {
            $consulta->bindValue(':lectura_id', $lecturaId, PDO::PARAM_INT);
        }

        if ($detalle === null) {
            $consulta->bindValue(':detalle', null, PDO::PARAM_NULL);
        } else {
            $consulta->bindValue(':detalle', $detalle);
        }

        $consulta->execute();

        responder_json([
            'ok' => true,
            'mensaje' => 'Tarea de automatizacion en cola',
            'id' => (int) $pdo->lastInsertId(),
            'duplicada' => false,
        ], 201);
    }

    $datos = leer_json_body();
    validar_campos_requeridos($datos, [
        'id',
        'estado_tarea',
    ]);

    $id = obtener_entero($datos, 'id', 1);
    $estadoTarea = validar_enum($datos['estado_tarea'], ['ejecutada', 'cancelada'], 'estado_tarea');
    $detalle = obtener_texto_opcional($datos, 'detalle', 255);

    if (!recurso_existe($pdo, 'cola_automatizacion', $id)) {
        responder_error_json('La tarea de cola indicada no existe', 404);
    }

    $consulta = $pdo->prepare(
        'UPDATE cola_automatizacion
         SET estado_tarea = :estado_tarea,
             fecha_cierre = CURRENT_TIMESTAMP,
             detalle = :detalle
         WHERE id = :id'
    );
    $consulta->bindValue(':estado_tarea', $estadoTarea);

    if ($detalle === null) {
        $consulta->bindValue(':detalle', null, PDO::PARAM_NULL);
    } else {
        $consulta->bindValue(':detalle', $detalle);
    }

    $consulta->bindValue(':id', $id, PDO::PARAM_INT);
    $consulta->execute();

    responder_json([
        'ok' => true,
        'mensaje' => 'Tarea de cola actualizada correctamente',
    ]);
} catch (Throwable $e) {
    error_log($e->getMessage());
    responder_error_json('Error interno del servidor', 500);
}
