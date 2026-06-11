#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

#if __has_include("config.h")
#include "config.h"
#else
#error "Copia config.example.h como config.h y configura tus credenciales locales."
#endif

WiFiClient clienteHttp;
WiFiClientSecure clienteHttps;

int estadoVentilador = 0;
int estadoBomba = 0;
int estadoLampara = 0;
int estadoServoAcceso = 0;

unsigned long ultimaEjecucion = 0;
const unsigned long intervaloSimulacionMs = 30000;

void setup() {
  Serial.begin(115200);
  delay(500);

  conectarWifi();

  enviarLecturaSimulada();
  enviarEstadoActuadores();
  registrarRfidDemo();
  consultarYEjecutarComandoPendiente();
}

void loop() {
  if (millis() - ultimaEjecucion >= intervaloSimulacionMs) {
    ultimaEjecucion = millis();

    // En firmware final aqui se leeran sensores reales.
    enviarLecturaSimulada();
    enviarEstadoActuadores();
    consultarYEjecutarComandoPendiente();
  }
}

void conectarWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Conectando a Wi-Fi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("Wi-Fi conectado. IP: ");
  Serial.println(WiFi.localIP());
}

String requestApi(const String& metodo, const String& endpoint, const String& payload) {
  if (WiFi.status() != WL_CONNECTED) {
    conectarWifi();
  }

  HTTPClient http;
  String url = String(API_BASE_URL) + endpoint;

  if (url.startsWith("https://")) {
    // Solo para demo con ngrok. En produccion debe validarse certificado.
    clienteHttps.setInsecure();
    http.begin(clienteHttps, url);
  } else {
    http.begin(clienteHttp, url);
  }

  http.addHeader("Accept", "application/json");
  http.addHeader("Content-Type", "application/json");

  int codigoHttp = -1;

  if (metodo == "GET") {
    codigoHttp = http.GET();
  } else if (metodo == "POST") {
    codigoHttp = http.POST(payload);
  } else if (metodo == "PUT") {
    codigoHttp = http.PUT(payload);
  }

  String respuesta = http.getString();

  Serial.print(metodo);
  Serial.print(" ");
  Serial.print(endpoint);
  Serial.print(" -> HTTP ");
  Serial.println(codigoHttp);

  if (codigoHttp < 200 || codigoHttp >= 300) {
    Serial.println(respuesta);
    http.end();
    return "";
  }

  http.end();
  return respuesta;
}

void enviarLecturaSimulada() {
  String payload = "{";
  payload += "\"temperatura_c\":28.5,";
  payload += "\"humedad_ambiente_pct\":62.0,";
  payload += "\"humedad_suelo_pct\":41.3,";
  payload += "\"humedad_suelo_raw\":2870,";
  payload += "\"intensidad_luz_lux\":780.5";
  payload += "}";

  requestApi("POST", "/lecturas.php", payload);
}

void enviarEstadoActuadores() {
  String payload = "{";
  payload += "\"ventilador\":" + String(estadoVentilador) + ",";
  payload += "\"bomba\":" + String(estadoBomba) + ",";
  payload += "\"lampara\":" + String(estadoLampara) + ",";
  payload += "\"servo_acceso\":" + String(estadoServoAcceso) + ",";
  payload += "\"modo_control\":\"automatico\",";
  payload += "\"origen\":\"esp32\"";
  payload += "}";

  requestApi("POST", "/actuadores.php", payload);
}

void registrarRfidDemo() {
  String payload = "{";
  payload += "\"uid\":\"A1B2C3D4\",";
  payload += "\"servo_abierto\":1";
  payload += "}";

  requestApi("POST", "/accesos.php", payload);
}

void consultarYEjecutarComandoPendiente() {
  String respuesta = requestApi("GET", "/comandos.php?estado=pendiente&limite=1", "");

  if (respuesta.length() == 0 || respuesta.indexOf("\"comandos\":[]") >= 0) {
    Serial.println("Sin comandos pendientes.");
    return;
  }

  int comandoId = extraerEntero(respuesta, "id", -1);
  String actuador = extraerTexto(respuesta, "actuador");
  int estadoSolicitado = extraerEntero(respuesta, "estado_solicitado", -1);

  if (comandoId <= 0 || estadoSolicitado < 0) {
    Serial.println("Comando pendiente con formato no valido.");
    return;
  }

  if (!actuadorPermitido(actuador)) {
    marcarComandoFallido(comandoId, "Actuador no permitido por firmware base");
    return;
  }

  int estadoAnterior = obtenerEstadoActuador(actuador);
  actualizarEstadoActuador(actuador, estadoSolicitado);
  enviarEstadoActuadores();
  registrarEvento(actuador, estadoAnterior, estadoSolicitado);
  marcarComandoEjecutado(comandoId);
}

bool actuadorPermitido(const String& actuador) {
  return actuador == "ventilador" || actuador == "bomba" || actuador == "lampara";
}

int obtenerEstadoActuador(const String& actuador) {
  if (actuador == "ventilador") {
    return estadoVentilador;
  }

  if (actuador == "bomba") {
    return estadoBomba;
  }

  if (actuador == "lampara") {
    return estadoLampara;
  }

  return 0;
}

void actualizarEstadoActuador(const String& actuador, int estado) {
  if (actuador == "ventilador") {
    estadoVentilador = estado;
  } else if (actuador == "bomba") {
    estadoBomba = estado;
  } else if (actuador == "lampara") {
    estadoLampara = estado;
  }

  // servo_acceso no se controla por comandos remotos en esta fase.
}

void registrarEvento(const String& actuador, int estadoAnterior, int estadoNuevo) {
  String payload = "{";
  payload += "\"actuador\":\"" + actuador + "\",";
  payload += "\"estado_anterior\":" + String(estadoAnterior) + ",";
  payload += "\"estado_nuevo\":" + String(estadoNuevo) + ",";
  payload += "\"motivo\":\"comando_manual\",";
  payload += "\"lectura_id\":null,";
  payload += "\"acceso_rfid_id\":null";
  payload += "}";

  requestApi("POST", "/eventos.php", payload);
}

void marcarComandoEjecutado(int comandoId) {
  String payload = "{";
  payload += "\"id\":" + String(comandoId) + ",";
  payload += "\"estado_comando\":\"ejecutado\",";
  payload += "\"respuesta_esp32\":\"Comando ejecutado por ESP32 simulado\"";
  payload += "}";

  requestApi("PUT", "/comandos.php", payload);
}

void marcarComandoFallido(int comandoId, const String& motivo) {
  String payload = "{";
  payload += "\"id\":" + String(comandoId) + ",";
  payload += "\"estado_comando\":\"fallido\",";
  payload += "\"respuesta_esp32\":\"" + motivo + "\"";
  payload += "}";

  requestApi("PUT", "/comandos.php", payload);
}

String extraerTexto(const String& json, const String& campo) {
  String patron = "\"" + campo + "\":\"";
  int inicio = json.indexOf(patron);

  if (inicio < 0) {
    return "";
  }

  inicio += patron.length();
  int fin = json.indexOf("\"", inicio);

  if (fin < 0) {
    return "";
  }

  return json.substring(inicio, fin);
}

int extraerEntero(const String& json, const String& campo, int valorDefault) {
  String patron = "\"" + campo + "\":";
  int inicio = json.indexOf(patron);

  if (inicio < 0) {
    return valorDefault;
  }

  inicio += patron.length();
  int fin = inicio;

  while (fin < json.length() && isDigit(json.charAt(fin))) {
    fin++;
  }

  if (fin == inicio) {
    return valorDefault;
  }

  return json.substring(inicio, fin).toInt();
}
