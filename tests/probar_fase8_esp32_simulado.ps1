$ErrorActionPreference = "Stop"
$BaseUrl = "http://localhost:8080"

Write-Host "ADVERTENCIA: esta prueba reconstruye la base de datos y elimina datos previos del volumen MySQL." -ForegroundColor Yellow
Write-Host "Pruebas Fase 8 ESP32 simulado - Invernadero Inteligente IoT"
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

function Invoke-MySqlScalar {
    param(
        [string]$Query
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = & docker compose exec -T -e MYSQL_PWD=invernadero_pass db mysql -uinvernadero_user invernadero_iot -N -B -e $Query 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        $detail = ($output | Out-String).Trim()
        throw "Consulta MySQL fallida: $Query. $detail"
    }

    return (($output | Select-Object -First 1) | Out-String).Trim()
}

function Assert-CountEquals {
    param(
        [string]$Table,
        [int]$Expected
    )

    $count = [int](Invoke-MySqlScalar -Query "SELECT COUNT(*) FROM $Table;")

    if ($count -ne $Expected) {
        throw "Tabla $Table esperaba $Expected registros, tiene $count."
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

Invoke-Check "API status disponible" {
    $status = Invoke-ApiJson -Method "GET" -Path "/api/status.php"

    if ($status.ok -ne $true -or $status.conexion_bd -ne $true) {
        throw "status.php no reporta ok=true y conexion_bd=true."
    }
}

Invoke-Check "Datos semilla correctos tras reconstruir" {
    Assert-CountEquals -Table "configuracion_automatizacion" -Expected 1
    $tarjetasDemo = [int](Invoke-MySqlScalar -Query "SELECT COUNT(*) FROM tarjetas_rfid WHERE uid = 'A1B2C3D4' AND activa = 1;")

    if ($tarjetasDemo -ne 1) {
        throw "No existe exactamente una tarjeta RFID demo activa A1B2C3D4."
    }
}

Invoke-Check "Tablas operativas vacias antes del simulador" {
    $tablasVacias = @(
        "lecturas",
        "estados_actuadores",
        "accesos_rfid",
        "eventos_actuadores",
        "comandos_actuadores",
        "calibraciones_sensores"
    )

    foreach ($tabla in $tablasVacias) {
        Assert-CountEquals -Table $tabla -Expected 0
    }
}

Invoke-Check "Endpoints no muestran datos operativos previos" {
    $lecturas = Invoke-ApiJson -Method "GET" -Path "/api/lecturas.php?limite=1"
    $accesos = Invoke-ApiJson -Method "GET" -Path "/api/accesos.php?limite=1"
    $comandos = Invoke-ApiJson -Method "GET" -Path "/api/comandos.php?limite=5"
    $eventos = Invoke-ApiJson -Method "GET" -Path "/api/eventos.php?limite=5"

    if ($lecturas.lecturas.Count -ne 0) {
        throw "lecturas no esta vacia."
    }

    if ($accesos.accesos.Count -ne 0) {
        throw "accesos no esta vacia."
    }

    if ($comandos.comandos.Count -ne 0) {
        throw "comandos no esta vacia."
    }

    if ($eventos.eventos.Count -ne 0) {
        throw "eventos no esta vacia."
    }
}

Invoke-Check "Simulador soporta modo continuo" {
    $simulador = Get-Content -Raw "tests/simular_esp32.ps1"

    if (-not $simulador.Contains("ModoContinuo")) {
        throw "simular_esp32.ps1 no contiene parametro ModoContinuo."
    }

    if (-not $simulador.Contains("Start-ModoContinuo")) {
        throw "simular_esp32.ps1 no contiene flujo de modo continuo."
    }

    if (-not $simulador.Contains("/comandos.php?estado=pendiente&limite=50")) {
        throw "simular_esp32.ps1 no consulta comandos pendientes con limite 50."
    }

    if (-not $simulador.Contains("Start-Sleep -Seconds 2")) {
        throw "simular_esp32.ps1 no espera 2 segundos entre ciclos."
    }

    if (-not $simulador.Contains("Send-LecturaSensoresSimulada")) {
        throw "simular_esp32.ps1 no envia lecturas simuladas en modo continuo."
    }

    if (-not $simulador.Contains("variacion simulada")) {
        throw "simular_esp32.ps1 no deja claro que las lecturas varian entre ciclos."
    }

    if (-not $simulador.Contains("No se crea comando nuevo porque no se uso -CrearComandoPrueba")) {
        throw "simular_esp32.ps1 no deja claro que no crea comandos sin -CrearComandoPrueba."
    }
}

Invoke-Check "Simulador ESP32 ejecutado" {
    Invoke-NativeCommand -FilePath "powershell" -Arguments @("-ExecutionPolicy", "Bypass", "-File", ".\tests\simular_esp32.ps1", "-CrearComandoPrueba") | Out-Null
}

Invoke-Check "Despues del simulador existen lecturas" {
    $lecturas = Invoke-ApiJson -Method "GET" -Path "/api/lecturas.php?limite=1"

    if ($lecturas.lecturas.Count -lt 1) {
        throw "No se encontraron lecturas generadas."
    }
}

Invoke-Check "Despues del simulador existe estado de actuadores" {
    $estado = Invoke-ApiJson -Method "GET" -Path "/api/actuadores.php"

    if ($estado.estado -eq $null -or $estado.estado.bomba -ne 1) {
        throw "No se encontro estado de actuadores con bomba encendida."
    }
}

Invoke-Check "Despues del simulador existen accesos RFID" {
    $accesos = Invoke-ApiJson -Method "GET" -Path "/api/accesos.php?limite=1"

    if ($accesos.accesos.Count -lt 1 -or $accesos.accesos[0].uid -ne "A1B2C3D4") {
        throw "No se encontro acceso RFID demo generado."
    }
}

Invoke-Check "Despues del simulador existe comando ejecutado" {
    $comandos = Invoke-ApiJson -Method "GET" -Path "/api/comandos.php?limite=5"

    if ($comandos.comandos.Count -lt 1) {
        throw "No se encontraron comandos generados."
    }

    $ejecutados = @($comandos.comandos | Where-Object { $_.estado_comando -eq "ejecutado" })

    if ($ejecutados.Count -lt 1) {
        throw "No existe comando ejecutado."
    }
}

Invoke-Check "Despues del simulador existe evento de bomba" {
    $eventos = Invoke-ApiJson -Method "GET" -Path "/api/eventos.php?limite=5"

    if ($eventos.eventos.Count -lt 1) {
        throw "No se encontraron eventos generados."
    }

    $eventosBomba = @($eventos.eventos | Where-Object { $_.actuador -eq "bomba" })

    if ($eventosBomba.Count -lt 1) {
        throw "No existe evento relacionado con bomba."
    }
}

Invoke-Check "No existen comandos para servo_acceso" {
    $comandos = Invoke-ApiJson -Method "GET" -Path "/api/comandos.php?limite=100"
    $comandosServo = @($comandos.comandos | Where-Object { $_.actuador -eq "servo_acceso" })

    if ($comandosServo.Count -gt 0) {
        throw "Se encontraron comandos para servo_acceso."
    }
}

Invoke-Check "No quedan comandos pendientes procesables" {
    $pendientes = Invoke-ApiJson -Method "GET" -Path "/api/comandos.php?estado=pendiente&limite=50"
    $pendientesProcesables = @($pendientes.comandos | Where-Object { $_.actuador -in @("bomba", "ventilador", "lampara") })

    if ($pendientesProcesables.Count -gt 0) {
        throw "Quedan comandos pendientes procesables: $($pendientesProcesables.Count)"
    }
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Todas las pruebas de Fase 8 finalizaron correctamente.") -ForegroundColor Green
