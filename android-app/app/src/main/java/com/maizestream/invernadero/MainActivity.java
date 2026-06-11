package com.maizestream.invernadero;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.app.Activity;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity {
    private static final String DEFAULT_API_BASE_URL = "https://irregular-mothball-flyover.ngrok-free.dev/api";
    private static final String PREFS_NAME = "invernadero_prefs";
    private static final String PREF_API_BASE_URL = "api_base_url";

    private EditText etApiBaseUrl;
    private TextView tvEstadoApi;
    private TextView tvUltimaActualizacion;
    private TextView tvSensores;
    private TextView tvActuadores;
    private TextView tvConfiguracion;
    private TextView tvAccesos;
    private TextView tvComandos;
    private TextView tvControlMensaje;
    private SharedPreferences preferences;
    private ExecutorService executorService;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        preferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        executorService = Executors.newSingleThreadExecutor();

        etApiBaseUrl = findViewById(R.id.etApiBaseUrl);
        tvEstadoApi = findViewById(R.id.tvEstadoApi);
        tvUltimaActualizacion = findViewById(R.id.tvUltimaActualizacion);
        tvSensores = findViewById(R.id.tvSensores);
        tvActuadores = findViewById(R.id.tvActuadores);
        tvConfiguracion = findViewById(R.id.tvConfiguracion);
        tvAccesos = findViewById(R.id.tvAccesos);
        tvComandos = findViewById(R.id.tvComandos);
        tvControlMensaje = findViewById(R.id.tvControlMensaje);
        Button btnGuardarUrl = findViewById(R.id.btnGuardarUrl);
        Button btnProbarConexion = findViewById(R.id.btnProbarConexion);
        Button btnActualizarDatos = findViewById(R.id.btnActualizarDatos);
        Button btnVentiladorEncender = findViewById(R.id.btnVentiladorEncender);
        Button btnVentiladorApagar = findViewById(R.id.btnVentiladorApagar);
        Button btnBombaEncender = findViewById(R.id.btnBombaEncender);
        Button btnBombaApagar = findViewById(R.id.btnBombaApagar);
        Button btnLamparaEncender = findViewById(R.id.btnLamparaEncender);
        Button btnLamparaApagar = findViewById(R.id.btnLamparaApagar);

        etApiBaseUrl.setText(obtenerApiBaseUrl());

        btnGuardarUrl.setOnClickListener(view -> guardarUrlBase());
        btnProbarConexion.setOnClickListener(view -> probarConexion());
        btnActualizarDatos.setOnClickListener(view -> cargarTodosLosDatos());
        btnVentiladorEncender.setOnClickListener(view -> crearComando("ventilador", 1));
        btnVentiladorApagar.setOnClickListener(view -> crearComando("ventilador", 0));
        btnBombaEncender.setOnClickListener(view -> crearComando("bomba", 1));
        btnBombaApagar.setOnClickListener(view -> crearComando("bomba", 0));
        btnLamparaEncender.setOnClickListener(view -> crearComando("lampara", 1));
        btnLamparaApagar.setOnClickListener(view -> crearComando("lampara", 0));
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();

        if (executorService != null) {
            executorService.shutdown();
        }
    }

    private String obtenerApiBaseUrl() {
        return preferences.getString(PREF_API_BASE_URL, DEFAULT_API_BASE_URL);
    }

    private ApiClient crearApiClient(String apiBaseUrl) {
        return new ApiClient(apiBaseUrl);
    }

    private void guardarUrlBase() {
        String apiBaseUrl = etApiBaseUrl.getText().toString().trim();

        if (apiBaseUrl.isEmpty()) {
            apiBaseUrl = DEFAULT_API_BASE_URL;
            etApiBaseUrl.setText(apiBaseUrl);
        }

        preferences.edit().putString(PREF_API_BASE_URL, apiBaseUrl).apply();
        aplicarEstadoAdvertencia();
        tvEstadoApi.setText("URL guardada: " + apiBaseUrl);
    }

    private void probarConexion() {
        guardarUrlBase();
        String apiBaseUrl = etApiBaseUrl.getText().toString().trim();
        aplicarEstadoAdvertencia();
        tvEstadoApi.setText("Probando conexion...");

        executorService.execute(() -> {
            try {
                JSONObject status = crearApiClient(apiBaseUrl).getJson("/status.php");
                boolean ok = status.optBoolean("ok", false);
                String servicio = status.optString("servicio", "Sin servicio");
                String baseDatos = status.optString("base_datos", "Sin base de datos");
                String mensaje = ok
                        ? "API conectada\nServicio: " + servicio + "\nBase de datos: " + baseDatos
                        : "API no disponible";

                runOnUiThread(() -> {
                    if (ok) {
                        aplicarEstadoExito();
                    } else {
                        aplicarEstadoError();
                    }
                    tvEstadoApi.setText(mensaje);
                    actualizarHora();
                });
            } catch (Exception e) {
                mostrarError("API no disponible: " + e.getMessage());
            }
        });
    }

    private void cargarTodosLosDatos() {
        guardarUrlBase();
        String apiBaseUrl = etApiBaseUrl.getText().toString().trim();
        aplicarEstadoAdvertencia();
        tvEstadoApi.setText("Actualizando datos...");

        executorService.execute(() -> {
            ApiClient apiClient = crearApiClient(apiBaseUrl);
            String estadoApi = cargarEstadoApi(apiClient);
            String sensores = cargarSensores(apiClient);
            String actuadores = cargarActuadores(apiClient);
            String configuracion = cargarConfiguracion(apiClient);
            String accesos = cargarAccesos(apiClient);
            String comandos = cargarComandos(apiClient);

            runOnUiThread(() -> {
                if (estadoApi.startsWith("API conectada")) {
                    aplicarEstadoExito();
                } else {
                    aplicarEstadoError();
                }
                tvEstadoApi.setText(estadoApi);
                tvSensores.setText(sensores);
                tvActuadores.setText(actuadores);
                tvConfiguracion.setText(configuracion);
                tvAccesos.setText(accesos);
                tvComandos.setText(comandos);
                actualizarHora();
            });
        });
    }

    private String cargarEstadoApi(ApiClient apiClient) {
        try {
            JSONObject status = apiClient.getJson("/status.php");

            if (!status.optBoolean("ok", false)) {
                return "API no disponible";
            }

            return "API conectada"
                    + "\nServicio: " + valor(status, "servicio")
                    + "\nBase de datos: " + valor(status, "base_datos");
        } catch (Exception e) {
            return "API no disponible: " + e.getMessage();
        }
    }

    private String cargarSensores(ApiClient apiClient) {
        try {
            JSONObject response = apiClient.getJson("/lecturas.php?limite=1");
            JSONArray lecturas = response.optJSONArray("lecturas");

            if (lecturas == null || lecturas.length() == 0) {
                return "Sin datos";
            }

            JSONObject lectura = lecturas.getJSONObject(0);

            return "Temperatura: " + valor(lectura, "temperatura_c") + " \u00B0C"
                    + "\nHumedad ambiental: " + valor(lectura, "humedad_ambiente_pct") + " %"
                    + "\nHumedad del suelo: " + valor(lectura, "humedad_suelo_pct") + " %"
                    + "\nHumedad suelo raw: " + valor(lectura, "humedad_suelo_raw")
                    + "\nIntensidad de luz: " + valor(lectura, "intensidad_luz_lux") + " lux"
                    + "\nFecha: " + valor(lectura, "fecha");
        } catch (Exception e) {
            return "Error al cargar sensores: " + e.getMessage();
        }
    }

    private String cargarActuadores(ApiClient apiClient) {
        try {
            JSONObject response = apiClient.getJson("/actuadores.php");
            JSONObject estado = response.optJSONObject("estado");

            if (estado == null) {
                return "Sin datos";
            }

            return "Ventilador: " + binario(estado.optInt("ventilador", 0), "encendido", "apagado")
                    + "\nBomba: " + binario(estado.optInt("bomba", 0), "encendida", "apagada")
                    + "\nLampara: " + binario(estado.optInt("lampara", 0), "encendida", "apagada")
                    + "\nServo: " + binario(estado.optInt("servo_acceso", 0), "abierto", "cerrado")
                    + "\nModo de control: " + valor(estado, "modo_control")
                    + "\nOrigen: " + valor(estado, "origen")
                    + "\nFecha: " + valor(estado, "fecha");
        } catch (Exception e) {
            return "Error al cargar actuadores: " + e.getMessage();
        }
    }

    private String cargarConfiguracion(ApiClient apiClient) {
        try {
            JSONObject response = apiClient.getJson("/configuracion.php");
            JSONObject configuracion = response.optJSONObject("configuracion");

            if (configuracion == null) {
                return "Sin datos";
            }

            return "Temperatura maxima: " + valor(configuracion, "temperatura_max_c") + " \u00B0C"
                    + "\nHumedad minima de suelo: " + valor(configuracion, "humedad_suelo_min_pct") + " %"
                    + "\nLuz minima: " + valor(configuracion, "luz_min_lux") + " lux"
                    + "\nVentilacion automatica: " + activo(configuracion.optInt("ventilacion_automatica", 0))
                    + "\nRiego automatico: " + activo(configuracion.optInt("riego_automatico", 0))
                    + "\nIluminacion automatica: " + activo(configuracion.optInt("iluminacion_automatica", 0))
                    + "\nDuracion de riego: " + valor(configuracion, "duracion_riego_seg") + " s"
                    + "\nIntervalo de lectura: " + valor(configuracion, "intervalo_lectura_seg") + " s";
        } catch (Exception e) {
            return "Error al cargar configuracion: " + e.getMessage();
        }
    }

    private String cargarAccesos(ApiClient apiClient) {
        try {
            JSONObject response = apiClient.getJson("/accesos.php?limite=5");
            JSONArray accesos = response.optJSONArray("accesos");

            if (accesos == null || accesos.length() == 0) {
                return "Sin datos";
            }

            StringBuilder builder = new StringBuilder();

            for (int i = 0; i < accesos.length(); i++) {
                JSONObject acceso = accesos.getJSONObject(i);

                if (i > 0) {
                    builder.append("\n\n");
                }

                builder.append("UID: ").append(valor(acceso, "uid"))
                        .append("\nUsuario: ").append(valor(acceso, "nombre_usuario"))
                        .append("\nAcceso: ").append(acceso.optInt("autorizado", 0) == 1 ? "autorizado" : "rechazado")
                        .append("\nServo: ").append(binario(acceso.optInt("servo_abierto", 0), "abierto", "cerrado"))
                        .append("\nFecha: ").append(valor(acceso, "fecha"));
            }

            return builder.toString();
        } catch (Exception e) {
            return "Error al cargar accesos RFID: " + e.getMessage();
        }
    }

    private String cargarComandos(ApiClient apiClient) {
        try {
            JSONObject response = apiClient.getJson("/comandos.php?limite=5");
            JSONArray comandos = response.optJSONArray("comandos");

            if (comandos == null || comandos.length() == 0) {
                return "Sin datos";
            }

            StringBuilder builder = new StringBuilder();

            for (int i = 0; i < comandos.length(); i++) {
                JSONObject comando = comandos.getJSONObject(i);

                if (i > 0) {
                    builder.append("\n\n");
                }

                builder.append("Actuador: ").append(valor(comando, "actuador"))
                        .append("\nEstado solicitado: ").append(binario(comando.optInt("estado_solicitado", 0), "encendido", "apagado"))
                        .append("\nOrigen: ").append(valor(comando, "origen"))
                        .append("\nEstado del comando: ").append(valor(comando, "estado_comando"))
                        .append("\nFecha de creacion: ").append(valor(comando, "fecha_creacion"));
            }

            return builder.toString();
        } catch (Exception e) {
            return "Error al cargar comandos: " + e.getMessage();
        }
    }

    private void crearComando(String actuador, int estadoSolicitado) {
        if (!esActuadorControlPermitido(actuador)) {
            mostrarErrorControl("Actuador no permitido desde la app");
            return;
        }

        if (estadoSolicitado != 0 && estadoSolicitado != 1) {
            mostrarErrorControl("Estado solicitado invalido");
            return;
        }

        guardarUrlBase();
        String apiBaseUrl = etApiBaseUrl.getText().toString().trim();
        aplicarControlAdvertencia();
        tvControlMensaje.setText("Creando comando pendiente...");

        executorService.execute(() -> {
            try {
                ApiClient apiClient = crearApiClient(apiBaseUrl);
                JSONObject body = new JSONObject();
                body.put("actuador", actuador);
                body.put("estado_solicitado", estadoSolicitado);
                body.put("origen", "app");

                JSONObject response = apiClient.postJson("/comandos.php", body);
                boolean ok = response.optBoolean("ok", false);
                String mensaje = response.optString("mensaje", "Comando creado correctamente");

                if (!ok) {
                    throw new Exception(mensaje);
                }

                String comandos = cargarComandos(apiClient);

                runOnUiThread(() -> {
                    aplicarControlExito();
                    tvControlMensaje.setText(mensaje);
                    tvComandos.setText(comandos);
                    actualizarHora();
                });
            } catch (Exception e) {
                mostrarErrorControl("Error al crear comando: " + e.getMessage());
            }
        });
    }

    private void mostrarError(String mensaje) {
        runOnUiThread(() -> {
            aplicarEstadoError();
            tvEstadoApi.setText(mensaje);
            actualizarHora();
        });
    }

    private void mostrarErrorControl(String mensaje) {
        runOnUiThread(() -> {
            aplicarControlError();
            tvControlMensaje.setText(mensaje);
            actualizarHora();
        });
    }

    private void aplicarEstadoExito() {
        tvEstadoApi.setBackgroundResource(R.drawable.bg_status_success);
        tvEstadoApi.setTextColor(getResources().getColor(R.color.color_success));
    }

    private void aplicarEstadoError() {
        tvEstadoApi.setBackgroundResource(R.drawable.bg_status_error);
        tvEstadoApi.setTextColor(getResources().getColor(R.color.color_error));
    }

    private void aplicarEstadoAdvertencia() {
        tvEstadoApi.setBackgroundResource(R.drawable.bg_status_warning);
        tvEstadoApi.setTextColor(getResources().getColor(R.color.color_warning));
    }

    private void aplicarControlExito() {
        tvControlMensaje.setBackgroundResource(R.drawable.bg_status_success);
        tvControlMensaje.setTextColor(getResources().getColor(R.color.color_success));
    }

    private void aplicarControlError() {
        tvControlMensaje.setBackgroundResource(R.drawable.bg_status_error);
        tvControlMensaje.setTextColor(getResources().getColor(R.color.color_error));
    }

    private void aplicarControlAdvertencia() {
        tvControlMensaje.setBackgroundResource(R.drawable.bg_status_warning);
        tvControlMensaje.setTextColor(getResources().getColor(R.color.color_warning));
    }

    private void actualizarHora() {
        String ahora = new SimpleDateFormat("dd/MM/yyyy HH:mm:ss", Locale.getDefault()).format(new Date());
        tvUltimaActualizacion.setText("Ultima actualizacion: " + ahora);
    }

    private String valor(JSONObject object, String key) {
        if (object == null || !object.has(key) || object.isNull(key)) {
            return "Sin datos";
        }

        return object.optString(key, "Sin datos");
    }

    private String binario(int value, String textoActivo, String textoInactivo) {
        return value == 1 ? textoActivo : textoInactivo;
    }

    private String activo(int value) {
        return value == 1 ? "activa" : "inactiva";
    }

    private boolean esActuadorControlPermitido(String actuador) {
        return "ventilador".equals(actuador)
                || "bomba".equals(actuador)
                || "lampara".equals(actuador);
    }
}
