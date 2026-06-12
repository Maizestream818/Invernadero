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

function Assert-FileMatches {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Detail
    )

    $content = Get-Content -Raw $Path

    if (-not [regex]::IsMatch($content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
        throw $Detail
    }
}

function Assert-AnyLayoutContains {
    param(
        [string]$Text
    )

    $matches = @(Get-ChildItem -Path "android-app/app/src/main/res/layout" -Filter "*.xml" | Where-Object {
        (Get-Content -Raw $_.FullName).Contains($Text)
    })

    if ($matches.Count -eq 0) {
        throw "Ningun layout Android contiene: $Text"
    }
}

function Assert-NoLayoutContains {
    param(
        [string]$Text
    )

    $matches = @(Get-ChildItem -Path "android-app/app/src/main/res/layout" -Filter "*.xml" | Where-Object {
        (Get-Content -Raw $_.FullName).Contains($Text)
    })

    if ($matches.Count -gt 0) {
        throw "Hay layouts Android que contienen texto no permitido: $Text"
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

$mainActivityPath = "android-app/app/src/main/java/com/maizestream/invernadero/MainActivity.java"
$layoutPath = "android-app/app/src/main/res/layout/activity_main.xml"
$webIndexPath = "web/index.html"
$webCssPath = "web/estilos.css"
$webJsPath = "web/app.js"

Write-Host "Pruebas Fase 8.1 UX app/web - Invernadero Inteligente IoT"
Write-Host "================================================"

Invoke-Check "Existe MainActivity.java" {
    if (-not (Test-Path $mainActivityPath -PathType Leaf)) {
        throw "No existe $mainActivityPath"
    }
}

Invoke-Check "Existe activity_main.xml" {
    if (-not (Test-Path $layoutPath -PathType Leaf)) {
        throw "No existe $layoutPath"
    }
}

Invoke-Check "App, web y simulador actualizan cada 2 segundos" {
    Assert-FileContains -Path $mainActivityPath -Text "AUTO_REFRESH_INTERVAL_MS"
    Assert-FileContains -Path $mainActivityPath -Text "2000L"
    Assert-FileContains -Path $mainActivityPath -Text "Handler"
    Assert-FileContains -Path $mainActivityPath -Text "Runnable"
    Assert-FileContains -Path $mainActivityPath -Text "onResume"
    Assert-FileContains -Path $mainActivityPath -Text "onPause"
    Assert-FileContains -Path $mainActivityPath -Text "isRefreshing"
    Assert-FileContains -Path $webJsPath -Text "INTERVALO_ACTUALIZACION_MS = 2000"
    Assert-FileContains -Path "tests/simular_esp32.ps1" -Text "Start-Sleep -Seconds 2"
    Assert-FileContains -Path "tests/simular_esp32.ps1" -Text "Send-LecturaSensoresSimulada"
}

Invoke-Check "MainActivity.java contiene logica dinamica para bomba, ventilador y lampara" {
    Assert-FileContains -Path $mainActivityPath -Text "estadoActualBomba"
    Assert-FileContains -Path $mainActivityPath -Text "estadoActualVentilador"
    Assert-FileContains -Path $mainActivityPath -Text "estadoActualLampara"
    Assert-FileContains -Path $mainActivityPath -Text "hayComandoPendienteBomba"
    Assert-FileContains -Path $mainActivityPath -Text "hayComandoPendienteVentilador"
    Assert-FileContains -Path $mainActivityPath -Text "hayComandoPendienteLampara"
    Assert-FileContains -Path $mainActivityPath -Text "crearComandoSegunEstado"
    Assert-FileContains -Path $mainActivityPath -Text "actualizarControlesRemotos"
    Assert-FileContains -Path $mainActivityPath -Text "actualizarControlActuador"
    Assert-FileContains -Path $mainActivityPath -Text "hayComandoPendienteParaActuador"
}

Invoke-Check "MainActivity.java contiene guardado automatico de URL" {
    Assert-FileContains -Path $mainActivityPath -Text "guardarUrlSiEsNecesario"
    Assert-FileContains -Path $mainActivityPath -Text "setOnFocusChangeListener"
    Assert-FileContains -Path $mainActivityPath -Text "SharedPreferences"
}

Invoke-Check "activity_main.xml ya no contiene boton Guardar URL" {
    Assert-FileNotContains -Path $layoutPath -Text "btnGuardarUrl"
    Assert-FileNotContains -Path $layoutPath -Text "Guardar URL"
}

Invoke-Check "No existe boton manual Actualizar datos" {
    Assert-FileNotContains -Path $layoutPath -Text "btnActualizarDatos"
    Assert-FileNotContains -Path $layoutPath -Text "Actualizar datos"
    Assert-FileNotContains -Path $webIndexPath -Text "btn-actualizar"
    Assert-FileNotContains -Path $webIndexPath -Text "Actualizar datos"
    Assert-FileNotContains -Path $webJsPath -Text "btn-actualizar"
}

Invoke-Check "Actuadores usan cards tocables sin botones separados" {
    Assert-NoLayoutContains -Text "btnToggleBomba"
    Assert-NoLayoutContains -Text "btnToggleVentilador"
    Assert-NoLayoutContains -Text "btnToggleLampara"
    Assert-AnyLayoutContains -Text "cardActBomba"
    Assert-AnyLayoutContains -Text "cardActVentilador"
    Assert-AnyLayoutContains -Text "cardActLampara"
    Assert-AnyLayoutContains -Text "cardActServo"
    Assert-AnyLayoutContains -Text "txtEstadoBombaControl"
    Assert-AnyLayoutContains -Text "txtEstadoVentiladorControl"
    Assert-AnyLayoutContains -Text "txtEstadoLamparaControl"
    Assert-AnyLayoutContains -Text "Bomba de agua"
    Assert-AnyLayoutContains -Text "Ventilador"
    Assert-AnyLayoutContains -Text "Lampara"
    Assert-FileContains -Path $layoutPath -Text "gridActuadoresAndroid"
    Assert-FileContains -Path $mainActivityPath -Text "cardActBomba.setOnClickListener"
    Assert-FileContains -Path $mainActivityPath -Text "Esperando ejecucion"
    Assert-FileContains -Path $webIndexPath -Text "control-actuador"
    Assert-FileContains -Path $webJsPath -Text "crearComandoDesdeCard"
    Assert-FileNotContains -Path $webIndexPath -Text "btn-act-bomba"
    Assert-FileNotContains -Path $webIndexPath -Text "boton-actuador"
    Assert-FileNotContains -Path $webJsPath -Text "btn-act-"
}

Invoke-Check "activity_main.xml no contiene botones dobles antiguos" {
    $idsProhibidos = @(
        "btnEncenderBomba",
        "btnApagarBomba",
        "btnEncenderVentilador",
        "btnApagarVentilador",
        "btnEncenderLampara",
        "btnApagarLampara",
        "btnBombaEncender",
        "btnBombaApagar",
        "btnVentiladorEncender",
        "btnVentiladorApagar",
        "btnLamparaEncender",
        "btnLamparaApagar"
    )

    foreach ($id in $idsProhibidos) {
        Assert-FileNotContains -Path $layoutPath -Text $id
    }
}

Invoke-Check "Sensores usan cards reales en dos columnas sin fecha" {
    Assert-FileContains -Path $layoutPath -Text "txtTarjetasSensores"
    Assert-AnyLayoutContains -Text "txtSensorTemperatura"
    Assert-AnyLayoutContains -Text "txtSensorHumedadAmbiente"
    Assert-AnyLayoutContains -Text "txtSensorHumedadSuelo"
    Assert-AnyLayoutContains -Text "txtSensorHumedadRaw"
    Assert-AnyLayoutContains -Text "txtSensorLuz"
    Assert-AnyLayoutContains -Text "&#127777;"
    Assert-AnyLayoutContains -Text "&#128167;"
    Assert-AnyLayoutContains -Text "&#127793;"
    Assert-AnyLayoutContains -Text "&#9728;"
    Assert-FileNotContains -Path $layoutPath -Text "Fecha de lectura"
    Assert-NoLayoutContains -Text "Fecha de lectura"
    Assert-FileNotContains -Path $layoutPath -Text "txtSensorFecha"
    Assert-FileContains -Path $webIndexPath -Text "grid-sensores"
    Assert-FileContains -Path $webCssPath -Text "--tile-size: 150px"
    Assert-FileContains -Path $webCssPath -Text "repeat(auto-fit, minmax(var(--tile-size), var(--tile-size)))"
    Assert-FileContains -Path $webCssPath -Text ".sensor-card {"
    Assert-FileContains -Path $webCssPath -Text ".sensor-card .icono-tarjeta"
    Assert-FileContains -Path $webCssPath -Text "aspect-ratio: 1 / 1"
    Assert-FileNotContains -Path $webCssPath -Text "min-height: 104px"
    Assert-FileNotContains -Path $webIndexPath -Text "Fecha de lectura"
    Assert-FileNotContains -Path $webJsPath -Text "lectura-fecha"
    Assert-FileContains -Path $webIndexPath -Text "icono-tarjeta"
}

Invoke-Check "Actuadores son cards en dos columnas sin modo, origen ni fecha" {
    Assert-FileContains -Path $layoutPath -Text "txtTarjetasActuadores"
    Assert-AnyLayoutContains -Text "txtActVentilador"
    Assert-AnyLayoutContains -Text "txtActBomba"
    Assert-AnyLayoutContains -Text "txtActLampara"
    Assert-AnyLayoutContains -Text "txtActServo"
    Assert-NoLayoutContains -Text "txtActModo"
    Assert-NoLayoutContains -Text "txtActOrigen"
    Assert-NoLayoutContains -Text "txtActFecha"
    Assert-FileNotContains -Path $webIndexPath -Text "act-modo"
    Assert-FileNotContains -Path $webIndexPath -Text "act-origen"
    Assert-FileNotContains -Path $webIndexPath -Text "act-fecha"
    Assert-FileContains -Path $webIndexPath -Text "grid-actuadores"
    Assert-FileContains -Path $webCssPath -Text ".grid-actuadores"
    Assert-FileContains -Path $webCssPath -Text ".actuator-card {"
    Assert-FileContains -Path $webCssPath -Text "width: var(--tile-size)"
    Assert-FileContains -Path $webCssPath -Text "aspect-ratio: 1 / 1"
    Assert-FileContains -Path $webCssPath -Text "actuador-on"
    Assert-FileContains -Path $webCssPath -Text "actuador-off"
    Assert-FileContains -Path $webCssPath -Text "actuador-pendiente"
}

Invoke-Check "MainActivity.java sigue usando endpoints requeridos" {
    Assert-FileContains -Path $mainActivityPath -Text "/actuadores.php"
    Assert-FileContains -Path $mainActivityPath -Text "/comandos.php"
}

Invoke-Check "MainActivity.java contiene estado API estable sin banner de actualizacion" {
    Assert-FileContains -Path $mainActivityPath -Text "API conectada"
    Assert-FileContains -Path $mainActivityPath -Text "API desconectada"
    Assert-FileNotContains -Path $mainActivityPath -Text "Actualizando datos..."
    Assert-FileNotContains -Path $mainActivityPath -Text "Actualizando..."
    Assert-FileNotContains -Path $layoutPath -Text "Actualizando datos..."
    Assert-FileNotContains -Path $layoutPath -Text "Actualizando..."
}

Invoke-Check "No existe Control remoto y existe Comandos pendientes" {
    Assert-FileNotContains -Path $layoutPath -Text "Control remoto"
    Assert-FileNotContains -Path $webIndexPath -Text "Control remoto"
    Assert-FileContains -Path $layoutPath -Text "Comandos pendientes"
    Assert-FileContains -Path $layoutPath -Text "tvComandosPendientes"
    Assert-FileContains -Path $webIndexPath -Text "Comandos pendientes"
    Assert-FileContains -Path $webIndexPath -Text "comandos-pendientes"
    Assert-FileContains -Path $layoutPath -Text "Sin comandos pendientes"
    Assert-FileContains -Path $mainActivityPath -Text "Sin comandos pendientes"
    Assert-FileContains -Path $mainActivityPath -Text "Comandos pendientes detectados"
    Assert-FileContains -Path $mainActivityPath -Text "Esperando ejecucion de comandos"
    Assert-FileNotContains -Path $layoutPath -Text "Sin comandos enviados desde la app"
    Assert-FileNotContains -Path $mainActivityPath -Text "Sin comandos enviados desde la app"
}

Invoke-Check "Configuracion se muestra como cards editables" {
    Assert-AnyLayoutContains -Text "cardConfigTempMax"
    Assert-NoLayoutContains -Text "cardConfigIntervalo"
    Assert-NoLayoutContains -Text "Intervalo de lectura"
    Assert-FileContains -Path $mainActivityPath -Text "configurarEdicionConfiguracion"
    Assert-FileContains -Path $mainActivityPath -Text 'putJson("/configuracion.php"'
    Assert-FileContains -Path $mainActivityPath -Text "mostrarSelectorBooleanoConfiguracion"
    Assert-FileContains -Path $mainActivityPath -Text "setSingleChoiceItems"
    Assert-FileContains -Path $mainActivityPath -Text '"Activa", "Inactiva"'
    Assert-FileContains -Path $mainActivityPath -Text "esConfiguracionBooleana"
    Assert-FileContains -Path $mainActivityPath -Text "InputType.TYPE_CLASS_NUMBER"
    Assert-FileContains -Path $webIndexPath -Text "editable-card"
    Assert-FileContains -Path $webIndexPath -Text 'data-campo="temperatura_max_c"'
    Assert-FileContains -Path $webIndexPath -Text 'data-campo="ventilacion_automatica"'
    Assert-FileContains -Path $webIndexPath -Text 'data-campo="riego_automatico"'
    Assert-FileContains -Path $webIndexPath -Text 'data-campo="iluminacion_automatica"'
    Assert-FileNotContains -Path $webIndexPath -Text "Intervalo de lectura"
    Assert-FileNotContains -Path $webIndexPath -Text "cfg-intervalo"
    Assert-FileNotContains -Path $webJsPath -Text "cfg-intervalo"
    Assert-FileContains -Path $webJsPath -Text 'enviarJson("/configuracion.php", "PUT"'
    Assert-FileContains -Path $webJsPath -Text "seleccionarValorBooleanoConfiguracion"
    Assert-FileContains -Path $webJsPath -Text "esConfiguracionBooleana"
    Assert-FileContains -Path $webJsPath -Text 'label: "Activa", value: "1"'
    Assert-FileContains -Path $webJsPath -Text 'label: "Inactiva", value: "0"'
    Assert-FileContains -Path $webJsPath -Text 'document.createElement("select")'
    Assert-FileNotContains -Path $webJsPath -Text '"Activo", "Inactivo"'
}

Invoke-Check "Cards de actuadores tienen estados visuales suficientes" {
    Assert-FileContains -Path "android-app/app/src/main/res/drawable/bg_actuator_on.xml" -Text "@color/color_primary"
    Assert-FileContains -Path "android-app/app/src/main/res/drawable/bg_actuator_off.xml" -Text "@color/color_success_soft"
    Assert-FileContains -Path "android-app/app/src/main/res/drawable/bg_actuator_pending.xml" -Text "@color/color_warning_soft"
    Assert-FileContains -Path "android-app/app/src/main/res/values/colors.xml" -Text "#1F2933"
}

Invoke-Check "MainActivity.java no crea comandos para servo_acceso" {
    $content = Get-Content -Raw $mainActivityPath

    if ($content.Contains('crearComando("servo_acceso"') -or $content.Contains('body.put("actuador", "servo_acceso")')) {
        throw "MainActivity intenta crear comandos para servo_acceso."
    }
}

Invoke-Check "Web contiene tarjetas visuales para sensores y actuadores" {
    Assert-FileContains -Path $webIndexPath -Text "sensor-card"
    Assert-FileContains -Path $webIndexPath -Text "actuator-card"
    Assert-FileContains -Path $webIndexPath -Text "icono-tarjeta"
    Assert-FileContains -Path $webCssPath -Text ".visual-card"
    Assert-FileContains -Path $webCssPath -Text ".icono-tarjeta"
    Assert-FileContains -Path $webJsPath -Text "lectura-temperatura"
    Assert-FileContains -Path $webJsPath -Text "act-bomba"
}

Invoke-Check "simular_esp32.ps1 procesa todos los pendientes" {
    $simulador = "tests/simular_esp32.ps1"
    Assert-FileContains -Path $simulador -Text "param("
    Assert-FileMatches -Path $simulador -Pattern "\[switch\]\s*\`$CrearComandoPrueba" -Detail "simular_esp32.ps1 no define el parametro switch -CrearComandoPrueba."
    Assert-FileMatches -Path $simulador -Pattern "\[switch\]\s*\`$ModoContinuo" -Detail "simular_esp32.ps1 no define el parametro switch -ModoContinuo."
    Assert-FileContains -Path $simulador -Text "/comandos.php?estado=pendiente&limite=50"
    Assert-FileMatches -Path $simulador -Pattern "foreach\s*\(\s*\`$[A-Za-z_][A-Za-z0-9_]*\s+in\s+@\s*\(\s*\`$[A-Za-z_][A-Za-z0-9_]*\s*\)\s*\)" -Detail "simular_esp32.ps1 no recorre una coleccion de comandos pendientes con foreach."
    Assert-FileMatches -Path $simulador -Pattern "if\s*\(\s*\`$CrearComandoPrueba\s*\).*?Invoke-ApiJson\s+-Method\s+[`"']POST[`"']\s+-Endpoint\s+[`"']/comandos\.php[`"']" -Detail "simular_esp32.ps1 no limita la creacion de comandos nuevos al uso de -CrearComandoPrueba."
    Assert-FileContains -Path $simulador -Text "No se crea comando nuevo porque no se uso -CrearComandoPrueba"
    Assert-FileContains -Path $simulador -Text "No quedan comandos pendientes procesables"
}

Invoke-Check "No se modificaron Dockerfile ni docker-compose.yml" {
    $diffTracked = git diff --name-only -- Dockerfile docker-compose.yml
    $diffUntracked = git ls-files --others --exclude-standard Dockerfile docker-compose.yml

    if ($diffTracked -or $diffUntracked) {
        throw "Hay cambios fuera del alcance: $diffTracked $diffUntracked"
    }
}

Invoke-Check "Docker disponible" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("--version")
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "version")
}

Invoke-Check "Servicios levantados con Docker Compose" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "up", "-d", "--build")
}

Invoke-Check "API status responde" {
    Wait-ForApiStatus
}

Invoke-Check "Actuadores restablecidos para pruebas de comandos" {
    $json = Invoke-ApiJson -Method "POST" -Path "/api/actuadores.php" -ExpectedStatus 201 -Body @{
        ventilador = 0
        bomba = 0
        lampara = 0
        servo_acceso = 0
        control_ventilador = "libre"
        control_bomba = "libre"
        control_lampara = "libre"
        modo_control = "automatico"
        origen = "sistema"
    }

    if ($json.ok -ne $true) {
        throw "No se pudo restablecer actuadores."
    }
}

Invoke-Check "API permite crear comandos de bomba" {
    $json = Invoke-ApiJson -Method "POST" -Path "/api/comandos.php" -ExpectedStatus 201 -Body @{
        actuador = "bomba"
        estado_solicitado = 1
        origen = "app"
    }

    if ($json.ok -ne $true -or -not $json.id) {
        throw "La API no devolvio ok=true e id para comando de bomba."
    }
}

Invoke-Check "API permite crear comandos de ventilador" {
    $json = Invoke-ApiJson -Method "POST" -Path "/api/comandos.php" -ExpectedStatus 201 -Body @{
        actuador = "ventilador"
        estado_solicitado = 1
        origen = "app"
    }

    if ($json.ok -ne $true -or -not $json.id) {
        throw "La API no devolvio ok=true e id para comando de ventilador."
    }
}

Invoke-Check "API permite crear comandos de lampara" {
    $json = Invoke-ApiJson -Method "POST" -Path "/api/comandos.php" -ExpectedStatus 201 -Body @{
        actuador = "lampara"
        estado_solicitado = 1
        origen = "app"
    }

    if ($json.ok -ne $true -or -not $json.id) {
        throw "La API no devolvio ok=true e id para comando de lampara."
    }
}

Invoke-Check "API rechaza comandos de servo_acceso" {
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
Write-Host ("PAS" + [char]0x00D3 + " - Todas las pruebas de Fase 8.1 finalizaron correctamente.") -ForegroundColor Green
