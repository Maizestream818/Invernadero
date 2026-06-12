param(
    [switch]$CrearComandoPrueba,
    [switch]$ModoContinuo
)

$ErrorActionPreference = "Stop"

$ApiBaseUrl = "http://localhost:8080/api"
# Para probar con ngrok, cambiar a:
# $ApiBaseUrl = "https://TU-URL.ngrok-free.app/api"

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

function Test-ActuadorPermitido {
    param([string]$Actuador)

    return $Actuador -in @("ventilador", "bomba", "lampara")
}

function Set-EstadoActuadorLocal {
    param(
        [string]$Actuador,
        [int]$Estado
    )

    if ($Actuador -eq "ventilador") {
        $script:EstadoVentilador = $Estado
    } elseif ($Actuador -eq "bomba") {
        $script:EstadoBomba = $Estado
    } elseif ($Actuador -eq "lampara") {
        $script:EstadoLampara = $Estado
    }
}

function Set-ControlActuadorLocal {
    param(
        [string]$Actuador,
        [string]$Control
    )

    if ($Actuador -eq "ventilador") {
        $script:ControlVentilador = $Control
    } elseif ($Actuador -eq "bomba") {
        $script:ControlBomba = $Control
    } elseif ($Actuador -eq "lampara") {
        $script:ControlLampara = $Control
    }
}

function Get-EstadoActuadorLocal {
    param([string]$Actuador)

    if ($Actuador -eq "ventilador") {
        return $script:EstadoVentilador
    }

    if ($Actuador -eq "bomba") {
        return $script:EstadoBomba
    }

    if ($Actuador -eq "lampara") {
        return $script:EstadoLampara
    }

    return 0
}

function Get-ControlActuadorLocal {
    param([string]$Actuador)

    if ($Actuador -eq "ventilador") {
        return $script:ControlVentilador
    }

    if ($Actuador -eq "bomba") {
        return $script:ControlBomba
    }

    if ($Actuador -eq "lampara") {
        return $script:ControlLampara
    }

    return "libre"
}

function Format-EstadoActuadores {
    return "ventilador=$script:EstadoVentilador/$script:ControlVentilador, bomba=$script:EstadoBomba/$script:ControlBomba, lampara=$script:EstadoLampara/$script:ControlLampara, servo_acceso=$script:EstadoServoAcceso"
}

function Sync-EstadoActuadoresDesdeApi {
    $response = Invoke-ApiJson -Method "GET" -Endpoint "/actuadores.php"

    if ($response.ok -ne $true -or $null -eq $response.estado) {
        return
    }

    $estado = $response.estado
    $script:EstadoVentilador = [int]$estado.ventilador
    $script:EstadoBomba = [int]$estado.bomba
    $script:EstadoLampara = [int]$estado.lampara
    $script:EstadoServoAcceso = [int]$estado.servo_acceso
    $script:ControlVentilador = if ($estado.control_ventilador) { [string]$estado.control_ventilador } else { "libre" }
    $script:ControlBomba = if ($estado.control_bomba) { [string]$estado.control_bomba } else { "libre" }
    $script:ControlLampara = if ($estado.control_lampara) { [string]$estado.control_lampara } else { "libre" }
}

function Get-ConfiguracionAutomatizacion {
    $response = Invoke-ApiJson -Method "GET" -Endpoint "/configuracion.php"

    if ($response.ok -ne $true -or $null -eq $response.configuracion) {
        throw "La API no devolvio configuracion de automatizacion."
    }

    $script:ConfiguracionActual = $response.configuracion
    return $response.configuracion
}

function Send-LecturaSensoresSimulada {
    $script:CicloLectura++
    $variacion = [math]::Sin($script:CicloLectura / 3)

    $lecturaGenerada = [pscustomobject]@{
        temperatura_c = [math]::Round(28.5 + $variacion, 1)
        humedad_ambiente_pct = [math]::Round(62.0 + ($variacion * 1.7), 1)
        humedad_suelo_pct = [math]::Round(41.3 + ($variacion * 1.2), 1)
        humedad_suelo_raw = [int](2870 + ($variacion * 45))
        intensidad_luz_lux = [math]::Round(780.5 + ($variacion * 28), 1)
    }

    $lectura = Invoke-ApiJson -Method "POST" -Endpoint "/lecturas.php" -ExpectedStatus 201 -Body $lecturaGenerada

    if ($lectura.ok -ne $true -or -not $lectura.id) {
        throw "No se recibio id de lectura."
    }

    $script:UltimaLecturaId = [int]$lectura.id
    $script:UltimaLectura = $lecturaGenerada

    return $lecturaGenerada
}

function Send-EstadoActuadores {
    $body = @{
        ventilador = $script:EstadoVentilador
        bomba = $script:EstadoBomba
        lampara = $script:EstadoLampara
        servo_acceso = $script:EstadoServoAcceso
        control_ventilador = $script:ControlVentilador
        control_bomba = $script:ControlBomba
        control_lampara = $script:ControlLampara
        modo_control = "automatico"
        origen = "esp32"
    }

    if ($null -ne $script:UltimaLecturaId) {
        $body.lectura_id = $script:UltimaLecturaId
    }

    $estado = Invoke-ApiJson -Method "POST" -Endpoint "/actuadores.php" -ExpectedStatus 201 -Body $body

    if ($estado.ok -ne $true -or -not $estado.id) {
        throw "No se recibio id de estado de actuadores."
    }
}

function Register-EventoActuador {
    param(
        [string]$Actuador,
        [int]$EstadoAnterior,
        [int]$EstadoNuevo,
        [string]$Motivo = "comando_manual",
        [object]$LecturaId = $script:UltimaLecturaId
    )

    $evento = Invoke-ApiJson -Method "POST" -Endpoint "/eventos.php" -ExpectedStatus 201 -Body @{
        actuador = $Actuador
        estado_anterior = $EstadoAnterior
        estado_nuevo = $EstadoNuevo
        motivo = $Motivo
        lectura_id = $LecturaId
        acceso_rfid_id = $null
    }

    if ($evento.ok -ne $true -or -not $evento.id) {
        throw "No se recibio id de evento."
    }
}

function Add-ColaAutomatizacion {
    param(
        [string]$Actuador,
        [string]$Motivo,
        [string]$Detalle
    )

    $body = @{
        actuador = $Actuador
        accion = "encender"
        motivo = $Motivo
        detalle = $Detalle
    }

    if ($null -ne $script:UltimaLecturaId) {
        $body.lectura_id = $script:UltimaLecturaId
    }

    $cola = Invoke-ApiJson -Method "POST" -Endpoint "/cola_automatizacion.php" -Body $body -ExpectedStatus 201
    Register-EventoActuador -Actuador $Actuador -EstadoAnterior (Get-EstadoActuadorLocal -Actuador $Actuador) -EstadoNuevo (Get-EstadoActuadorLocal -Actuador $Actuador) -Motivo "automatizacion_en_cola"
    $script:DecisionesAutomaticas += "$Detalle / automatizacion en cola"
    return $cola
}

function Set-ColaAutomatizacionEstado {
    param(
        [int]$Id,
        [string]$EstadoTarea,
        [string]$Detalle
    )

    $actualizada = Invoke-ApiJson -Method "PUT" -Endpoint "/cola_automatizacion.php" -Body @{
        id = $Id
        estado_tarea = $EstadoTarea
        detalle = $Detalle
    }

    if ($actualizada.ok -ne $true) {
        throw "No se pudo actualizar la tarea de cola $Id."
    }
}

function Get-ColaAutomatizacionPendiente {
    $response = Invoke-ApiJson -Method "GET" -Endpoint "/cola_automatizacion.php?estado=pendiente"

    if ($response.ok -ne $true -or $null -eq $response.cola) {
        return @()
    }

    return @($response.cola)
}

function Set-ComandoEstado {
    param(
        [int]$Id,
        [string]$EstadoComando,
        [string]$Respuesta
    )

    $actualizado = Invoke-ApiJson -Method "PUT" -Endpoint "/comandos.php" -Body @{
        id = $Id
        estado_comando = $EstadoComando
        respuesta_esp32 = $Respuesta
    }

    if ($actualizado.ok -ne $true) {
        throw "El comando $Id no pudo marcarse como $EstadoComando."
    }
}

function Get-ComandosPendientes {
    $response = Invoke-ApiJson -Method "GET" -Endpoint "/comandos.php?estado=pendiente&limite=50"

    if ($response.ok -ne $true) {
        throw "La API no devolvio ok=true al consultar pendientes."
    }

    if ($null -eq $response.comandos) {
        return @()
    }

    return @($response.comandos)
}

function Test-CondicionAutomaticaActiva {
    param(
        [string]$Actuador,
        [object]$Lectura = $script:UltimaLectura,
        [object]$Configuracion = $script:ConfiguracionActual
    )

    if ($null -eq $Lectura -or $null -eq $Configuracion) {
        return $false
    }

    if ($Actuador -eq "ventilador") {
        return [int]$Configuracion.ventilacion_automatica -eq 1 -and [double]$Lectura.temperatura_c -gt [double]$Configuracion.temperatura_max_c
    }

    if ($Actuador -eq "bomba") {
        return [int]$Configuracion.riego_automatico -eq 1 -and [double]$Lectura.humedad_suelo_pct -lt [double]$Configuracion.humedad_suelo_min_pct
    }

    if ($Actuador -eq "lampara") {
        return [int]$Configuracion.iluminacion_automatica -eq 1 -and [double]$Lectura.intensidad_luz_lux -lt [double]$Configuracion.luz_min_lux
    }

    return $false
}

function Get-MotivoEncendidoAutomatico {
    param([string]$Actuador)

    if ($Actuador -eq "ventilador") {
        return "temperatura_alta"
    }

    if ($Actuador -eq "bomba") {
        return "suelo_seco"
    }

    return "luz_baja"
}

function Set-ActuadorAutomatico {
    param(
        [string]$Actuador,
        [int]$EstadoNuevo,
        [string]$Motivo,
        [string]$Descripcion
    )

    $estadoAnterior = Get-EstadoActuadorLocal -Actuador $Actuador
    $controlActual = Get-ControlActuadorLocal -Actuador $Actuador

    if ($controlActual -eq "usuario") {
        if ($EstadoNuevo -eq 1) {
            Add-ColaAutomatizacion -Actuador $Actuador -Motivo (Get-MotivoEncendidoAutomatico -Actuador $Actuador) -Detalle $Descripcion | Out-Null
        } else {
            $script:DecisionesAutomaticas += "$Descripcion (bloqueado por control usuario)"
        }
        return
    }

    if ($controlActual -eq "automatizacion" -and $EstadoNuevo -eq 1) {
        $script:DecisionesAutomaticas += "$Descripcion (automatizacion ya tiene control)"
        return
    }

    if ($controlActual -eq "libre" -and $EstadoNuevo -eq 0 -and $estadoAnterior -eq 0) {
        $script:DecisionesAutomaticas += "$Descripcion (sin cambio)"
        return
    }

    Set-EstadoActuadorLocal -Actuador $Actuador -Estado $EstadoNuevo
    Set-ControlActuadorLocal -Actuador $Actuador -Control $(if ($EstadoNuevo -eq 1) { "automatizacion" } else { "libre" })
    $motivoEvento = if ($EstadoNuevo -eq 1) { "control_tomado_automatizacion" } else { "control_liberado_automatizacion" }
    Register-EventoActuador -Actuador $Actuador -EstadoAnterior $estadoAnterior -EstadoNuevo $EstadoNuevo -Motivo $Motivo
    Register-EventoActuador -Actuador $Actuador -EstadoAnterior $estadoAnterior -EstadoNuevo $EstadoNuevo -Motivo $motivoEvento
    $script:DecisionesAutomaticas += "$Descripcion (cambio $estadoAnterior -> $EstadoNuevo)"
}

function Invoke-AtenderColaActuador {
    param([string]$Actuador)

    $pendientes = @(Get-ColaAutomatizacionPendiente | Where-Object { $_.actuador -eq $Actuador })

    foreach ($tarea in @($pendientes)) {
        if (Test-CondicionAutomaticaActiva -Actuador $Actuador) {
            $estadoAnterior = Get-EstadoActuadorLocal -Actuador $Actuador
            Set-EstadoActuadorLocal -Actuador $Actuador -Estado 1
            Set-ControlActuadorLocal -Actuador $Actuador -Control "automatizacion"
            Register-EventoActuador -Actuador $Actuador -EstadoAnterior $estadoAnterior -EstadoNuevo 1 -Motivo ([string]$tarea.motivo)
            Register-EventoActuador -Actuador $Actuador -EstadoAnterior $estadoAnterior -EstadoNuevo 1 -Motivo "control_tomado_automatizacion"
            Set-ColaAutomatizacionEstado -Id ([int]$tarea.id) -EstadoTarea "ejecutada" -Detalle "Ejecutada al liberar control usuario"
            $script:DecisionesAutomaticas += "cola ejecutada para $Actuador"
        } else {
            Register-EventoActuador -Actuador $Actuador -EstadoAnterior (Get-EstadoActuadorLocal -Actuador $Actuador) -EstadoNuevo (Get-EstadoActuadorLocal -Actuador $Actuador) -Motivo "automatizacion_cancelada"
            Set-ColaAutomatizacionEstado -Id ([int]$tarea.id) -EstadoTarea "cancelada" -Detalle "Condicion automatica ya no aplica"
            $script:DecisionesAutomaticas += "automatizacion cancelada porque ya no aplica para $Actuador"
        }
    }
}

function Invoke-Automatizacion {
    param(
        [object]$Lectura,
        [object]$Configuracion
    )

    $script:DecisionesAutomaticas = @()

    if ([int]$Configuracion.ventilacion_automatica -eq 1) {
        if ([double]$Lectura.temperatura_c -gt [double]$Configuracion.temperatura_max_c) {
            Set-ActuadorAutomatico -Actuador "ventilador" -EstadoNuevo 1 -Motivo "temperatura_alta" -Descripcion "temperatura alta / ventilador encendido"
        } else {
            Set-ActuadorAutomatico -Actuador "ventilador" -EstadoNuevo 0 -Motivo "temperatura_normal" -Descripcion "temperatura normal / ventilador apagado"
        }
    } else {
        $script:DecisionesAutomaticas += "ventilacion automatica desactivada / ventilador sin cambios"
    }

    if ([int]$Configuracion.riego_automatico -eq 1) {
        if ([double]$Lectura.humedad_suelo_pct -lt [double]$Configuracion.humedad_suelo_min_pct) {
            Set-ActuadorAutomatico -Actuador "bomba" -EstadoNuevo 1 -Motivo "suelo_seco" -Descripcion "humedad baja / bomba encendida"
        } else {
            Set-ActuadorAutomatico -Actuador "bomba" -EstadoNuevo 0 -Motivo "suelo_humedo" -Descripcion "humedad suficiente / bomba apagada"
        }
    } else {
        $script:DecisionesAutomaticas += "riego automatico desactivado / bomba sin cambios"
    }

    if ([int]$Configuracion.iluminacion_automatica -eq 1) {
        if ([double]$Lectura.intensidad_luz_lux -lt [double]$Configuracion.luz_min_lux) {
            Set-ActuadorAutomatico -Actuador "lampara" -EstadoNuevo 1 -Motivo "luz_baja" -Descripcion "luz baja / lampara encendida"
        } else {
            Set-ActuadorAutomatico -Actuador "lampara" -EstadoNuevo 0 -Motivo "luz_suficiente" -Descripcion "luz suficiente / lampara apagada"
        }
    } else {
        $script:DecisionesAutomaticas += "iluminacion automatica desactivada / lampara sin cambios"
    }

    return @($script:DecisionesAutomaticas)
}

function Invoke-ProcesarComandosPendientes {
    param(
        [array]$Comandos
    )

    $ejecutados = 0
    $fallidos = 0

    foreach ($comando in @($Comandos)) {
        if ($null -eq $comando) {
            continue
        }

        $id = [int]$comando.id
        $actuador = [string]$comando.actuador
        $estadoSolicitado = [int]$comando.estado_solicitado

        if (-not (Test-ActuadorPermitido -Actuador $actuador)) {
            Set-ComandoEstado -Id $id -EstadoComando "fallido" -Respuesta "servo_acceso no se controla desde app"
            $fallidos++
            continue
        }

        $estadoAnterior = Get-EstadoActuadorLocal -Actuador $actuador
        $controlActual = Get-ControlActuadorLocal -Actuador $actuador

        if ($controlActual -eq "automatizacion") {
            Set-ComandoEstado -Id $id -EstadoComando "fallido" -Respuesta "Actuador bajo control de automatizacion"
            $fallidos++
            continue
        }

        if ($estadoSolicitado -eq 1 -and !($controlActual -eq "libre" -and $estadoAnterior -eq 0)) {
            Set-ComandoEstado -Id $id -EstadoComando "fallido" -Respuesta "El actuador no esta libre y apagado"
            $fallidos++
            continue
        }

        if ($estadoSolicitado -eq 0 -and !($controlActual -eq "usuario" -and $estadoAnterior -eq 1)) {
            Set-ComandoEstado -Id $id -EstadoComando "fallido" -Respuesta "El actuador no esta bajo control usuario"
            $fallidos++
            continue
        }

        Set-EstadoActuadorLocal -Actuador $actuador -Estado $estadoSolicitado
        Set-ControlActuadorLocal -Actuador $actuador -Control $(if ($estadoSolicitado -eq 1) { "usuario" } else { "libre" })
        Send-EstadoActuadores
        Register-EventoActuador -Actuador $actuador -EstadoAnterior $estadoAnterior -EstadoNuevo $estadoSolicitado -Motivo "comando_manual"
        Register-EventoActuador -Actuador $actuador -EstadoAnterior $estadoAnterior -EstadoNuevo $estadoSolicitado -Motivo $(if ($estadoSolicitado -eq 1) { "control_tomado_usuario" } else { "control_liberado_usuario" })
        Set-ComandoEstado -Id $id -EstadoComando "ejecutado" -Respuesta "Comando ejecutado por ESP32 simulado"
        if ($estadoSolicitado -eq 0) {
            Invoke-AtenderColaActuador -Actuador $actuador
            Send-EstadoActuadores
        }
        $ejecutados++
    }

    return [pscustomobject]@{
        Ejecutados = $ejecutados
        Fallidos = $fallidos
    }
}

function Get-ComandosPendientesProcesables {
    $pendientes = @(Get-ComandosPendientes | Where-Object { $_.actuador -in @("ventilador", "bomba", "lampara") })
    return $pendientes
}

function Invoke-CicloAutomatizacion {
    Sync-EstadoActuadoresDesdeApi
    $configuracion = Get-ConfiguracionAutomatizacion
    Write-Host ("Configuracion aplicada: temp_max={0} C, humedad_min={1} %, luz_min={2} lux, ventilacion={3}, riego={4}, iluminacion={5}, duracion_riego={6} s" -f `
        $configuracion.temperatura_max_c,
        $configuracion.humedad_suelo_min_pct,
        $configuracion.luz_min_lux,
        $configuracion.ventilacion_automatica,
        $configuracion.riego_automatico,
        $configuracion.iluminacion_automatica,
        $configuracion.duracion_riego_seg)

    $lectura = Send-LecturaSensoresSimulada
    Write-Host ("Lectura generada con variacion simulada: temperatura={0} C, humedad_ambiente={1} %, humedad_suelo={2} %, humedad_suelo_raw={3}, luz={4} lux" -f `
        $lectura.temperatura_c,
        $lectura.humedad_ambiente_pct,
        $lectura.humedad_suelo_pct,
        $lectura.humedad_suelo_raw,
        $lectura.intensidad_luz_lux)

    $decisiones = @(Invoke-Automatizacion -Lectura $lectura -Configuracion $configuracion)
    Write-Host "Decisiones automaticas:"
    foreach ($decision in @($decisiones)) {
        Write-Host " - $decision"
    }

    Send-EstadoActuadores

    $comandos = @(Get-ComandosPendientes)
    Write-Host "Comandos manuales encontrados: $($comandos.Count)"

    $resultado = Invoke-ProcesarComandosPendientes -Comandos $comandos
    Write-Host "Comandos manuales procesados: ejecutados=$($resultado.Ejecutados), fallidos=$($resultado.Fallidos)"
    Write-Host "Estado final de actuadores: $(Format-EstadoActuadores)"

    return [pscustomobject]@{
        Lectura = $lectura
        Configuracion = $configuracion
        Decisiones = $decisiones
        ComandosEjecutados = $resultado.Ejecutados
        ComandosFallidos = $resultado.Fallidos
    }
}

function Start-ModoContinuo {
    Write-Host "Modo continuo activo. Presiona Ctrl + C para detener." -ForegroundColor Cyan
    Write-Host "El simulador consultara configuracion, enviara lecturas y consultara comandos pendientes cada 2 segundos."

    while ($true) {
        $inicioCiclo = Get-Date

        try {
            Write-Host "[$($inicioCiclo.ToString('yyyy-MM-dd HH:mm:ss'))] ciclo automatico iniciado..."
            Invoke-CicloAutomatizacion | Out-Null
            Write-Host "Hora del ultimo ciclo: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
        } catch {
            Write-Host "[FALL$([char]0x00D3)] Ciclo de modo continuo - $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Hora del ultimo ciclo: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
        }

        Start-Sleep -Seconds 2
    }
}

Write-Host "Simulador ESP32 - Invernadero Inteligente IoT"
Write-Host "API base: $ApiBaseUrl"
Write-Host "Crear comando de prueba: $($CrearComandoPrueba.IsPresent)"
Write-Host "Modo continuo: $($ModoContinuo.IsPresent)"
Write-Host "================================================"

$script:EstadoVentilador = 0
$script:EstadoBomba = 0
$script:EstadoLampara = 0
$script:EstadoServoAcceso = 0
$script:ControlVentilador = "libre"
$script:ControlBomba = "libre"
$script:ControlLampara = "libre"
$script:ComandosPendientes = @()
$script:TotalEjecutados = 0
$script:TotalFallidos = 0
$script:CicloLectura = 0
$script:UltimaLecturaId = $null
$script:UltimaLectura = $null
$script:ConfiguracionActual = $null
$script:DecisionesAutomaticas = @()

Invoke-Check "Conexion API correcta" {
    $status = Invoke-ApiJson -Method "GET" -Endpoint "/status.php"

    if ($status.ok -ne $true -or $status.conexion_bd -ne $true) {
        throw "La API no reporta ok=true y conexion_bd=true."
    }
}

if ($CrearComandoPrueba) {
    Invoke-Check "Comando pendiente de prueba creado" {
        $comando = Invoke-ApiJson -Method "POST" -Endpoint "/comandos.php" -ExpectedStatus 201 -Body @{
            actuador = "bomba"
            estado_solicitado = 1
            origen = "app"
        }

        if ($comando.ok -ne $true -or -not $comando.id) {
            throw "No se recibio id de comando."
        }
    }
} else {
    Write-Host "[INFO] No se crea comando nuevo porque no se uso -CrearComandoPrueba."
}

if ($ModoContinuo) {
    Start-ModoContinuo
    return
}

Invoke-Check "Ciclo de automatizacion ejecutado" {
    Invoke-CicloAutomatizacion | Out-Null
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

Invoke-Check "No quedan comandos pendientes procesables" {
    $pendientes = @(Get-ComandosPendientesProcesables)

    if ($pendientes.Count -gt 0) {
        throw "Quedan $($pendientes.Count) comandos pendientes procesables."
    }

    Write-Host "No quedan comandos pendientes procesables"
}

Write-Host "================================================"
Write-Host ("PAS" + [char]0x00D3 + " - Simulacion ESP32 finalizada correctamente.") -ForegroundColor Green
