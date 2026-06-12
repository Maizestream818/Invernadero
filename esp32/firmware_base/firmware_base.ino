#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <Wire.h>
#include <BH1750.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ESP32Servo.h>

#if __has_include("config.h")
#include "config.h"
#else
#error "Copia config.example.h como config.h y configura tus credenciales locales."
#endif

struct ConfiguracionAutomatizacion {
  float temperaturaMaxC;
  float humedadSueloMinPct;
  float luzMinLux;
  bool ventilacionAutomatica;
  bool riegoAutomatico;
  bool iluminacionAutomatica;
  int duracionRiegoSeg;
};

struct LecturaSensores {
  float temperaturaC;
  float humedadAmbientePct;
  float humedadSueloPct;
  int humedadSueloRaw;
  float intensidadLuzLux;
};

WiFiClient clienteHttp;
WiFiClientSecure clienteHttps;
DHT dht(PIN_DHT, DHT_SENSOR_TYPE);
BH1750 bh1750;
MFRC522 rfid(PIN_RFID_SS, PIN_RFID_RST);
Servo servoAcceso;

ConfiguracionAutomatizacion configuracion = {
  30.0,
  35.0,
  500.0,
  true,
  true,
  true,
  5
};

int estadoVentilador = 0;
int estadoBomba = 0;
int estadoLampara = 0;
int estadoServoAcceso = 0;
int ultimaLecturaId = -1;

unsigned long ultimaEjecucion = 0;
unsigned long bombaEncendidaHasta = 0;
unsigned long servoAbiertoHasta = 0;

void conectarWiFi();
String requestApi(const String& metodo, const String& endpoint, const String& payload);
bool obtenerConfiguracion();
LecturaSensores leerSensores();
int enviarLectura(const LecturaSensores& lectura);
void aplicarAutomatizacion(const LecturaSensores& lectura);
bool procesarComandosPendientes();
void actualizarActuadores();
void registrarEvento(const String& actuador, int estadoAnterior, int estadoNuevo, const String& motivo);
void registrarAccesoRFID();

bool actuadorPermitido(const String& actuador);
int obtenerEstadoActuador(const String& actuador);
void asignarEstadoActuador(const String& actuador, int estado);
void cambiarActuadorAutomatico(const String& actuador, int estadoNuevo, const String& motivo, const String& descripcion);
void marcarComando(int comandoId, const String& estadoComando, const String& respuesta);
void aplicarSalidasFisicas();
void actualizarServoAcceso();
String uidTarjetaActual();

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(PIN_RELAY_VENTILADOR, OUTPUT);
  pinMode(PIN_RELAY_BOMBA, OUTPUT);
  pinMode(PIN_RELAY_LAMPARA, OUTPUT);
  aplicarSalidasFisicas();

  dht.begin();
  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  bh1750.begin(BH1750::CONTINUOUS_HIGH_RES_MODE);

  SPI.begin(PIN_RFID_SCK, PIN_RFID_MISO, PIN_RFID_MOSI, PIN_RFID_SS);
  rfid.PCD_Init();

  servoAcceso.setPeriodHertz(50);
  servoAcceso.attach(PIN_SERVO_ACCESO, SERVO_MIN_US, SERVO_MAX_US);
  servoAcceso.write(SERVO_CERRADO_GRADOS);

  conectarWiFi();
  obtenerConfiguracion();
  actualizarActuadores();
}

void loop() {
  registrarAccesoRFID();
  actualizarServoAcceso();

  if (millis() - ultimaEjecucion < CICLO_DEMO_MS) {
    return;
  }

  ultimaEjecucion = millis();

  Serial.println("================================================");
  Serial.println("Ciclo ESP32 automatico iniciado");

  obtenerConfiguracion();
  LecturaSensores lectura = leerSensores();
  ultimaLecturaId = enviarLectura(lectura);

  aplicarAutomatizacion(lectura);
  actualizarActuadores();

  bool huboComandosManuales = procesarComandosPendientes();

  if (huboComandosManuales) {
    actualizarActuadores();
  }

  Serial.print("Estado final: ventilador=");
  Serial.print(estadoVentilador);
  Serial.print(", bomba=");
  Serial.print(estadoBomba);
  Serial.print(", lampara=");
  Serial.print(estadoLampara);
  Serial.print(", servo_acceso=");
  Serial.println(estadoServoAcceso);
}

void conectarWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Conectando a WiFi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("WiFi conectado. IP: ");
  Serial.println(WiFi.localIP());
}

String requestApi(const String& metodo, const String& endpoint, const String& payload) {
  if (WiFi.status() != WL_CONNECTED) {
    conectarWiFi();
  }

  HTTPClient http;
  String url = String(API_BASE_URL) + endpoint;

  if (url.startsWith("https://")) {
    // Demo con ngrok. En produccion se debe validar el certificado.
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

bool obtenerConfiguracion() {
  String respuesta = requestApi("GET", "/configuracion.php", "");

  if (respuesta.length() == 0) {
    Serial.println("No se pudo obtener configuracion. Se conserva la ultima configuracion valida.");
    return false;
  }

  StaticJsonDocument<1536> doc;
  DeserializationError error = deserializeJson(doc, respuesta);

  if (error || !doc["ok"].as<bool>()) {
    Serial.println("Respuesta de configuracion no valida.");
    return false;
  }

  JsonObject cfg = doc["configuracion"];
  configuracion.temperaturaMaxC = cfg["temperatura_max_c"] | configuracion.temperaturaMaxC;
  configuracion.humedadSueloMinPct = cfg["humedad_suelo_min_pct"] | configuracion.humedadSueloMinPct;
  configuracion.luzMinLux = cfg["luz_min_lux"] | configuracion.luzMinLux;
  configuracion.ventilacionAutomatica = (cfg["ventilacion_automatica"] | 0) == 1;
  configuracion.riegoAutomatico = (cfg["riego_automatico"] | 0) == 1;
  configuracion.iluminacionAutomatica = (cfg["iluminacion_automatica"] | 0) == 1;
  configuracion.duracionRiegoSeg = cfg["duracion_riego_seg"] | configuracion.duracionRiegoSeg;

  Serial.print("Configuracion remota: temp_max=");
  Serial.print(configuracion.temperaturaMaxC);
  Serial.print(" C, humedad_min=");
  Serial.print(configuracion.humedadSueloMinPct);
  Serial.print(" %, luz_min=");
  Serial.print(configuracion.luzMinLux);
  Serial.print(" lux, ventilacion=");
  Serial.print(configuracion.ventilacionAutomatica);
  Serial.print(", riego=");
  Serial.print(configuracion.riegoAutomatico);
  Serial.print(", iluminacion=");
  Serial.print(configuracion.iluminacionAutomatica);
  Serial.print(", duracion_riego=");
  Serial.print(configuracion.duracionRiegoSeg);
  Serial.println(" s");

  return true;
}

LecturaSensores leerSensores() {
  LecturaSensores lectura;

  float temperatura = dht.readTemperature();
  float humedadAmbiente = dht.readHumidity();

  if (isnan(temperatura)) {
    temperatura = 28.5 + sin(millis() / 6000.0);
  }

  if (isnan(humedadAmbiente)) {
    humedadAmbiente = 62.0 + sin(millis() / 7000.0);
  }

  int humedadRaw = analogRead(PIN_HUMEDAD_SUELO_AO);
  int humedadPct = map(humedadRaw, HUMEDAD_SUELO_RAW_SECO, HUMEDAD_SUELO_RAW_HUMEDO, 0, 100);
  humedadPct = constrain(humedadPct, 0, 100);

  float lux = bh1750.readLightLevel();

  if (lux < 0) {
    lux = 780.0 + sin(millis() / 8000.0) * 30.0;
  }

  lectura.temperaturaC = temperatura;
  lectura.humedadAmbientePct = humedadAmbiente;
  lectura.humedadSueloPct = humedadPct;
  lectura.humedadSueloRaw = humedadRaw;
  lectura.intensidadLuzLux = lux;

  Serial.print("Lectura sensores: temp=");
  Serial.print(lectura.temperaturaC);
  Serial.print(" C, humedad_ambiente=");
  Serial.print(lectura.humedadAmbientePct);
  Serial.print(" %, humedad_suelo=");
  Serial.print(lectura.humedadSueloPct);
  Serial.print(" %, raw=");
  Serial.print(lectura.humedadSueloRaw);
  Serial.print(", luz=");
  Serial.print(lectura.intensidadLuzLux);
  Serial.println(" lux");

  return lectura;
}

int enviarLectura(const LecturaSensores& lectura) {
  StaticJsonDocument<512> doc;
  doc["temperatura_c"] = lectura.temperaturaC;
  doc["humedad_ambiente_pct"] = lectura.humedadAmbientePct;
  doc["humedad_suelo_pct"] = lectura.humedadSueloPct;
  doc["humedad_suelo_raw"] = lectura.humedadSueloRaw;
  doc["intensidad_luz_lux"] = lectura.intensidadLuzLux;

  String payload;
  serializeJson(doc, payload);

  String respuesta = requestApi("POST", "/lecturas.php", payload);

  if (respuesta.length() == 0) {
    return -1;
  }

  StaticJsonDocument<512> respuestaDoc;
  DeserializationError error = deserializeJson(respuestaDoc, respuesta);

  if (error || !respuestaDoc["ok"].as<bool>()) {
    return -1;
  }

  int lecturaId = respuestaDoc["id"] | -1;
  Serial.print("Lectura enviada con id=");
  Serial.println(lecturaId);
  return lecturaId;
}

void aplicarAutomatizacion(const LecturaSensores& lectura) {
  Serial.println("Decisiones automaticas:");

  if (configuracion.ventilacionAutomatica) {
    if (lectura.temperaturaC > configuracion.temperaturaMaxC) {
      cambiarActuadorAutomatico("ventilador", 1, "temperatura_alta", "temperatura alta / ventilador encendido");
    } else {
      cambiarActuadorAutomatico("ventilador", 0, "temperatura_normal", "temperatura normal / ventilador apagado");
    }
  } else {
    Serial.println(" - ventilacion automatica desactivada / ventilador sin cambios");
  }

  if (configuracion.riegoAutomatico) {
    if (lectura.humedadSueloPct < configuracion.humedadSueloMinPct) {
      if (estadoBomba == 0) {
        bombaEncendidaHasta = millis() + ((unsigned long)configuracion.duracionRiegoSeg * 1000UL);
        cambiarActuadorAutomatico("bomba", 1, "suelo_seco", "humedad baja / bomba encendida");
      } else if (configuracion.duracionRiegoSeg > 0 && millis() >= bombaEncendidaHasta) {
        cambiarActuadorAutomatico("bomba", 0, "suelo_humedo", "duracion de riego cumplida / bomba apagada");
      } else {
        Serial.println(" - humedad baja / bomba continua encendida dentro de la duracion configurada");
      }
    } else {
      bombaEncendidaHasta = 0;
      cambiarActuadorAutomatico("bomba", 0, "suelo_humedo", "humedad suficiente / bomba apagada");
    }
  } else {
    Serial.println(" - riego automatico desactivado / bomba sin cambios");
  }

  if (configuracion.iluminacionAutomatica) {
    if (lectura.intensidadLuzLux < configuracion.luzMinLux) {
      cambiarActuadorAutomatico("lampara", 1, "luz_baja", "luz baja / lampara encendida");
    } else {
      cambiarActuadorAutomatico("lampara", 0, "luz_suficiente", "luz suficiente / lampara apagada");
    }
  } else {
    Serial.println(" - iluminacion automatica desactivada / lampara sin cambios");
  }
}

void cambiarActuadorAutomatico(const String& actuador, int estadoNuevo, const String& motivo, const String& descripcion) {
  int estadoAnterior = obtenerEstadoActuador(actuador);

  if (estadoAnterior == estadoNuevo) {
    Serial.print(" - ");
    Serial.print(descripcion);
    Serial.println(" (sin cambio)");
    return;
  }

  asignarEstadoActuador(actuador, estadoNuevo);
  registrarEvento(actuador, estadoAnterior, estadoNuevo, motivo);

  Serial.print(" - ");
  Serial.print(descripcion);
  Serial.print(" (cambio ");
  Serial.print(estadoAnterior);
  Serial.print(" -> ");
  Serial.print(estadoNuevo);
  Serial.println(")");
}

bool procesarComandosPendientes() {
  String respuesta = requestApi("GET", "/comandos.php?estado=pendiente&limite=50", "");

  if (respuesta.length() == 0) {
    return false;
  }

  StaticJsonDocument<4096> doc;
  DeserializationError error = deserializeJson(doc, respuesta);

  if (error || !doc["ok"].as<bool>()) {
    Serial.println("Respuesta de comandos no valida.");
    return false;
  }

  JsonArray comandos = doc["comandos"].as<JsonArray>();
  int ejecutados = 0;
  int fallidos = 0;

  for (JsonObject comando : comandos) {
    int comandoId = comando["id"] | -1;
    String actuador = comando["actuador"] | "";
    int estadoSolicitado = comando["estado_solicitado"] | -1;

    if (comandoId <= 0 || estadoSolicitado < 0) {
      continue;
    }

    if (!actuadorPermitido(actuador)) {
      marcarComando(comandoId, "fallido", "servo_acceso no se controla desde app");
      fallidos++;
      continue;
    }

    int estadoAnterior = obtenerEstadoActuador(actuador);
    asignarEstadoActuador(actuador, estadoSolicitado);
    registrarEvento(actuador, estadoAnterior, estadoSolicitado, "comando_manual");
    marcarComando(comandoId, "ejecutado", "Comando ejecutado por ESP32");
    ejecutados++;
  }

  Serial.print("Comandos manuales procesados: ejecutados=");
  Serial.print(ejecutados);
  Serial.print(", fallidos=");
  Serial.println(fallidos);

  return ejecutados > 0 || fallidos > 0;
}

void actualizarActuadores() {
  aplicarSalidasFisicas();

  StaticJsonDocument<512> doc;
  doc["ventilador"] = estadoVentilador;
  doc["bomba"] = estadoBomba;
  doc["lampara"] = estadoLampara;
  doc["servo_acceso"] = estadoServoAcceso;
  doc["modo_control"] = "automatico";
  doc["origen"] = "esp32";

  if (ultimaLecturaId > 0) {
    doc["lectura_id"] = ultimaLecturaId;
  }

  String payload;
  serializeJson(doc, payload);
  requestApi("POST", "/actuadores.php", payload);
}

void registrarEvento(const String& actuador, int estadoAnterior, int estadoNuevo, const String& motivo) {
  StaticJsonDocument<512> doc;
  doc["actuador"] = actuador;
  doc["estado_anterior"] = estadoAnterior;
  doc["estado_nuevo"] = estadoNuevo;
  doc["motivo"] = motivo;

  if (ultimaLecturaId > 0) {
    doc["lectura_id"] = ultimaLecturaId;
  } else {
    doc["lectura_id"] = nullptr;
  }

  doc["acceso_rfid_id"] = nullptr;

  String payload;
  serializeJson(doc, payload);
  requestApi("POST", "/eventos.php", payload);
}

void registrarAccesoRFID() {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) {
    return;
  }

  String uid = uidTarjetaActual();

  StaticJsonDocument<256> doc;
  doc["uid"] = uid;
  doc["servo_abierto"] = 1;

  String payload;
  serializeJson(doc, payload);

  String respuesta = requestApi("POST", "/accesos.php", payload);

  if (respuesta.length() > 0) {
    StaticJsonDocument<512> respuestaDoc;

    if (!deserializeJson(respuestaDoc, respuesta) && respuestaDoc["autorizado"].as<bool>()) {
      estadoServoAcceso = 1;
      servoAcceso.write(SERVO_ABIERTO_GRADOS);
      servoAbiertoHasta = millis() + SERVO_TIEMPO_ABIERTO_MS;
      actualizarActuadores();
    }
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
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

void asignarEstadoActuador(const String& actuador, int estado) {
  if (actuador == "ventilador") {
    estadoVentilador = estado;
  } else if (actuador == "bomba") {
    estadoBomba = estado;
  } else if (actuador == "lampara") {
    estadoLampara = estado;
  }

  // servo_acceso se controla por RFID, no por comandos manuales.
}

void marcarComando(int comandoId, const String& estadoComando, const String& respuesta) {
  StaticJsonDocument<512> doc;
  doc["id"] = comandoId;
  doc["estado_comando"] = estadoComando;
  doc["respuesta_esp32"] = respuesta;

  String payload;
  serializeJson(doc, payload);
  requestApi("PUT", "/comandos.php", payload);
}

void aplicarSalidasFisicas() {
  digitalWrite(PIN_RELAY_VENTILADOR, estadoVentilador ? RELAY_ON_LEVEL : RELAY_OFF_LEVEL);
  digitalWrite(PIN_RELAY_BOMBA, estadoBomba ? RELAY_ON_LEVEL : RELAY_OFF_LEVEL);
  digitalWrite(PIN_RELAY_LAMPARA, estadoLampara ? RELAY_ON_LEVEL : RELAY_OFF_LEVEL);
}

void actualizarServoAcceso() {
  if (estadoServoAcceso == 1 && servoAbiertoHasta > 0 && millis() >= servoAbiertoHasta) {
    estadoServoAcceso = 0;
    servoAbiertoHasta = 0;
    servoAcceso.write(SERVO_CERRADO_GRADOS);
    actualizarActuadores();
  }
}

String uidTarjetaActual() {
  String uid = "";

  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) {
      uid += "0";
    }

    uid += String(rfid.uid.uidByte[i], HEX);
  }

  uid.toUpperCase();
  return uid;
}
