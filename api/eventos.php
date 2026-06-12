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
            'SELECT id, actuador, estado_anterior, estado_nuevo, motivo,
                    lectura_id, acceso_rfid_id, fecha
             FROM eventos_actuadores
             ORDER BY fecha DESC, id DESC
             LIMIT :limite'
        );
        $consulta->bindValue(':limite', $limite, PDO::PARAM_INT);
        $consulta->execute();

        $eventos = array_map(
            static fn (array $fila): array => convertir_fila_enteros($fila, [
                'id',
                'estado_anterior',
                'estado_nuevo',
                'lectura_id',
                'acceso_rfid_id',
            ]),
            $consulta->fetchAll()
        );

        responder_json([
            'ok' => true,
            'eventos' => $eventos,
        ]);
    }

    $datos = leer_json_body();
    validar_campos_requeridos($datos, [
        'actuador',
        'estado_nuevo',
        'motivo',
    ]);

    $actuador = validar_enum($datos['actuador'], ['ventilador', 'bomba', 'lampara', 'servo_acceso'], 'actuador');

    if (array_key_exists('estado_anterior', $datos) && $datos['estado_anterior'] !== null && $datos['estado_anterior'] !== '') {
        $estadoAnterior = obtener_binario($datos, 'estado_anterior');
    } else {
        $estadoAnterior = null;
    }

    $estadoNuevo = obtener_binario($datos, 'estado_nuevo');
    $motivo = validar_enum($datos['motivo'], [
        'temperatura_alta',
        'temperatura_normal',
        'suelo_seco',
        'suelo_humedo',
        'luz_baja',
        'luz_suficiente',
        'rfid_autorizado',
        'rfid_rechazado',
        'comando_manual',
        'control_tomado_usuario',
        'control_liberado_usuario',
        'control_tomado_automatizacion',
        'control_liberado_automatizacion',
        'automatizacion_en_cola',
        'automatizacion_cancelada',
        'inicio_sistema',
        'desconocido',
    ], 'motivo');
    $lecturaId = obtener_entero_opcional($datos, 'lectura_id', 1);
    $accesoRfidId = obtener_entero_opcional($datos, 'acceso_rfid_id', 1);

    if ($lecturaId !== null && !recurso_existe($pdo, 'lecturas', $lecturaId)) {
        responder_error_json('La lectura indicada no existe', 400);
    }

    if ($accesoRfidId !== null && !recurso_existe($pdo, 'accesos_rfid', $accesoRfidId)) {
        responder_error_json('El acceso RFID indicado no existe', 400);
    }

    $consulta = $pdo->prepare(
        'INSERT INTO eventos_actuadores
            (actuador, estado_anterior, estado_nuevo, motivo, lectura_id, acceso_rfid_id)
         VALUES
            (:actuador, :estado_anterior, :estado_nuevo, :motivo, :lectura_id, :acceso_rfid_id)'
    );
    $consulta->bindValue(':actuador', $actuador);

    if ($estadoAnterior === null) {
        $consulta->bindValue(':estado_anterior', null, PDO::PARAM_NULL);
    } else {
        $consulta->bindValue(':estado_anterior', $estadoAnterior, PDO::PARAM_INT);
    }

    $consulta->bindValue(':estado_nuevo', $estadoNuevo, PDO::PARAM_INT);
    $consulta->bindValue(':motivo', $motivo);

    if ($lecturaId === null) {
        $consulta->bindValue(':lectura_id', null, PDO::PARAM_NULL);
    } else {
        $consulta->bindValue(':lectura_id', $lecturaId, PDO::PARAM_INT);
    }

    if ($accesoRfidId === null) {
        $consulta->bindValue(':acceso_rfid_id', null, PDO::PARAM_NULL);
    } else {
        $consulta->bindValue(':acceso_rfid_id', $accesoRfidId, PDO::PARAM_INT);
    }

    $consulta->execute();

    responder_json([
        'ok' => true,
        'mensaje' => 'Evento registrado correctamente',
        'id' => (int) $pdo->lastInsertId(),
    ], 201);
} catch (Throwable $e) {
    error_log($e->getMessage());
    responder_error_json('Error interno del servidor', 500);
}
