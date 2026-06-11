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

function Invoke-WebOk {
    param(
        [string]$Url,
        [int]$ExpectedStatus = 200
    )

    $response = Invoke-WebRequest -Uri $Url -Method GET -UseBasicParsing

    if ([int]$response.StatusCode -ne $ExpectedStatus) {
        throw "HTTP esperado $ExpectedStatus, recibido $($response.StatusCode)."
    }

    return $response
}

function Wait-ForApiStatus {
    $maxAttempts = 60
    $lastError = ""

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri "$BaseUrl/api/status.php" -Method GET -UseBasicParsing
            $json = $response.Content | ConvertFrom-Json

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

Write-Host "Pruebas Fase 6 Diseno - Invernadero Inteligente IoT"
Write-Host "================================================"

Invoke-Check "Docker disponible" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("--version")
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "version")
}

Invoke-Check "Servicios levantados con Docker Compose" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "up", "-d", "--build")
}

Invoke-Check "API lista" {
    Wait-ForApiStatus
}

Invoke-Check "Existe web/index.html" {
    if (-not (Test-Path "web/index.html" -PathType Leaf)) {
        throw "No existe web/index.html"
    }
}

Invoke-Check "Existe web/estilos.css con paleta Fase 6" {
    if (-not (Test-Path "web/estilos.css" -PathType Leaf)) {
        throw "No existe web/estilos.css"
    }

    Assert-FileContains -Path "web/estilos.css" -Text "#0F5132"
    Assert-FileContains -Path "web/estilos.css" -Text "#198754"
    Assert-FileContains -Path "web/estilos.css" -Text "#EAF4EF"
    Assert-FileContains -Path "web/estilos.css" -Text "border-radius"
}

Invoke-Check "Existe colors.xml con paleta equivalente" {
    $colorsPath = "android-app/app/src/main/res/values/colors.xml"

    if (-not (Test-Path $colorsPath -PathType Leaf)) {
        throw "No existe $colorsPath"
    }

    Assert-FileContains -Path $colorsPath -Text "0F5132"
    Assert-FileContains -Path $colorsPath -Text "198754"
    Assert-FileContains -Path $colorsPath -Text "EAF4EF"
}

Invoke-Check "MainActivity.java contiene URL ngrok por defecto" {
    $path = "android-app/app/src/main/java/com/maizestream/invernadero/MainActivity.java"
    Assert-FileContains -Path $path -Text "DEFAULT_API_BASE_URL"
    Assert-FileContains -Path $path -Text "https://irregular-mothball-flyover.ngrok-free.dev/api"
}

Invoke-Check "activity_main.xml sigue existiendo" {
    if (-not (Test-Path "android-app/app/src/main/res/layout/activity_main.xml" -PathType Leaf)) {
        throw "No existe activity_main.xml"
    }
}

Invoke-Check "No se crearon archivos de control remoto web fuera de alcance" {
    $rutasProhibidas = @(
        "web/control.html",
        "web/control.js",
        "android-app/app/src/main/java/com/maizestream/invernadero/ControlActivity.java"
    )

    foreach ($ruta in $rutasProhibidas) {
        if (Test-Path $ruta) {
            throw "Existe archivo fuera de alcance: $ruta"
        }
    }
}

Invoke-Check "No se modificaron api/ ni sql/" {
    $diffTracked = git diff --name-only -- api sql
    $diffUntracked = git ls-files --others --exclude-standard api sql

    if ($diffTracked -or $diffUntracked) {
        throw "Hay cambios en api/ o sql/: $diffTracked $diffUntracked"
    }
}

Invoke-Check "Backend status responde" {
    $response = Invoke-WebOk -Url "$BaseUrl/api/status.php"
    $json = $response.Content | ConvertFrom-Json

    if ($json.ok -ne $true -or $json.conexion_bd -ne $true) {
        throw "status.php no reporta ok=true y conexion_bd=true."
    }
}

Invoke-Check "Panel web responde" {
    $response = Invoke-WebOk -Url "$BaseUrl/web/"

    if ($response.Content -notmatch "Invernadero Inteligente IoT") {
        throw "El panel web no contiene el titulo esperado."
    }
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Todas las pruebas de Fase 6 finalizaron correctamente.") -ForegroundColor Green
