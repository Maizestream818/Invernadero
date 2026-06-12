$ErrorActionPreference = "Stop"
$BaseUrl = "http://localhost:8080"

Write-Host "Pruebas Fase 11 turnos y cola de automatizacion - Invernadero Inteligente IoT"
Write-Host "================================================"

function Write-Result {
    param([string]$Name, [bool]$Passed, [string]$Detail = "")

    $status = if ($Passed) { "PAS$([char]0x00D3)" } else { "FALL$([char]0x00D3)" }
    $message = "[$status] $Name"

    if ($Detail -ne "") {
        $message = "$message - $Detail"
    }

    Write-Host $message -ForegroundColor $(if ($Passed) { "Green" } else { "Red" })
}

function Invoke-Check {
    param([string]$Name, [scriptblock]$Action)

    try {
        & $Action
        Write-Result -Name $Name -Passed $true
    } catch {
        Write-Result -Name $Name -Passed $false -Detail $_.Exception.Message
        throw
    }
}

function Invoke-NativeCommand {
    param([string]$FilePath, [string[]]$Arguments)

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw "El comando fallo con codigo ${exitCode}: $FilePath $($Arguments -join ' '). $(($output | Out-String).Trim())"
    }

    return ($output | Out-String).Trim()
}

function Get-ErrorResponseContent {
    param([object]$ErrorRecord)

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
        Headers = @{ Accept = "application/json" }
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

function Assert-FileContains {
    param([string]$Path, [string]$Text)

    $content = Get-Content -Raw $Path

    if (-not $content.Contains($Text)) {
        throw "El archivo $Path no contiene: $Text"
    }
}

function Set-ConfiguracionAutomatica {
    param([int]$TempMax, [int]$HumedadMin, [int]$LuzMin)

    $respuesta = Invoke-ApiJson -Method "PUT" -Path "/api/configuracion.php" -Body @{
        temperatura_max_c = $TempMax
        humedad_suelo_min_pct = $HumedadMin
        luz_min_lux = $LuzMin
        ventilacion_automatica = 1
        riego_automatico = 1
        iluminacion_automatica = 1
        duracion_riego_seg = 3
        intervalo_lectura_seg = 10
    }

    if ($respuesta.ok -ne $true) {
        throw "No se pudo actualizar configuracion."
    }
}

function Crear-ComandoUsuario {
    param([string]$Actuador, [int]$Estado, [int]$ExpectedStatus = 201)

    return Invoke-ApiJson -Method "POST" -Path "/api/comandos.php" -ExpectedStatus $ExpectedStatus -Body @{
        actuador = $Actuador
        estado_solicitado = $Estado
        origen = "app"
    }
}

function Ejecutar-Simulador {
    Invoke-NativeCommand -FilePath "powershell" -Arguments @("-ExecutionPolicy", "Bypass", "-File", ".\tests\simular_esp32.ps1") | Out-Null
}

Invoke-Check "Docker disponible" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("--version") | Out-Null
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "version") | Out-Null
}

Invoke-Check "Base reconstruida desde cero" {
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "down", "-v") | Out-Null
    Invoke-NativeCommand -FilePath "docker" -Arguments @("compose", "up", "-d", "--build") | Out-Null
    Wait-ForApiStatus
}

Invoke-Check "Esquema contiene controles y cola" {
    Assert-FileContains -Path "sql/init.sql" -Text "control_ventilador"
    Assert-FileContains -Path "sql/init.sql" -Text "control_bomba"
    Assert-FileContains -Path "sql/init.sql" -Text "control_lampara"
    Assert-FileContains -Path "sql/init.sql" -Text "cola_automatizacion"
}

Invoke-Check "Usuario toma control de bomba libre" {
    Crear-ComandoUsuario -Actuador "bomba" -Estado 1 | Out-Null
    Ejecutar-Simulador
    $estado = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"

    if ($estado.estado.bomba -ne 1 -or $estado.estado.control_bomba -ne "usuario") {
        throw "La bomba no quedo encendida con control usuario."
    }
}

Invoke-Check "Automatizacion no cambia bomba del usuario y guarda cola" {
    Set-ConfiguracionAutomatica -TempMax 99 -HumedadMin 90 -LuzMin 0
    Ejecutar-Simulador
    $estado = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"
    $colaBomba = @($estado.cola_automatizacion | Where-Object { $_.actuador -eq "bomba" -and $_.estado_tarea -eq "pendiente" })

    if ($estado.estado.bomba -ne 1 -or $estado.estado.control_bomba -ne "usuario") {
        throw "La automatizacion interrumpio la bomba del usuario."
    }

    if ($colaBomba.Count -ne 1) {
        throw "No se guardo una tarea pendiente para bomba."
    }
}

Invoke-Check "Usuario libera bomba y se ejecuta cola si aplica" {
    Crear-ComandoUsuario -Actuador "bomba" -Estado 0 | Out-Null
    Ejecutar-Simulador
    $estado = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"

    if ($estado.estado.bomba -ne 1 -or $estado.estado.control_bomba -ne "automatizacion") {
        throw "La cola pendiente de bomba no se ejecuto al liberar."
    }
}

Invoke-Check "Cola se cancela si condicion ya no aplica" {
    $estado = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"

    if ($estado.estado.control_bomba -eq "automatizacion") {
        Set-ConfiguracionAutomatica -TempMax 99 -HumedadMin 0 -LuzMin 0
        Ejecutar-Simulador
    }

    Crear-ComandoUsuario -Actuador "bomba" -Estado 1 | Out-Null
    Ejecutar-Simulador
    Set-ConfiguracionAutomatica -TempMax 99 -HumedadMin 90 -LuzMin 0
    Ejecutar-Simulador
    Set-ConfiguracionAutomatica -TempMax 99 -HumedadMin 0 -LuzMin 0
    Crear-ComandoUsuario -Actuador "bomba" -Estado 0 | Out-Null
    Ejecutar-Simulador

    $estadoFinal = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"
    $canceladas = Invoke-ApiJson -Method "GET" -Path "/api/cola_automatizacion.php?estado=cancelada"
    $canceladaBomba = @($canceladas.cola | Where-Object { $_.actuador -eq "bomba" })

    if ($estadoFinal.estado.bomba -ne 0 -or $estadoFinal.estado.control_bomba -ne "libre") {
        throw "La bomba no quedo libre/apagada tras cancelar cola."
    }

    if ($canceladaBomba.Count -lt 1) {
        throw "No se marco cola cancelada para bomba."
    }
}

Invoke-Check "Automatizacion toma ventilador libre" {
    Set-ConfiguracionAutomatica -TempMax 20 -HumedadMin 0 -LuzMin 0
    Ejecutar-Simulador
    $estado = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"

    if ($estado.estado.ventilador -ne 1 -or $estado.estado.control_ventilador -ne "automatizacion") {
        throw "El ventilador no quedo bajo automatizacion."
    }
}

Invoke-Check "Usuario no puede apagar ventilador de automatizacion" {
    $respuesta = Crear-ComandoUsuario -Actuador "ventilador" -Estado 0 -ExpectedStatus 409

    if ($respuesta.ok -ne $false -or $respuesta.control_actual -ne "automatizacion") {
        throw "La API no bloqueo apagado de ventilador por usuario."
    }
}

Invoke-Check "Bloqueos son independientes por actuador" {
    Crear-ComandoUsuario -Actuador "lampara" -Estado 1 | Out-Null
    Ejecutar-Simulador
    $estado = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"

    if ($estado.estado.control_ventilador -ne "automatizacion" -or $estado.estado.control_lampara -ne "usuario") {
        throw "Los bloqueos no son independientes entre ventilador y lampara."
    }
}

Invoke-Check "Servo acceso no se controla" {
    $respuesta = Invoke-ApiJson -Method "POST" -Path "/api/comandos.php" -ExpectedStatus 400 -Body @{
        actuador = "servo_acceso"
        estado_solicitado = 1
        origen = "app"
    }

    if ($respuesta.ok -ne $false) {
        throw "La API no rechazo servo_acceso."
    }
}

Invoke-Check "API devuelve control actual y cola pendiente" {
    $estado = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"

    if ($null -eq $estado.estado.control_ventilador -or $null -eq $estado.estado.control_bomba -or $null -eq $estado.estado.control_lampara) {
        throw "La API no devolvio control por actuador."
    }

    if ($null -eq $estado.cola_automatizacion) {
        throw "La API no devolvio cola_automatizacion."
    }
}

Invoke-Check "App/web reflejan bloqueo y cola" {
    Assert-FileContains -Path "web/app.js" -Text "Apagado · Libre"
    Assert-FileContains -Path "web/app.js" -Text "Encendido · Control usuario"
    Assert-FileContains -Path "web/app.js" -Text "Encendido · Control automatizacion"
    Assert-FileContains -Path "web/app.js" -Text "Automatizacion en espera"
    Assert-FileContains -Path "android-app/app/src/main/java/com/maizestream/invernadero/MainActivity.java" -Text "Apagado · Libre"
    Assert-FileContains -Path "android-app/app/src/main/java/com/maizestream/invernadero/MainActivity.java" -Text "Control automatizacion"
    Assert-FileContains -Path "android-app/app/src/main/java/com/maizestream/invernadero/MainActivity.java" -Text "Automatizacion en espera"
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Todas las pruebas de Fase 11 finalizaron correctamente.") -ForegroundColor Green
