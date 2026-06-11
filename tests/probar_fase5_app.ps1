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

$androidRoot = "android-app"
$manifestPath = "android-app/app/src/main/AndroidManifest.xml"
$mainActivityPath = "android-app/app/src/main/java/com/maizestream/invernadero/MainActivity.java"
$apiClientPath = "android-app/app/src/main/java/com/maizestream/invernadero/ApiClient.java"
$layoutPath = "android-app/app/src/main/res/layout/activity_main.xml"
$readmePath = "tests/README_PRUEBAS_APP_FASE5.md"

Write-Host "Pruebas Fase 5 App Android - Invernadero Inteligente IoT"
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

Invoke-Check "Existe AndroidManifest.xml" {
    if (-not (Test-Path $manifestPath -PathType Leaf)) {
        throw "No existe $manifestPath"
    }
}

Invoke-Check "AndroidManifest.xml tiene permiso INTERNET" {
    Assert-FileContains -Path $manifestPath -Text '<uses-permission android:name="android.permission.INTERNET" />'
}

Invoke-Check "AndroidManifest.xml permite cleartext traffic" {
    Assert-FileContains -Path $manifestPath -Text 'android:usesCleartextTraffic="true"'
}

Invoke-Check "Existe ApiClient.java" {
    if (-not (Test-Path $apiClientPath -PathType Leaf)) {
        throw "No existe $apiClientPath"
    }
}

Invoke-Check "La app usa HttpURLConnection, org.json y SharedPreferences" {
    Assert-FileContains -Path $apiClientPath -Text "HttpURLConnection"
    Assert-FileContains -Path $apiClientPath -Text "org.json"
    Assert-FileContains -Path $mainActivityPath -Text "SharedPreferences"
}

Invoke-Check "Archivos Java referencian endpoints requeridos" {
    $javaContent = Get-ChildItem "android-app/app/src/main/java/com/maizestream/invernadero" -Filter *.java |
        ForEach-Object { Get-Content -Raw $_.FullName } |
        Out-String

    $endpoints = @(
        "status.php",
        "lecturas.php",
        "actuadores.php",
        "configuracion.php",
        "accesos.php",
        "comandos.php"
    )

    foreach ($endpoint in $endpoints) {
        if (-not $javaContent.Contains($endpoint)) {
            throw "No se encontro referencia a $endpoint en archivos Java."
        }
    }
}

Invoke-Check "activity_main.xml usa ScrollView y controles basicos" {
    Assert-FileContains -Path $layoutPath -Text "<ScrollView"
    Assert-FileContains -Path $layoutPath -Text "<LinearLayout"
    Assert-FileContains -Path $layoutPath -Text "<EditText"
    Assert-FileContains -Path $layoutPath -Text "<Button"
    Assert-FileContains -Path $layoutPath -Text "<TextView"
}

Invoke-Check "No hay Retrofit, Volley ni Jetpack Compose en la app" {
    $contenido = Get-ChildItem "android-app/app/src/main" -Recurse -File |
        Where-Object { $_.Extension -in ".java", ".xml", ".kt", ".kts" } |
        ForEach-Object { Get-Content -Raw $_.FullName } |
        Out-String

    $prohibidos = @("Retrofit", "Volley", "Composable", "setContent {")

    foreach ($texto in $prohibidos) {
        if ($contenido.Contains($texto)) {
            throw "Se encontro texto no permitido: $texto"
        }
    }
}

Invoke-Check "Existe README de pruebas Fase 5" {
    if (-not (Test-Path $readmePath -PathType Leaf)) {
        throw "No existe $readmePath"
    }
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Todas las validaciones de Fase 5 finalizaron correctamente.") -ForegroundColor Green
