$ErrorActionPreference = "Stop"

$ApiBaseUrl = "http://localhost:8080/api"
# Para probar con ngrok, cambiar a:
# $ApiBaseUrl = "https://irregular-mothball-flyover.ngrok-free.dev/api"

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
        [string]$Endpoint,
        [object]$Body = $null,
        [int]$ExpectedStatus = 200
    )

    $params = @{
        Uri = "$ApiBaseUrl$Endpoint"
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

    return $content | ConvertFrom-Json
}

Write-Host "Simulador ESP32 - Invernadero Inteligente IoT"
Write-Host "API base: $ApiBaseUrl"
Write-Host "================================================"

$script:EstadoVentilador = 0
$script:EstadoBomba = 0
$script:EstadoLampara = 0
$script:EstadoServoAcceso = 0
$script:ComandoPendiente = $null

Invoke-Check "Conexion API correcta" {
    $status = Invoke-ApiJson -Method "GET" -Endpoint "/status.php"

    if ($status.ok -ne $true -or $status.conexion_bd -ne $true) {
        throw "La API no reporta ok=true y conexion_bd=true."
    }
}

Invoke-Check "Lectura enviada" {
    $lectura = Invoke-ApiJson -Method "POST" -Endpoint "/lecturas.php" -ExpectedStatus 201 -Body @{
        temperatura_c = 28.5
        humedad_ambiente_pct = 62.0
        humedad_suelo_pct = 41.3
        humedad_suelo_raw = 2870
        intensidad_luz_lux = 780.5
    }

    if ($lectura.ok -ne $true -or -not $lectura.id) {
        throw "No se recibio id de lectura."
    }
}

Invoke-Check "Estado de actuadores enviado" {
    $estado = Invoke-ApiJson -Method "POST" -Endpoint "/actuadores.php" -ExpectedStatus 201 -Body @{
        ventilador = $script:EstadoVentilador
        bomba = $script:EstadoBomba
        lampara = $script:EstadoLampara
        servo_acceso = $script:EstadoServoAcceso
        modo_control = "automatico"
        origen = "esp32"
    }

    if ($estado.ok -ne $true -or -not $estado.id) {
        throw "No se recibio id de estado de actuadores."
    }
}

Invoke-Check "Acceso RFID registrado" {
    $acceso = Invoke-ApiJson -Method "POST" -Endpoint "/accesos.php" -ExpectedStatus 201 -Body @{
        uid = "A1B2C3D4"
        servo_abierto = 1
    }

    if ($acceso.ok -ne $true -or $acceso.autorizado -ne $true -or -not $acceso.id) {
        throw "El acceso demo no fue autorizado."
    }
}

Invoke-Check "Comando pendiente creado" {
    $comando = Invoke-ApiJson -Method "POST" -Endpoint "/comandos.php" -ExpectedStatus 201 -Body @{
        actuador = "bomba"
        estado_solicitado = 1
        origen = "app"
    }

    if ($comando.ok -ne $true -or -not $comando.id) {
        throw "No se recibio id de comando."
    }
}

Invoke-Check "Comando pendiente consultado" {
    $response = Invoke-ApiJson -Method "GET" -Endpoint "/comandos.php?estado=pendiente&limite=1"

    if ($response.ok -ne $true -or $response.comandos.Count -lt 1) {
        throw "No se encontro comando pendiente."
    }

    $script:ComandoPendiente = $response.comandos[0]

    if ($script:ComandoPendiente.actuador -notin @("ventilador", "bomba", "lampara")) {
        throw "Actuador no permitido para ESP32 simulado: $($script:ComandoPendiente.actuador)"
    }
}

Invoke-Check "Estado actualizado por comando" {
    $actuador = [string]$script:ComandoPendiente.actuador
    $estadoSolicitado = [int]$script:ComandoPendiente.estado_solicitado

    if ($actuador -eq "ventilador") {
        $script:EstadoVentilador = $estadoSolicitado
    } elseif ($actuador -eq "bomba") {
        $script:EstadoBomba = $estadoSolicitado
    } elseif ($actuador -eq "lampara") {
        $script:EstadoLampara = $estadoSolicitado
    } else {
        throw "Actuador no permitido: $actuador"
    }

    $estado = Invoke-ApiJson -Method "POST" -Endpoint "/actuadores.php" -ExpectedStatus 201 -Body @{
        ventilador = $script:EstadoVentilador
        bomba = $script:EstadoBomba
        lampara = $script:EstadoLampara
        servo_acceso = $script:EstadoServoAcceso
        modo_control = "automatico"
        origen = "esp32"
    }

    if ($estado.ok -ne $true -or -not $estado.id) {
        throw "No se guardo el estado actualizado."
    }
}

Invoke-Check "Evento registrado" {
    $evento = Invoke-ApiJson -Method "POST" -Endpoint "/eventos.php" -ExpectedStatus 201 -Body @{
        actuador = $script:ComandoPendiente.actuador
        estado_anterior = 0
        estado_nuevo = [int]$script:ComandoPendiente.estado_solicitado
        motivo = "comando_manual"
        lectura_id = $null
        acceso_rfid_id = $null
    }

    if ($evento.ok -ne $true -or -not $evento.id) {
        throw "No se recibio id de evento."
    }
}

Invoke-Check "Comando marcado como ejecutado" {
    $actualizado = Invoke-ApiJson -Method "PUT" -Endpoint "/comandos.php" -Body @{
        id = [int]$script:ComandoPendiente.id
        estado_comando = "ejecutado"
        respuesta_esp32 = "Comando ejecutado por ESP32 simulado"
    }

    if ($actualizado.ok -ne $true) {
        throw "El comando no fue marcado como ejecutado."
    }
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Simulacion ESP32 finalizada correctamente.") -ForegroundColor Green
