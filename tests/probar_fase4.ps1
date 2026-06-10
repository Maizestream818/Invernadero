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

Write-Host "Pruebas Fase 4 - Invernadero Inteligente IoT"
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

Invoke-Check "API status disponible" {
    $response = Invoke-WebOk -Url "$BaseUrl/api/status.php"
    $json = $response.Content | ConvertFrom-Json

    if ($json.ok -ne $true -or $json.conexion_bd -ne $true) {
        throw "status.php no reporta ok=true y conexion_bd=true."
    }
}

Invoke-Check "Panel web disponible" {
    $response = Invoke-WebOk -Url "$BaseUrl/web/"

    if ($response.Content -notmatch "Invernadero Inteligente IoT") {
        throw "El panel web no contiene el titulo esperado."
    }
}

Invoke-Check "phpMyAdmin disponible" {
    Invoke-WebOk -Url "http://localhost:8081" | Out-Null
}

Invoke-Check "Archivos de documentacion existen" {
    $archivos = @(
        "README.md",
        "docs/guia_ngrok.md",
        "docs/guia_ejecucion.md",
        "docs/guia_entrega.md",
        "tests/README_PRUEBAS_FASE4.md"
    )

    foreach ($archivo in $archivos) {
        if (-not (Test-Path $archivo)) {
            throw "No existe el archivo requerido: $archivo"
        }
    }
}

Invoke-Check "README.md contiene referencias obligatorias" {
    $readme = Get-Content -Raw "README.md"
    $textos = @(
        "ngrok http 8080",
        "http://localhost:8080/web/",
        "http://localhost:8080/api/status.php",
        "http://localhost:8081",
        "App Android en etapa posterior"
    )

    foreach ($texto in $textos) {
        if (-not $readme.Contains($texto)) {
            throw "README.md no contiene: $texto"
        }
    }
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Todas las pruebas de Fase 4 finalizaron correctamente.") -ForegroundColor Green
