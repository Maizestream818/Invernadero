#ifndef CONFIG_EXAMPLE_H
#define CONFIG_EXAMPLE_H

// Copia este archivo como config.h y reemplaza los placeholders locales.
// No subas config.h a Git.

// WiFi
#define WIFI_SSID "TU_SSID_WIFI"
#define WIFI_PASSWORD "TU_CONTRASENA_WIFI"

// API REST PHP. Ejemplos:
// - Local por red LAN: "http://192.168.1.50:8080/api"
// - Tunel publico: "https://TU-URL.ngrok-free.app/api"
#define API_BASE_URL "http://TU_HOST:8080/api"

// Demo: la UI oculta intervalo_lectura_seg, por eso el firmware usa 2 segundos fijos.
#define CICLO_DEMO_MS 2000UL

// DHT11
#define PIN_DHT 4
#define DHT_SENSOR_TYPE DHT11

// YL-69 humedad de suelo
#define PIN_HUMEDAD_SUELO_AO 34
#define HUMEDAD_SUELO_RAW_SECO 4095
#define HUMEDAD_SUELO_RAW_HUMEDO 1200

// BH1750 por I2C
#define PIN_I2C_SDA 21
#define PIN_I2C_SCL 22

// RFID RC522 por SPI
#define PIN_RFID_SS 5
#define PIN_RFID_SCK 18
#define PIN_RFID_MOSI 23
#define PIN_RFID_MISO 19
#define PIN_RFID_RST 27

// Servo de acceso
#define PIN_SERVO_ACCESO 13
#define SERVO_CERRADO_GRADOS 0
#define SERVO_ABIERTO_GRADOS 90
#define SERVO_TIEMPO_ABIERTO_MS 3000UL
#define SERVO_MIN_US 500
#define SERVO_MAX_US 2400

// Actuadores mediante relay, MOSFET o driver
#define PIN_RELAY_VENTILADOR 25
#define PIN_RELAY_BOMBA 26
#define PIN_RELAY_LAMPARA 33

// Ajusta estos niveles segun el modulo usado.
// Muchos modulos relay son activos en LOW.
#define RELAY_ON_LEVEL HIGH
#define RELAY_OFF_LEVEL LOW

#endif
