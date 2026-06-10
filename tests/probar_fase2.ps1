$ErrorActionPreference = "Stop"
$BaseUrl = "http://localhost:8080"

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

function Get-ErrorResponseContent {
    param(
        [object]$ErrorRecord
    )

    if ($ErrorRecord.ErrorDetails -ne $null -and $ErrorRecord.ErrorDetails.Message) {
        return $ErrorRecord.ErrorDetails.Message
    }

    if ($ErrorRecord.Exception.Response -eq $null) {
        throw $ErrorRecord.Exception
    }

    $stream = $ErrorRecord.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    return $reader.ReadToEnd()
}

function Invoke-ApiJson {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body = $null,
        [int]$ExpectedStatus = 200
    )

    $uri = "$BaseUrl$Path"
    $params = @{
        Uri = $uri
        Method = $Method
        UseBasicParsing = $true
        Headers = @{
            Accept = "application/json"
        }
    }

    if ($Body -ne $null) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
        $params.ContentType = "application/json"
    }

    try {
        $response = Invoke-WebRequest @params
        $statusCode = [int]$response.StatusCode
        $content = $response.Content
    } catch {
        $statusCode = [int]$_.Exception.Response.StatusCode
        $content = Get-ErrorResponseContent -ErrorRecord $_
    }

    if ($statusCode -ne $ExpectedStatus) {
        throw "HTTP esperado $ExpectedStatus, recibido $statusCode. Respuesta: $content"
    }

    try {
        return $content | ConvertFrom-Json
    } catch {
        throw "La respuesta no es JSON valido: $content"
    }
}

Write-Host "Pruebas Fase 2 - Invernadero Inteligente IoT"
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

Invoke-Check "Fase 1: /api/status.php sigue funcionando" {
    $response = Invoke-ApiJson -Method "GET" -Path "/api/status.php"

    if ($response.ok -ne $true -or $response.conexion_bd -ne $true) {
        throw "El endpoint status no reporta conexion_bd true."
    }
}

Invoke-Check "POST /api/lecturas.php" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/lecturas.php" -ExpectedStatus 201 -Body @{
        temperatura_c = 28.5
        humedad_ambiente_pct = 62.0
        humedad_suelo_pct = 41.3
        humedad_suelo_raw = 2870
        intensidad_luz_lux = 780.5
    }

    if ($response.ok -ne $true -or $response.id -lt 1) {
        throw "No se guardo la lectura correctamente."
    }

    $script:LecturaId = [int]$response.id
}

Invoke-Check "GET /api/lecturas.php" {
    $response = Invoke-ApiJson -Method "GET" -Path "/api/lecturas.php?limite=10"
    $lecturas = @($response.lecturas)

    if ($response.ok -ne $true -or $lecturas.Count -lt 1) {
        throw "No se recibieron lecturas."
    }
}

Invoke-Check "POST invalido /api/lecturas.php responde error JSON" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/lecturas.php" -ExpectedStatus 400 -Body @{
        temperatura_c = 28.5
        humedad_ambiente_pct = 150
        humedad_suelo_pct = 41.3
        intensidad_luz_lux = 780.5
    }

    if ($response.ok -ne $false) {
        throw "La lectura invalida no devolvio ok=false."
    }
}

Invoke-Check "POST /api/actuadores.php" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/actuadores.php" -ExpectedStatus 201 -Body @{
        lectura_id = $script:LecturaId
        ventilador = 1
        bomba = 0
        lampara = 1
        servo_acceso = 0
        modo_control = "automatico"
        origen = "esp32"
    }

    if ($response.ok -ne $true -or $response.id -lt 1) {
        throw "No se guardo el estado de actuadores."
    }
}

Invoke-Check "GET /api/actuadores.php" {
    $response = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"

    if ($response.ok -ne $true -or $response.estado -eq $null) {
        throw "No se recibio el ultimo estado de actuadores."
    }
}

Invoke-Check "POST invalido /api/actuadores.php responde error JSON" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/actuadores.php" -ExpectedStatus 400 -Body @{
        ventilador = 2
        bomba = 0
        lampara = 1
        servo_acceso = 0
        modo_control = "automatico"
        origen = "esp32"
    }

    if ($response.ok -ne $false) {
        throw "El estado invalido no devolvio ok=false."
    }
}

Invoke-Check "GET /api/configuracion.php" {
    $response = Invoke-ApiJson -Method "GET" -Path "/api/configuracion.php"

    if ($response.ok -ne $true -or $response.configuracion -eq $null) {
        throw "No se recibio configuracion."
    }
}

Invoke-Check "PUT /api/configuracion.php" {
    $response = Invoke-ApiJson -Method "PUT" -Path "/api/configuracion.php" -Body @{
        temperatura_max_c = 31
        humedad_suelo_min_pct = 36
        luz_min_lux = 520
        ventilacion_automatica = 1
        riego_automatico = 1
        iluminacion_automatica = 1
        duracion_riego_seg = 6
        intervalo_lectura_seg = 11
    }

    if ($response.ok -ne $true) {
        throw "No se actualizo la configuracion."
    }
}

Invoke-Check "POST /api/accesos.php con UID demo autorizado" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/accesos.php" -ExpectedStatus 201 -Body @{
        uid = "A1B2C3D4"
        servo_abierto = 1
    }

    if ($response.ok -ne $true -or $response.autorizado -ne $true -or $response.servo_abierto -ne 1) {
        throw "El UID demo no fue autorizado correctamente."
    }

    $script:AccesoId = [int]$response.id
}

Invoke-Check "POST /api/accesos.php con UID desconocido rechazado" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/accesos.php" -ExpectedStatus 201 -Body @{
        uid = "UID_DESCONOCIDO_FASE2"
    }

    if ($response.ok -ne $true -or $response.autorizado -ne $false -or $response.servo_abierto -ne 0) {
        throw "El UID desconocido no fue rechazado correctamente."
    }
}

Invoke-Check "GET /api/accesos.php" {
    $response = Invoke-ApiJson -Method "GET" -Path "/api/accesos.php?limite=10"
    $accesos = @($response.accesos)

    if ($response.ok -ne $true -or $accesos.Count -lt 1) {
        throw "No se recibieron accesos RFID."
    }
}

Invoke-Check "POST /api/comandos.php" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/comandos.php" -ExpectedStatus 201 -Body @{
        actuador = "bomba"
        estado_solicitado = 1
        origen = "app"
    }

    if ($response.ok -ne $true -or $response.id -lt 1) {
        throw "No se creo el comando."
    }

    $script:ComandoId = [int]$response.id
}

Invoke-Check "GET /api/comandos.php?estado=pendiente" {
    $response = Invoke-ApiJson -Method "GET" -Path "/api/comandos.php?estado=pendiente&limite=20"
    $comandos = @($response.comandos)
    $encontrado = $false

    foreach ($comando in $comandos) {
        if ([int]$comando.id -eq $script:ComandoId -and $comando.estado_comando -eq "pendiente") {
            $encontrado = $true
        }
    }

    if ($response.ok -ne $true -or -not $encontrado) {
        throw "No se encontro el comando pendiente creado."
    }
}

Invoke-Check "PUT /api/comandos.php marca comando ejecutado" {
    $response = Invoke-ApiJson -Method "PUT" -Path "/api/comandos.php" -Body @{
        id = $script:ComandoId
        estado_comando = "ejecutado"
        respuesta_esp32 = "Bomba encendida correctamente"
    }

    if ($response.ok -ne $true) {
        throw "No se actualizo el comando."
    }
}

Invoke-Check "POST /api/comandos.php no permite servo_acceso" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/comandos.php" -ExpectedStatus 400 -Body @{
        actuador = "servo_acceso"
        estado_solicitado = 1
        origen = "app"
    }

    if ($response.ok -ne $false) {
        throw "El comando para servo_acceso no fue rechazado."
    }
}

Invoke-Check "POST /api/eventos.php" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/eventos.php" -ExpectedStatus 201 -Body @{
        actuador = "ventilador"
        estado_anterior = 0
        estado_nuevo = 1
        motivo = "temperatura_alta"
        lectura_id = $script:LecturaId
        acceso_rfid_id = $null
    }

    if ($response.ok -ne $true -or $response.id -lt 1) {
        throw "No se registro el evento."
    }
}

Invoke-Check "GET /api/eventos.php" {
    $response = Invoke-ApiJson -Method "GET" -Path "/api/eventos.php?limite=10"
    $eventos = @($response.eventos)

    if ($response.ok -ne $true -or $eventos.Count -lt 1) {
        throw "No se recibieron eventos."
    }
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Todas las pruebas de Fase 2 finalizaron correctamente.") -ForegroundColor Green
