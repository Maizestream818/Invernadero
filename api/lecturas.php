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
            'SELECT id, temperatura_c, humedad_ambiente_pct, humedad_suelo_pct,
                    humedad_suelo_raw, intensidad_luz_lux, fecha
             FROM lecturas
             ORDER BY fecha DESC, id DESC
             LIMIT :limite'
        );
        $consulta->bindValue(':limite', $limite, PDO::PARAM_INT);
        $consulta->execute();

        $lecturas = array_map(
            static fn (array $fila): array => convertir_fila_enteros($fila, ['id', 'humedad_suelo_raw']),
            $consulta->fetchAll()
        );

        responder_json([
            'ok' => true,
            'lecturas' => $lecturas,
        ]);
    }

    $datos = leer_json_body();
    validar_campos_requeridos($datos, [
        'temperatura_c',
        'humedad_ambiente_pct',
        'humedad_suelo_pct',
        'intensidad_luz_lux',
    ]);

    $temperatura = obtener_numero($datos, 'temperatura_c');
    $humedadAmbiente = obtener_numero($datos, 'humedad_ambiente_pct', 0, 100);
    $humedadSuelo = obtener_numero($datos, 'humedad_suelo_pct', 0, 100);
    $humedadSueloRaw = obtener_entero_opcional($datos, 'humedad_suelo_raw');
    $intensidadLuz = obtener_numero($datos, 'intensidad_luz_lux', 0);

    $consulta = $pdo->prepare(
        'INSERT INTO lecturas
            (temperatura_c, humedad_ambiente_pct, humedad_suelo_pct, humedad_suelo_raw, intensidad_luz_lux)
         VALUES
            (:temperatura_c, :humedad_ambiente_pct, :humedad_suelo_pct, :humedad_suelo_raw, :intensidad_luz_lux)'
    );
    $consulta->bindValue(':temperatura_c', $temperatura);
    $consulta->bindValue(':humedad_ambiente_pct', $humedadAmbiente);
    $consulta->bindValue(':humedad_suelo_pct', $humedadSuelo);

    if ($humedadSueloRaw === null) {
        $consulta->bindValue(':humedad_suelo_raw', null, PDO::PARAM_NULL);
    } else {
        $consulta->bindValue(':humedad_suelo_raw', $humedadSueloRaw, PDO::PARAM_INT);
    }

    $consulta->bindValue(':intensidad_luz_lux', $intensidadLuz);
    $consulta->execute();

    responder_json([
        'ok' => true,
        'mensaje' => 'Lectura guardada correctamente',
        'id' => (int) $pdo->lastInsertId(),
    ], 201);
} catch (Throwable $e) {
    error_log($e->getMessage());
    responder_error_json('Error interno del servidor', 500);
}
