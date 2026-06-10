const API_BASE_URL = "/api";
const INTERVALO_ACTUALIZACION_MS = 5000;

const $ = (id) => document.getElementById(id);

async function obtenerJson(endpoint) {
    const respuesta = await fetch(`${API_BASE_URL}${endpoint}`, {
        headers: {
            Accept: "application/json",
        },
    });

    let datos = null;

    try {
        datos = await respuesta.json();
    } catch (error) {
        throw new Error(`Respuesta no valida de ${endpoint}`);
    }

    if (!respuesta.ok || datos.ok === false) {
        throw new Error(datos.mensaje || `Error HTTP ${respuesta.status} en ${endpoint}`);
    }

    return datos;
}

function texto(valor, fallback = "Sin datos") {
    return valor === null || valor === undefined || valor === "" ? fallback : String(valor);
}

function formatearFecha(valor) {
    if (!valor) {
        return "Sin datos";
    }

    const fecha = new Date(String(valor).replace(" ", "T"));

    if (Number.isNaN(fecha.getTime())) {
        return String(valor);
    }

    return fecha.toLocaleString("es-MX", {
        dateStyle: "short",
        timeStyle: "medium",
    });
}

function formatearBinario(valor, textoActivo = "Encendido", textoInactivo = "Apagado") {
    return Number(valor) === 1 ? textoActivo : textoInactivo;
}

function claseBinaria(valor) {
    return Number(valor) === 1 ? "estado-on" : "estado-off";
}

function setTexto(id, valor) {
    $(id).textContent = texto(valor);
}

function setEtiqueta(id, valor, clase) {
    const elemento = $(id);
    elemento.textContent = texto(valor);
    elemento.className = `etiqueta ${clase}`;
}

function limpiarErrores() {
    const contenedor = $("errores");
    contenedor.innerHTML = "";
    contenedor.hidden = true;
}

function mostrarError(mensaje) {
    const contenedor = $("errores");
    const parrafo = document.createElement("p");
    parrafo.textContent = mensaje;
    contenedor.appendChild(parrafo);
    contenedor.hidden = false;
}

function mostrarSinDatosTabla(tbodyId, columnas) {
    const tbody = $(tbodyId);
    tbody.innerHTML = "";
    const fila = document.createElement("tr");
    const celda = document.createElement("td");
    celda.colSpan = columnas;
    celda.className = "sin-datos";
    celda.textContent = "Sin datos";
    fila.appendChild(celda);
    tbody.appendChild(fila);
}

function agregarCelda(fila, contenido) {
    const celda = document.createElement("td");

    if (contenido instanceof Node) {
        celda.appendChild(contenido);
    } else {
        celda.textContent = texto(contenido);
    }

    fila.appendChild(celda);
}

function crearEtiqueta(textoEtiqueta, clase) {
    const span = document.createElement("span");
    span.className = `etiqueta ${clase}`;
    span.textContent = textoEtiqueta;
    return span;
}

function estadoComandoClase(estado) {
    const clases = {
        pendiente: "estado-pendiente",
        ejecutado: "estado-ejecutado",
        fallido: "estado-fallido",
        cancelado: "estado-cancelado",
    };

    return clases[estado] || "estado-info";
}

async function cargarEstadoApi() {
    try {
        const datos = await obtenerJson("/status.php");
        setEtiqueta("estado-api-etiqueta", "API conectada", "estado-ok");
        setTexto("estado-api-servicio", datos.servicio);
        setTexto("estado-api-bd", datos.base_datos);
    } catch (error) {
        setEtiqueta("estado-api-etiqueta", "API no disponible", "estado-error");
        setTexto("estado-api-servicio", "Sin datos");
        setTexto("estado-api-bd", "Sin datos");
        mostrarError(`Estado API: ${error.message}`);
    }
}

async function cargarUltimaLectura() {
    try {
        const datos = await obtenerJson("/lecturas.php?limite=1");
        const lectura = Array.isArray(datos.lecturas) ? datos.lecturas[0] : null;

        if (!lectura) {
            ["lectura-temperatura", "lectura-humedad-ambiente", "lectura-humedad-suelo", "lectura-humedad-raw", "lectura-luz", "lectura-fecha"]
                .forEach((id) => setTexto(id, "Sin datos"));
            return;
        }

        setTexto("lectura-temperatura", lectura.temperatura_c);
        setTexto("lectura-humedad-ambiente", lectura.humedad_ambiente_pct);
        setTexto("lectura-humedad-suelo", lectura.humedad_suelo_pct);
        setTexto("lectura-humedad-raw", lectura.humedad_suelo_raw);
        setTexto("lectura-luz", lectura.intensidad_luz_lux);
        setTexto("lectura-fecha", formatearFecha(lectura.fecha));
    } catch (error) {
        mostrarError(`Ultima lectura: ${error.message}`);
    }
}

async function cargarEstadoActuadores() {
    try {
        const datos = await obtenerJson("/actuadores.php");
        const estado = datos.estado;

        if (!estado) {
            ["act-ventilador", "act-bomba", "act-lampara", "act-servo"].forEach((id) => {
                setEtiqueta(id, "Sin datos", "estado-neutro");
            });
            setTexto("act-modo", "Sin datos");
            setTexto("act-origen", "Sin datos");
            setTexto("act-fecha", "Sin datos");
            return;
        }

        setEtiqueta("act-ventilador", formatearBinario(estado.ventilador), claseBinaria(estado.ventilador));
        setEtiqueta("act-bomba", formatearBinario(estado.bomba, "Encendida", "Apagada"), claseBinaria(estado.bomba));
        setEtiqueta("act-lampara", formatearBinario(estado.lampara, "Encendida", "Apagada"), claseBinaria(estado.lampara));
        setEtiqueta("act-servo", formatearBinario(estado.servo_acceso, "Abierto", "Cerrado"), claseBinaria(estado.servo_acceso));
        setTexto("act-modo", estado.modo_control);
        setTexto("act-origen", estado.origen);
        setTexto("act-fecha", formatearFecha(estado.fecha));
    } catch (error) {
        mostrarError(`Estado de actuadores: ${error.message}`);
    }
}

async function cargarConfiguracion() {
    try {
        const datos = await obtenerJson("/configuracion.php");
        const cfg = datos.configuracion;

        if (!cfg) {
            mostrarError("Configuracion: sin datos registrados.");
            return;
        }

        setTexto("cfg-temp-max", `${cfg.temperatura_max_c} \u00B0C`);
        setTexto("cfg-hum-suelo-min", `${cfg.humedad_suelo_min_pct} %`);
        setTexto("cfg-luz-min", `${cfg.luz_min_lux} lux`);
        setEtiqueta("cfg-ventilacion", formatearBinario(cfg.ventilacion_automatica, "Activa", "Inactiva"), claseBinaria(cfg.ventilacion_automatica));
        setEtiqueta("cfg-riego", formatearBinario(cfg.riego_automatico, "Activo", "Inactivo"), claseBinaria(cfg.riego_automatico));
        setEtiqueta("cfg-iluminacion", formatearBinario(cfg.iluminacion_automatica, "Activa", "Inactiva"), claseBinaria(cfg.iluminacion_automatica));
        setTexto("cfg-duracion-riego", `${cfg.duracion_riego_seg} s`);
        setTexto("cfg-intervalo", `${cfg.intervalo_lectura_seg} s`);
    } catch (error) {
        mostrarError(`Configuracion: ${error.message}`);
    }
}

async function cargarTablaLecturas() {
    try {
        const datos = await obtenerJson("/lecturas.php?limite=10");
        const lecturas = Array.isArray(datos.lecturas) ? datos.lecturas : [];
        const tbody = $("tabla-lecturas");
        tbody.innerHTML = "";

        if (lecturas.length === 0) {
            mostrarSinDatosTabla("tabla-lecturas", 6);
            return;
        }

        lecturas.forEach((lectura) => {
            const fila = document.createElement("tr");
            agregarCelda(fila, lectura.id);
            agregarCelda(fila, `${lectura.temperatura_c} \u00B0C`);
            agregarCelda(fila, `${lectura.humedad_ambiente_pct} %`);
            agregarCelda(fila, `${lectura.humedad_suelo_pct} %`);
            agregarCelda(fila, `${lectura.intensidad_luz_lux} lux`);
            agregarCelda(fila, formatearFecha(lectura.fecha));
            tbody.appendChild(fila);
        });
    } catch (error) {
        mostrarSinDatosTabla("tabla-lecturas", 6);
        mostrarError(`Tabla lecturas: ${error.message}`);
    }
}

async function cargarTablaAccesos() {
    try {
        const datos = await obtenerJson("/accesos.php?limite=10");
        const accesos = Array.isArray(datos.accesos) ? datos.accesos : [];
        const tbody = $("tabla-accesos");
        tbody.innerHTML = "";

        if (accesos.length === 0) {
            mostrarSinDatosTabla("tabla-accesos", 6);
            return;
        }

        accesos.forEach((acceso) => {
            const fila = document.createElement("tr");
            agregarCelda(fila, acceso.id);
            agregarCelda(fila, acceso.uid);
            agregarCelda(fila, acceso.nombre_usuario || "Sin usuario");
            agregarCelda(fila, crearEtiqueta(Number(acceso.autorizado) === 1 ? "Autorizado" : "Rechazado", Number(acceso.autorizado) === 1 ? "estado-ok" : "estado-error"));
            agregarCelda(fila, crearEtiqueta(Number(acceso.servo_abierto) === 1 ? "Abierto" : "Cerrado", Number(acceso.servo_abierto) === 1 ? "estado-on" : "estado-off"));
            agregarCelda(fila, formatearFecha(acceso.fecha));
            tbody.appendChild(fila);
        });
    } catch (error) {
        mostrarSinDatosTabla("tabla-accesos", 6);
        mostrarError(`Tabla accesos RFID: ${error.message}`);
    }
}

async function cargarTablaEventos() {
    try {
        const datos = await obtenerJson("/eventos.php?limite=10");
        const eventos = Array.isArray(datos.eventos) ? datos.eventos : [];
        const tbody = $("tabla-eventos");
        tbody.innerHTML = "";

        if (eventos.length === 0) {
            mostrarSinDatosTabla("tabla-eventos", 6);
            return;
        }

        eventos.forEach((evento) => {
            const fila = document.createElement("tr");
            agregarCelda(fila, evento.id);
            agregarCelda(fila, evento.actuador);
            agregarCelda(fila, evento.estado_anterior === null ? "Sin datos" : formatearBinario(evento.estado_anterior));
            agregarCelda(fila, formatearBinario(evento.estado_nuevo));
            agregarCelda(fila, evento.motivo);
            agregarCelda(fila, formatearFecha(evento.fecha));
            tbody.appendChild(fila);
        });
    } catch (error) {
        mostrarSinDatosTabla("tabla-eventos", 6);
        mostrarError(`Tabla eventos: ${error.message}`);
    }
}

async function cargarTablaComandos() {
    try {
        const datos = await obtenerJson("/comandos.php?limite=10");
        const comandos = Array.isArray(datos.comandos) ? datos.comandos : [];
        const tbody = $("tabla-comandos");
        tbody.innerHTML = "";

        if (comandos.length === 0) {
            mostrarSinDatosTabla("tabla-comandos", 7);
            return;
        }

        comandos.forEach((comando) => {
            const fila = document.createElement("tr");
            agregarCelda(fila, comando.id);
            agregarCelda(fila, comando.actuador);
            agregarCelda(fila, crearEtiqueta(formatearBinario(comando.estado_solicitado), claseBinaria(comando.estado_solicitado)));
            agregarCelda(fila, comando.origen);
            agregarCelda(fila, crearEtiqueta(comando.estado_comando, estadoComandoClase(comando.estado_comando)));
            agregarCelda(fila, formatearFecha(comando.fecha_creacion));
            agregarCelda(fila, formatearFecha(comando.fecha_ejecucion));
            tbody.appendChild(fila);
        });
    } catch (error) {
        mostrarSinDatosTabla("tabla-comandos", 7);
        mostrarError(`Tabla comandos: ${error.message}`);
    }
}

async function cargarTodo() {
    limpiarErrores();

    await Promise.all([
        cargarEstadoApi(),
        cargarUltimaLectura(),
        cargarEstadoActuadores(),
        cargarConfiguracion(),
        cargarTablaLecturas(),
        cargarTablaAccesos(),
        cargarTablaEventos(),
        cargarTablaComandos(),
    ]);

    $("ultima-actualizacion").textContent = new Date().toLocaleString("es-MX", {
        dateStyle: "short",
        timeStyle: "medium",
    });
}

document.addEventListener("DOMContentLoaded", () => {
    $("btn-actualizar").addEventListener("click", cargarTodo);
    cargarTodo();
    window.setInterval(cargarTodo, INTERVALO_ACTUALIZACION_MS);
});
