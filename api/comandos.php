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
        $limite = obtener_limite();
        $estado = $_GET['estado'] ?? null;
        $estadosPermitidos = ['pendiente', 'ejecutado', 'fallido', 'cancelado'];

        if ($estado !== null && $estado !== '') {
            $estado = validar_enum((string) $estado, $estadosPermitidos, 'estado');
            $consulta = $pdo->prepare(
                'SELECT id, actuador, estado_solicitado, origen, estado_comando,
                        fecha_creacion, fecha_ejecucion, respuesta_esp32
                 FROM comandos_actuadores
                 WHERE estado_comando = :estado
                 ORDER BY fecha_creacion DESC, id DESC
                 LIMIT :limite'
            );
            $consulta->bindValue(':estado', $estado);
        } else {
            $consulta = $pdo->prepare(
                'SELECT id, actuador, estado_solicitado, origen, estado_comando,
                        fecha_creacion, fecha_ejecucion, respuesta_esp32
                 FROM comandos_actuadores
                 ORDER BY fecha_creacion DESC, id DESC
                 LIMIT :limite'
            );
        }

        $consulta->bindValue(':limite', $limite, PDO::PARAM_INT);
        $consulta->execute();

        $comandos = array_map(
            static fn (array $fila): array => convertir_fila_enteros($fila, [
                'id',
                'estado_solicitado',
            ]),
            $consulta->fetchAll()
        );

        responder_json([
            'ok' => true,
            'comandos' => $comandos,
        ]);
    }

    if ($metodo === 'POST') {
        $datos = leer_json_body();
        validar_campos_requeridos($datos, [
            'actuador',
            'estado_solicitado',
            'origen',
        ]);

        $actuador = validar_enum($datos['actuador'], ['ventilador', 'bomba', 'lampara'], 'actuador');
        $estadoSolicitado = obtener_binario($datos, 'estado_solicitado');
        $origen = validar_enum($datos['origen'], ['web', 'app'], 'origen');

        $consulta = $pdo->prepare(
            'INSERT INTO comandos_actuadores (actuador, estado_solicitado, origen)
             VALUES (:actuador, :estado_solicitado, :origen)'
        );
        $consulta->bindValue(':actuador', $actuador);
        $consulta->bindValue(':estado_solicitado', $estadoSolicitado, PDO::PARAM_INT);
        $consulta->bindValue(':origen', $origen);
        $consulta->execute();

        responder_json([
            'ok' => true,
            'mensaje' => 'Comando creado correctamente',
            'id' => (int) $pdo->lastInsertId(),
        ], 201);
    }

    $datos = leer_json_body();
    validar_campos_requeridos($datos, [
        'id',
        'estado_comando',
    ]);

    $id = obtener_entero($datos, 'id', 1);
    $estadoComando = validar_enum($datos['estado_comando'], ['ejecutado', 'fallido', 'cancelado'], 'estado_comando');
    $respuestaEsp32 = obtener_texto_opcional($datos, 'respuesta_esp32', 255);

    if (!recurso_existe($pdo, 'comandos_actuadores', $id)) {
        responder_error_json('El comando indicado no existe', 404);
    }

    $consulta = $pdo->prepare(
        'UPDATE comandos_actuadores
         SET estado_comando = :estado_comando,
             respuesta_esp32 = :respuesta_esp32,
             fecha_ejecucion = CURRENT_TIMESTAMP
         WHERE id = :id'
    );
    $consulta->bindValue(':estado_comando', $estadoComando);

    if ($respuestaEsp32 === null) {
        $consulta->bindValue(':respuesta_esp32', null, PDO::PARAM_NULL);
    } else {
        $consulta->bindValue(':respuesta_esp32', $respuestaEsp32);
    }

    $consulta->bindValue(':id', $id, PDO::PARAM_INT);
    $consulta->execute();

    responder_json([
        'ok' => true,
        'mensaje' => 'Comando actualizado correctamente',
    ]);
} catch (Throwable $e) {
    error_log($e->getMessage());
    responder_error_json('Error interno del servidor', 500);
}
