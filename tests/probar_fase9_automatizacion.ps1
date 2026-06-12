$ErrorActionPreference = "Stop"
$BaseUrl = "http://localhost:8080"

Write-Host "Pruebas Fase 9 automatizacion real - Invernadero Inteligente IoT"
Write-Host "================================================"

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

    return ($output | Out-String).Trim()
}

function Assert-FileContains {
    param(
        [string]$Path,
        [string]$Text
    )

    $content = Get-Content -Raw $Path

    if (-not $content.Contains($Text)) {
        throw "El archivo $Path no contiene: $Text"
    }
}

function Assert-FileNotContains {
    param(
        [string]$Path,
        [string]$Text
    )

    $content = Get-Content -Raw $Path

    if ($content.Contains($Text)) {
        throw "El archivo $Path contiene texto no permitido: $Text"
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
        [string]$Path,
        [object]$Body = $null,
        [int]$ExpectedStatus = 200
    )

    $params = @{
        Uri = "$BaseUrl$Path"
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

function Wait-ForApiStatus {
    $maxAttempts = 60
    $lastError = ""

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $json = Invoke-ApiJson -Method "GET" -Path "/api/status.php"

            if ($json.ok -eq $true -and $json.conexion_bd -eq $true) {
                return
            }
        } catch {
            $lastError = $_.Exception.Message
        }

        Start-Sleep -Seconds 2
    }

    throw "La API no estuvo lista despues de $maxAttempts intentos. $lastError"
}

Invoke-Check "Simulador contiene automatizacion real basada en configuracion" {
    $simulador = "tests/simular_esp32.ps1"
    Assert-FileContains -Path $simulador -Text "/configuracion.php"
    Assert-FileContains -Path $simulador -Text "Get-ConfiguracionAutomatizacion"
    Assert-FileContains -Path $simulador -Text "Invoke-Automatizacion"
    Assert-FileContains -Path $simulador -Text "temperatura_max_c"
    Assert-FileContains -Path $simulador -Text "humedad_suelo_min_pct"
    Assert-FileContains -Path $simulador -Text "luz_min_lux"
    Assert-FileContains -Path $simulador -Text "ventilacion_automatica"
    Assert-FileContains -Path $simulador -Text "riego_automatico"
    Assert-FileContains -Path $simulador -Text "iluminacion_automatica"
    Assert-FileContains -Path $simulador -Text "temperatura_alta"
    Assert-FileContains -Path $simulador -Text "suelo_seco"
    Assert-FileContains -Path $simulador -Text "luz_baja"
    Assert-FileContains -Path $simulador -Text "/comandos.php?estado=pendiente&limite=50"
    Assert-FileContains -Path $simulador -Text "Start-Sleep -Seconds 2"
}

Invoke-Check "Firmware contiene estructura equivalente y usa solo API" {
    $firmware = "esp32/firmware_base/firmware_base.ino"
    $funciones = @(
        "conectarWiFi()",
        "obtenerConfiguracion()",
        "leerSensores()",
        "enviarLectura(",
        "aplicarAutomatizacion(",
        "procesarComandosPendientes()",
        "actualizarActuadores()",
        "registrarEvento(",
        "registrarAccesoRFID()"
    )

    foreach ($funcion in $funciones) {
        Assert-FileContains -Path $firmware -Text $funcion
    }

    Assert-FileContains -Path $firmware -Text "/configuracion.php"
    Assert-FileContains -Path $firmware -Text "/lecturas.php"
    Assert-FileContains -Path $firmware -Text "/actuadores.php"
    Assert-FileContains -Path $firmware -Text "/comandos.php?estado=pendiente&limite=50"
    Assert-FileContains -Path $firmware -Text "/eventos.php"
    Assert-FileContains -Path $firmware -Text "/accesos.php"
    Assert-FileNotContains -Path $firmware -Text "MySQL"
    Assert-FileNotContains -Path $firmware -Text "mysql"
}

Invoke-Check "config.example.h usa placeholders y config.h esta ignorado" {
    $configExample = "esp32/firmware_base/config.example.h"
    Assert-FileContains -Path $configExample -Text 'WIFI_SSID "TU_SSID_WIFI"'
    Assert-FileContains -Path $configExample -Text 'WIFI_PASSWORD "TU_CONTRASENA_WIFI"'
    Assert-FileContains -Path $configExample -Text 'API_BASE_URL "http://TU_HOST:8080/api"'
    Assert-FileContains -Path $configExample -Text "PIN_DHT 4"
    Assert-FileContains -Path $configExample -Text "PIN_RELAY_VENTILADOR 25"
    Assert-FileNotContains -Path $configExample -Text "irregular-mothball-flyover"
    Assert-FileNotContains -Path $configExample -Text "invernadero_pass"
    Assert-FileContains -Path ".gitignore" -Text "esp32/firmware_base/config.h"
}

Invoke-Check "Documentacion contiene mapa de pines y advertencias" {
    $doc = "esp32/README_INTEGRACION_ESP32.md"
    Assert-FileContains -Path $doc -Text "Mapa de pines sugerido"
    Assert-FileContains -Path $doc -Text "DHT11"
    Assert-FileContains -Path $doc -Text "GPIO 4"
    Assert-FileContains -Path $doc -Text "YL-69"
    Assert-FileContains -Path $doc -Text "GPIO 34"
    Assert-FileContains -Path $doc -Text "BH1750"
    Assert-FileContains -Path $doc -Text "GPIO 21"
    Assert-FileContains -Path $doc -Text "RC522"
    Assert-FileContains -Path $doc -Text "GPIO 5"
    Assert-FileContains -Path $doc -Text "No conectar bomba, ventilador ni lampara directo a GPIO"
}

Invoke-Check "No se modificaron api/, sql/, Dockerfile ni docker-compose.yml" {
    $diffTracked = git diff --name-only -- api sql Dockerfile docker-compose.yml
    $diffUntracked = git ls-files --others --exclude-standard api sql Dockerfile docker-compose.yml

    if ($diffTracked -or $diffUntracked) {
        throw "Hay cambios fuera del alcance: $diffTracked $diffUntracked"
    }
}

Invoke-Check "Docker disponible" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("--version") | Out-Null
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "version") | Out-Null
}

Invoke-Check "Base reconstruida desde cero" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "down", "-v") | Out-Null
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "up", "-d", "--build") | Out-Null
}

Invoke-Check "MySQL y API listos" {
    Wait-For-MySql
    Wait-ForApiStatus
}

Invoke-Check "Configuracion fuerza encendido automatico de los actuadores" {
    $respuesta = Invoke-ApiJson -Method "PUT" -Path "/api/configuracion.php" -Body @{
        temperatura_max_c = 20
        humedad_suelo_min_pct = 90
        luz_min_lux = 1000
        ventilacion_automatica = 1
        riego_automatico = 1
        iluminacion_automatica = 1
        duracion_riego_seg = 3
        intervalo_lectura_seg = 10
    }

    if ($respuesta.ok -ne $true) {
        throw "No se pudo actualizar configuracion para la prueba."
    }
}

Invoke-Check "Simulador aplica reglas automaticas y registra eventos" {
    Invoke-NativeCommand -FilePath "powershell" -Arguments @("-ExecutionPolicy", "Bypass", "-File", ".\tests\simular_esp32.ps1") | Out-Null

    $estado = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"

    if ($estado.estado.ventilador -ne 1 -or $estado.estado.bomba -ne 1 -or $estado.estado.lampara -ne 1) {
        throw "La automatizacion no dejo ventilador, bomba y lampara encendidos."
    }

    $eventos = Invoke-ApiJson -Method "GET" -Path "/api/eventos.php?limite=20"
    $motivos = @($eventos.eventos | ForEach-Object { $_.motivo })

    foreach ($motivo in @("temperatura_alta", "suelo_seco", "luz_baja")) {
        if ($motivos -notcontains $motivo) {
            throw "No se registro evento automatico con motivo $motivo."
        }
    }
}

Invoke-Check "Comando manual tiene prioridad sobre automatizacion en el ciclo" {
    $comando = Invoke-ApiJson -Method "POST" -Path "/api/comandos.php" -ExpectedStatus 201 -Body @{
        actuador = "bomba"
        estado_solicitado = 0
        origen = "app"
    }

    if ($comando.ok -ne $true -or -not $comando.id) {
        throw "No se pudo crear comando manual para bomba."
    }

    Invoke-NativeCommand -FilePath "powershell" -Arguments @("-ExecutionPolicy", "Bypass", "-File", ".\tests\simular_esp32.ps1") | Out-Null

    $estado = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"

    if ($estado.estado.bomba -ne 0) {
        throw "La bomba no quedo apagada por prioridad del comando manual."
    }

    $comandos = Invoke-ApiJson -Method "GET" -Path "/api/comandos.php?limite=20"
    $manualEjecutado = @($comandos.comandos | Where-Object {
        $_.id -eq $comando.id -and $_.actuador -eq "bomba" -and $_.estado_solicitado -eq 0 -and $_.estado_comando -eq "ejecutado"
    })

    if ($manualEjecutado.Count -ne 1) {
        throw "El comando manual de bomba no quedo marcado como ejecutado."
    }
}

Invoke-Check "No existen comandos para servo_acceso" {
    $comandos = Invoke-ApiJson -Method "GET" -Path "/api/comandos.php?limite=100"
    $comandosServo = @($comandos.comandos | Where-Object { $_.actuador -eq "servo_acceso" })

    if ($comandosServo.Count -gt 0) {
        throw "Se encontraron comandos para servo_acceso."
    }
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Todas las pruebas de Fase 9 finalizaron correctamente.") -ForegroundColor Green
