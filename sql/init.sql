CREATE DATABASE IF NOT EXISTS invernadero_iot
CHARACTER SET utf8mb4
COLLATE utf8mb4_general_ci;

USE invernadero_iot;

CREATE TABLE IF NOT EXISTS lecturas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    temperatura_c DECIMAL(5,2) NOT NULL,
    humedad_ambiente_pct DECIMAL(5,2) NOT NULL,
    humedad_suelo_pct DECIMAL(5,2) NOT NULL,
    humedad_suelo_raw INT NULL,
    intensidad_luz_lux DECIMAL(10,2) NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CHECK (humedad_ambiente_pct >= 0 AND humedad_ambiente_pct <= 100),
    CHECK (humedad_suelo_pct >= 0 AND humedad_suelo_pct <= 100),
    CHECK (intensidad_luz_lux >= 0)
);

CREATE TABLE IF NOT EXISTS configuracion_automatizacion (
    id INT AUTO_INCREMENT PRIMARY KEY,
    temperatura_max_c DECIMAL(5,2) NOT NULL DEFAULT 30.00,
    humedad_suelo_min_pct DECIMAL(5,2) NOT NULL DEFAULT 35.00,
    luz_min_lux DECIMAL(10,2) NOT NULL DEFAULT 500.00,
    ventilacion_automatica TINYINT(1) NOT NULL DEFAULT 1,
    riego_automatico TINYINT(1) NOT NULL DEFAULT 1,
    iluminacion_automatica TINYINT(1) NOT NULL DEFAULT 1,
    duracion_riego_seg INT NOT NULL DEFAULT 5,
    intervalo_lectura_seg INT NOT NULL DEFAULT 10,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CHECK (humedad_suelo_min_pct >= 0 AND humedad_suelo_min_pct <= 100),
    CHECK (luz_min_lux >= 0),
    CHECK (ventilacion_automatica IN (0,1)),
    CHECK (riego_automatico IN (0,1)),
    CHECK (iluminacion_automatica IN (0,1)),
    CHECK (duracion_riego_seg > 0),
    CHECK (intervalo_lectura_seg > 0)
);

CREATE TABLE IF NOT EXISTS estados_actuadores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lectura_id INT NULL,
    ventilador TINYINT(1) NOT NULL DEFAULT 0,
    bomba TINYINT(1) NOT NULL DEFAULT 0,
    lampara TINYINT(1) NOT NULL DEFAULT 0,
    servo_acceso TINYINT(1) NOT NULL DEFAULT 0,
    control_ventilador ENUM('libre', 'usuario', 'automatizacion') NOT NULL DEFAULT 'libre',
    control_bomba ENUM('libre', 'usuario', 'automatizacion') NOT NULL DEFAULT 'libre',
    control_lampara ENUM('libre', 'usuario', 'automatizacion') NOT NULL DEFAULT 'libre',
    modo_control ENUM('automatico', 'manual') NOT NULL DEFAULT 'automatico',
    origen ENUM('esp32', 'web', 'app', 'sistema') NOT NULL DEFAULT 'esp32',
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (lectura_id) REFERENCES lecturas(id) ON DELETE SET NULL,

    CHECK (ventilador IN (0,1)),
    CHECK (bomba IN (0,1)),
    CHECK (lampara IN (0,1)),
    CHECK (servo_acceso IN (0,1))
);

CREATE TABLE IF NOT EXISTS cola_automatizacion (
    id INT AUTO_INCREMENT PRIMARY KEY,
    actuador ENUM('ventilador', 'bomba', 'lampara') NOT NULL,
    accion ENUM('encender') NOT NULL DEFAULT 'encender',
    motivo ENUM('temperatura_alta', 'suelo_seco', 'luz_baja') NOT NULL,
    lectura_id INT NULL,
    estado_tarea ENUM('pendiente', 'ejecutada', 'cancelada') NOT NULL DEFAULT 'pendiente',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre TIMESTAMP NULL,
    detalle VARCHAR(255) NULL,

    FOREIGN KEY (lectura_id) REFERENCES lecturas(id) ON DELETE SET NULL,
    INDEX idx_cola_actuador_estado (actuador, estado_tarea)
);

CREATE TABLE IF NOT EXISTS tarjetas_rfid (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uid VARCHAR(50) NOT NULL UNIQUE,
    nombre_usuario VARCHAR(100) NULL,
    activa TINYINT(1) NOT NULL DEFAULT 1,
    fecha_alta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CHECK (activa IN (0,1))
);

CREATE TABLE IF NOT EXISTS accesos_rfid (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uid VARCHAR(50) NOT NULL,
    tarjeta_id INT NULL,
    autorizado TINYINT(1) NOT NULL,
    servo_abierto TINYINT(1) NOT NULL DEFAULT 0,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (tarjeta_id) REFERENCES tarjetas_rfid(id) ON DELETE SET NULL,

    CHECK (autorizado IN (0,1)),
    CHECK (servo_abierto IN (0,1))
);

CREATE TABLE IF NOT EXISTS eventos_actuadores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    actuador ENUM('ventilador', 'bomba', 'lampara', 'servo_acceso') NOT NULL,
    estado_anterior TINYINT(1) NULL,
    estado_nuevo TINYINT(1) NOT NULL,
    motivo ENUM(
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
        'desconocido'
    ) NOT NULL DEFAULT 'desconocido',
    lectura_id INT NULL,
    acceso_rfid_id INT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (lectura_id) REFERENCES lecturas(id) ON DELETE SET NULL,
    FOREIGN KEY (acceso_rfid_id) REFERENCES accesos_rfid(id) ON DELETE SET NULL,

    CHECK (estado_anterior IS NULL OR estado_anterior IN (0,1)),
    CHECK (estado_nuevo IN (0,1))
);

CREATE TABLE IF NOT EXISTS comandos_actuadores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    actuador ENUM('ventilador', 'bomba', 'lampara') NOT NULL,
    estado_solicitado TINYINT(1) NOT NULL,
    origen ENUM('web', 'app') NOT NULL DEFAULT 'app',
    estado_comando ENUM('pendiente', 'ejecutado', 'fallido', 'cancelado') NOT NULL DEFAULT 'pendiente',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_ejecucion TIMESTAMP NULL,
    respuesta_esp32 VARCHAR(255) NULL,

    CHECK (estado_solicitado IN (0,1))
);

CREATE TABLE IF NOT EXISTS calibraciones_sensores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sensor ENUM('humedad_suelo', 'temperatura_humedad', 'luz') NOT NULL,
    valor_min_raw INT NULL,
    valor_max_raw INT NULL,
    descripcion VARCHAR(255) NULL,
    activa TINYINT(1) NOT NULL DEFAULT 1,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CHECK (activa IN (0,1))
);

INSERT INTO configuracion_automatizacion (
    temperatura_max_c,
    humedad_suelo_min_pct,
    luz_min_lux,
    ventilacion_automatica,
    riego_automatico,
    iluminacion_automatica,
    duracion_riego_seg,
    intervalo_lectura_seg
)
SELECT
    30.00,
    35.00,
    500.00,
    1,
    1,
    1,
    5,
    10
WHERE NOT EXISTS (
    SELECT 1 FROM configuracion_automatizacion
);

INSERT INTO estados_actuadores (
    lectura_id,
    ventilador,
    bomba,
    lampara,
    servo_acceso,
    control_ventilador,
    control_bomba,
    control_lampara,
    modo_control,
    origen
)
SELECT
    NULL,
    0,
    0,
    0,
    0,
    'libre',
    'libre',
    'libre',
    'automatico',
    'sistema'
WHERE NOT EXISTS (
    SELECT 1 FROM estados_actuadores
);

INSERT INTO tarjetas_rfid (uid, nombre_usuario, activa)
VALUES ('A1B2C3D4', 'Tarjeta demo', 1)
ON DUPLICATE KEY UPDATE
    nombre_usuario = VALUES(nombre_usuario),
    activa = VALUES(activa);
