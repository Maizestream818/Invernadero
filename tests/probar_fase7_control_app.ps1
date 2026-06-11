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

    return $content | ConvertFrom-Json
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

$androidRoot = "android-app"
$mainActivityPath = "android-app/app/src/main/java/com/maizestream/invernadero/MainActivity.java"
$apiClientPath = "android-app/app/src/main/java/com/maizestream/invernadero/ApiClient.java"
$layoutPath = "android-app/app/src/main/res/layout/activity_main.xml"
$readmePath = "tests/README_PRUEBAS_FASE7.md"

Write-Host "Pruebas Fase 7 Control remoto app Android - Invernadero Inteligente IoT"
Write-Host "================================================"

Invoke-Check "Existe android-app/" {
    if (-not (Test-Path $androidRoot -PathType Container)) {
        throw "No existe android-app/"
    }
}

Invoke-Check "Existe MainActivity.java" {
    if (-not (Test-Path $mainActivityPath -PathType Leaf)) {
        throw "No existe $mainActivityPath"
    }
}

Invoke-Check "Existe ApiClient.java" {
    if (-not (Test-Path $apiClientPath -PathType Leaf)) {
        throw "No existe $apiClientPath"
    }
}

Invoke-Check "ApiClient.java soporta POST JSON" {
    Assert-FileContains -Path $apiClientPath -Text "postJson"
    Assert-FileContains -Path $apiClientPath -Text 'setRequestMethod("POST")'
    Assert-FileContains -Path $apiClientPath -Text "Content-Type"
    Assert-FileContains -Path $apiClientPath -Text "application/json"
    Assert-FileContains -Path $apiClientPath -Text "HttpURLConnection"
}

Invoke-Check "MainActivity.java referencia actuadores permitidos y comandos.php" {
    Assert-FileContains -Path $mainActivityPath -Text "ventilador"
    Assert-FileContains -Path $mainActivityPath -Text "bomba"
    Assert-FileContains -Path $mainActivityPath -Text "lampara"
    Assert-FileContains -Path $mainActivityPath -Text "comandos.php"
}

Invoke-Check "MainActivity.java no crea comandos para servo_acceso" {
    $content = Get-Content -Raw $mainActivityPath

    if ($content.Contains('crearComando("servo_acceso"') -or $content.Contains('body.put("actuador", "servo_acceso")')) {
        throw "MainActivity intenta crear comandos para servo_acceso."
    }
}

Invoke-Check "activity_main.xml contiene seccion Control remoto y botones" {
    Assert-FileContains -Path $layoutPath -Text "Control remoto"
    Assert-FileContains -Path $layoutPath -Text "Encender ventilador"
    Assert-FileContains -Path $layoutPath -Text "Apagar ventilador"
    Assert-FileContains -Path $layoutPath -Text "Encender bomba"
    Assert-FileContains -Path $layoutPath -Text "Apagar bomba"
    Assert-FileContains -Path $layoutPath -Text "Encender lampara"
    Assert-FileContains -Path $layoutPath -Text "Apagar lampara"
}

Invoke-Check "No se modificaron api/, sql/, Dockerfile ni docker-compose.yml" {
    $diffTracked = git diff --name-only -- api sql Dockerfile docker-compose.yml
    $diffUntracked = git ls-files --others --exclude-standard api sql Dockerfile docker-compose.yml

    if ($diffTracked -or $diffUntracked) {
        throw "Hay cambios fuera del alcance: $diffTracked $diffUntracked"
    }
}

Invoke-Check "Existe README de pruebas Fase 7" {
    if (-not (Test-Path $readmePath -PathType Leaf)) {
        throw "No existe $readmePath"
    }
}

Invoke-Check "Docker disponible" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("--version")
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "version")
}

Invoke-Check "Servicios levantados con Docker Compose" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "up", "-d", "--build")
}

Invoke-Check "Backend status responde" {
    Wait-ForApiStatus
}

Invoke-Check "API permite crear comando pendiente para bomba" {
    $json = Invoke-ApiJson -Method "POST" -Path "/api/comandos.php" -ExpectedStatus 201 -Body @{
        actuador = "bomba"
        estado_solicitado = 1
        origen = "app"
    }

    if ($json.ok -ne $true -or -not $json.id) {
        throw "La API no devolvio ok=true e id para el comando."
    }
}

Invoke-Check "API rechaza comando para servo_acceso" {
    $json = Invoke-ApiJson -Method "POST" -Path "/api/comandos.php" -ExpectedStatus 400 -Body @{
        actuador = "servo_acceso"
        estado_solicitado = 1
        origen = "app"
    }

    if ($json.ok -ne $false) {
        throw "La API no rechazo servo_acceso con ok=false."
    }
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Todas las pruebas de Fase 7 finalizaron correctamente.") -ForegroundColor Green
