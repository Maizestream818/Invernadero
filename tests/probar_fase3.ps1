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

function Invoke-WebOk {
    param(
        [string]$Path,
        [int]$ExpectedStatus = 200
    )

    $response = Invoke-WebRequest -Uri "$BaseUrl$Path" -Method GET -UseBasicParsing

    if ([int]$response.StatusCode -ne $ExpectedStatus) {
        throw "HTTP esperado $ExpectedStatus, recibido $($response.StatusCode)."
    }

    return $response
}

Write-Host "Pruebas Fase 3 - Invernadero Inteligente IoT"
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

Invoke-Check "GET /api/status.php sigue funcionando" {
    $response = Invoke-ApiJson -Method "GET" -Path "/api/status.php"

    if ($response.ok -ne $true -or $response.conexion_bd -ne $true) {
        throw "El endpoint status no reporta conexion_bd true."
    }
}

Invoke-Check "Endpoints principales de Fase 2 responden" {
    $endpoints = @(
        "/api/lecturas.php",
        "/api/actuadores.php",
        "/api/accesos.php",
        "/api/configuracion.php",
        "/api/comandos.php",
        "/api/eventos.php"
    )

    foreach ($endpoint in $endpoints) {
        $response = Invoke-ApiJson -Method "GET" -Path $endpoint

        if ($response.ok -ne $true) {
            throw "Endpoint $endpoint no devolvio ok=true."
        }
    }
}

Invoke-Check "POST /api/lecturas.php para datos de prueba" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/lecturas.php" -ExpectedStatus 201 -Body @{
        temperatura_c = 27.8
        humedad_ambiente_pct = 61.5
        humedad_suelo_pct = 44.2
        humedad_suelo_raw = 2810
        intensidad_luz_lux = 735.4
    }

    if ($response.ok -ne $true -or $response.id -lt 1) {
        throw "No se inserto lectura de prueba."
    }

    $script:LecturaId = [int]$response.id
}

Invoke-Check "POST /api/actuadores.php para datos de prueba" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/actuadores.php" -ExpectedStatus 201 -Body @{
        lectura_id = $script:LecturaId
        ventilador = 1
        bomba = 0
        lampara = 1
        servo_acceso = 0
        modo_control = "automatico"
        origen = "sistema"
    }

    if ($response.ok -ne $true -or $response.id -lt 1) {
        throw "No se inserto estado de actuadores."
    }
}

Invoke-Check "POST /api/accesos.php para datos de prueba" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/accesos.php" -ExpectedStatus 201 -Body @{
        uid = "A1B2C3D4"
    }

    if ($response.ok -ne $true -or $response.autorizado -ne $true -or $response.id -lt 1) {
        throw "No se registro acceso RFID autorizado."
    }

    $script:AccesoId = [int]$response.id
}

Invoke-Check "POST /api/comandos.php para datos de prueba" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/comandos.php" -ExpectedStatus 201 -Body @{
        actuador = "bomba"
        estado_solicitado = 1
        origen = "app"
    }

    if ($response.ok -ne $true -or $response.id -lt 1) {
        throw "No se creo comando de prueba."
    }
}

Invoke-Check "POST /api/eventos.php para datos de prueba" {
    $response = Invoke-ApiJson -Method "POST" -Path "/api/eventos.php" -ExpectedStatus 201 -Body @{
        actuador = "servo_acceso"
        estado_anterior = 0
        estado_nuevo = 1
        motivo = "rfid_autorizado"
        lectura_id = $null
        acceso_rfid_id = $script:AccesoId
    }

    if ($response.ok -ne $true -or $response.id -lt 1) {
        throw "No se registro evento de prueba."
    }
}

Invoke-Check "La web responde HTTP 200 en /web/" {
    $response = Invoke-WebOk -Path "/web/"

    if ($response.Content -notmatch "Invernadero Inteligente IoT") {
        throw "El HTML no contiene el titulo esperado."
    }
}

Invoke-Check "web/estilos.css responde HTTP 200" {
    $response = Invoke-WebOk -Path "/web/estilos.css"

    if ($response.Content -notmatch "grid-tarjetas") {
        throw "El CSS no contiene estilos esperados."
    }
}

Invoke-Check "web/app.js responde HTTP 200" {
    $response = Invoke-WebOk -Path "/web/app.js"

    if ($response.Content -notmatch 'const API_BASE_URL = "/api";') {
        throw "app.js no contiene API_BASE_URL esperado."
    }
}

Invoke-Check "web/index.html referencia estilos.css y app.js" {
    $html = Get-Content -Raw ".\web\index.html"

    if ($html -notmatch "estilos\.css") {
        throw "index.html no referencia estilos.css."
    }

    if ($html -notmatch "app\.js") {
        throw "index.html no referencia app.js."
    }
}

Invoke-Check "web/app.js usa API_BASE_URL requerido" {
    $js = Get-Content -Raw ".\web\app.js"

    if ($js -notmatch 'const API_BASE_URL = "/api";') {
        throw "app.js no contiene const API_BASE_URL = `"/api`";"
    }
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Todas las pruebas de Fase 3 finalizaron correctamente.") -ForegroundColor Green
