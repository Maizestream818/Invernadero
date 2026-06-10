$ErrorActionPreference = "Stop"

function Write-Result {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail = ""
    )

    $status = if ($Passed) { "PAS$([char]0x00D3)" } else { "FALL$([char]0x00D3)" }
    $message = "[$status] $Name"

    if ($Detail -ne "") {
        $message = "$message - $Detail"
    }

    if ($Passed) {
        Write-Host $message -ForegroundColor Green
    } else {
        Write-Host $message -ForegroundColor Red
    }
}

function Invoke-NativeCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        $detail = ($output | Out-String).Trim()
        throw "El comando fallo con codigo ${exitCode}: $FilePath $($Arguments -join ' '). $detail"
    }
}

function Invoke-NativeCommandOutput {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        $detail = ($output | Out-String).Trim()
        throw "El comando fallo con codigo ${exitCode}: $FilePath $($Arguments -join ' '). $detail"
    }

    return $output
}

function Invoke-Check {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    try {
        & $Action
        Write-Result -Name $Name -Passed $true
    } catch {
        Write-Result -Name $Name -Passed $false -Detail $_.Exception.Message
        throw
    }
}

function Invoke-DbQuery {
    param(
        [string]$Query
    )

    Invoke-NativeCommandOutput -FilePath "docker" -Arguments @(
        "compose",
        "exec",
        "-T",
        "-e",
        "MYSQL_PWD=invernadero_pass",
        "db",
        "mysql",
        "-uinvernadero_user",
        "invernadero_iot",
        "-N",
        "-e",
        $Query
    )
}

function Wait-For-MySql {
    $maxAttempts = 60
    $lastOutput = ""

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        try {
            $output = & docker compose exec -T -e MYSQL_PWD=invernadero_pass db mysqladmin ping -uinvernadero_user --silent 2>&1
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        $lastOutput = ($output | Out-String).Trim()

        if ($exitCode -eq 0) {
            return
        }

        Start-Sleep -Seconds 2
    }

    throw "MySQL no estuvo listo despues de $maxAttempts intentos. $lastOutput"
}

$expectedServices = @("app", "db", "phpmyadmin")
$expectedTables = @(
    "lecturas",
    "configuracion_automatizacion",
    "estados_actuadores",
    "tarjetas_rfid",
    "accesos_rfid",
    "eventos_actuadores",
    "comandos_actuadores",
    "calibraciones_sensores"
)

Write-Host "Pruebas Fase 1 - Invernadero Inteligente IoT"
Write-Host "================================================"

Invoke-Check "Docker disponible" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("--version")
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "version")
}

Invoke-Check "Servicios levantados con Docker Compose" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "up", "-d", "--build")
}

Invoke-Check "MySQL listo" {
    Wait-For-MySql
}

Invoke-Check "Servicios requeridos existen" {
    $services = Invoke-NativeCommandOutput -FilePath "docker" -Arguments @("compose", "ps", "--services")

    foreach ($service in $expectedServices) {
        if ($services -notcontains $service) {
            throw "No existe el servicio requerido: $service"
        }
    }
}

Invoke-Check "Tablas requeridas existen" {
    $tables = Invoke-DbQuery "SHOW TABLES;"

    foreach ($table in $expectedTables) {
        if ($tables -notcontains $table) {
            throw "No existe la tabla requerida: $table"
        }
    }
}

Invoke-Check "Insertar lectura de prueba" {
    Invoke-DbQuery "INSERT INTO lecturas (temperatura_c, humedad_ambiente_pct, humedad_suelo_pct, humedad_suelo_raw, intensidad_luz_lux) VALUES (24.50, 60.00, 42.00, 1800, 650.00);" | Out-Null
}

$lecturaId = ((Invoke-DbQuery "SELECT id FROM lecturas ORDER BY id DESC LIMIT 1;") | Select-Object -First 1).Trim()

Invoke-Check "Insertar estado de actuadores de prueba" {
    Invoke-DbQuery "INSERT INTO estados_actuadores (lectura_id, ventilador, bomba, lampara, servo_acceso, modo_control, origen) VALUES ($lecturaId, 0, 1, 0, 0, 'automatico', 'sistema');" | Out-Null
}

Invoke-Check "Insertar acceso RFID de prueba" {
    $tarjetaId = ((Invoke-DbQuery "SELECT id FROM tarjetas_rfid WHERE uid = 'A1B2C3D4' LIMIT 1;") | Select-Object -First 1).Trim()
    Invoke-DbQuery "INSERT INTO accesos_rfid (uid, tarjeta_id, autorizado, servo_abierto) VALUES ('A1B2C3D4', $tarjetaId, 1, 1);" | Out-Null
}

Invoke-Check "Endpoint /api/status.php responde JSON valido" {
    $response = Invoke-RestMethod -Uri "http://localhost:8080/api/status.php" -Method Get

    if ($response.ok -ne $true) {
        throw "El campo ok no es true."
    }

    if ($response.conexion_bd -ne $true) {
        throw "El campo conexion_bd no es true."
    }

    if ($response.base_datos -ne "invernadero_iot") {
        throw "La base de datos devuelta no es invernadero_iot."
    }
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Todas las pruebas de Fase 1 finalizaron correctamente.") -ForegroundColor Green
