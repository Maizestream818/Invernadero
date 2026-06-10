<?php
declare(strict_types=1);

require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/config.php';

configurar_headers_json();
validar_metodo_http(['GET', 'PUT']);

try {
    $pdo = obtener_conexion_bd();
    $metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';

    if ($metodo === 'GET') {
        $consulta = $pdo->query(
            'SELECT id, temperatura_max_c, humedad_suelo_min_pct, luz_min_lux,
                    ventilacion_automatica, riego_automatico, iluminacion_automatica,
                    duracion_riego_seg, intervalo_lectura_seg, actualizado_en
             FROM configuracion_automatizacion
             ORDER BY id DESC
             LIMIT 1'
        );
        $configuracion = $consulta !== false ? $consulta->fetch() : false;

        responder_json([
            'ok' => true,
            'configuracion' => convertir_fila_enteros($configuracion ?: null, [
                'id',
                'ventilacion_automatica',
                'riego_automatico',
                'iluminacion_automatica',
                'duracion_riego_seg',
                'intervalo_lectura_seg',
            ]),
        ]);
    }

    $datos = leer_json_body();
    validar_campos_requeridos($datos, [
        'temperatura_max_c',
        'humedad_suelo_min_pct',
        'luz_min_lux',
        'ventilacion_automatica',
        'riego_automatico',
        'iluminacion_automatica',
        'duracion_riego_seg',
        'intervalo_lectura_seg',
    ]);

    $temperaturaMax = obtener_numero($datos, 'temperatura_max_c');
    $humedadSueloMin = obtener_numero($datos, 'humedad_suelo_min_pct', 0, 100);
    $luzMin = obtener_numero($datos, 'luz_min_lux', 0);
    $ventilacionAutomatica = obtener_binario($datos, 'ventilacion_automatica');
    $riegoAutomatico = obtener_binario($datos, 'riego_automatico');
    $iluminacionAutomatica = obtener_binario($datos, 'iluminacion_automatica');
    $duracionRiego = obtener_entero($datos, 'duracion_riego_seg', 1);
    $intervaloLectura = obtener_entero($datos, 'intervalo_lectura_seg', 1);

    $consultaActual = $pdo->query(
        'SELECT id FROM configuracion_automatizacion ORDER BY id DESC LIMIT 1'
    );
    $actual = $consultaActual !== false ? $consultaActual->fetch() : false;

    if ($actual === false) {
        responder_error_json('No existe configuracion para actualizar', 404);
    }

    $consulta = $pdo->prepare(
        'UPDATE configuracion_automatizacion
         SET temperatura_max_c = :temperatura_max_c,
             humedad_suelo_min_pct = :humedad_suelo_min_pct,
             luz_min_lux = :luz_min_lux,
             ventilacion_automatica = :ventilacion_automatica,
             riego_automatico = :riego_automatico,
             iluminacion_automatica = :iluminacion_automatica,
             duracion_riego_seg = :duracion_riego_seg,
             intervalo_lectura_seg = :intervalo_lectura_seg
         WHERE id = :id'
    );
    $consulta->bindValue(':temperatura_max_c', $temperaturaMax);
    $consulta->bindValue(':humedad_suelo_min_pct', $humedadSueloMin);
    $consulta->bindValue(':luz_min_lux', $luzMin);
    $consulta->bindValue(':ventilacion_automatica', $ventilacionAutomatica, PDO::PARAM_INT);
    $consulta->bindValue(':riego_automatico', $riegoAutomatico, PDO::PARAM_INT);
    $consulta->bindValue(':iluminacion_automatica', $iluminacionAutomatica, PDO::PARAM_INT);
    $consulta->bindValue(':duracion_riego_seg', $duracionRiego, PDO::PARAM_INT);
    $consulta->bindValue(':intervalo_lectura_seg', $intervaloLectura, PDO::PARAM_INT);
    $consulta->bindValue(':id', (int) $actual['id'], PDO::PARAM_INT);
    $consulta->execute();

    responder_json([
        'ok' => true,
        'mensaje' => 'Configuracion actualizada correctamente',
    ]);
} catch (Throwable $e) {
    error_log($e->getMessage());
    responder_error_json('Error interno del servidor', 500);
}
