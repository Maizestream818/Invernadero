package com.maizestream.invernadero;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.view.View;
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
    private static final long AUTO_REFRESH_INTERVAL_MS = 2000L;

    private EditText etApiBaseUrl;
    private TextView tvEstadoApi;
    private TextView tvUltimaActualizacion;
    private TextView txtSensorTemperatura;
    private TextView txtSensorHumedadAmbiente;
    private TextView txtSensorHumedadSuelo;
    private TextView txtSensorHumedadRaw;
    private TextView txtSensorLuz;
    private TextView txtActVentilador;
    private TextView txtActBomba;
    private TextView txtActLampara;
    private TextView txtActServo;
    private TextView txtEstadoBombaControl;
    private TextView txtEstadoVentiladorControl;
    private TextView txtEstadoLamparaControl;
    private TextView tvConfigTempMax;
    private TextView tvConfigHumedadMin;
    private TextView tvConfigLuzMin;
    private TextView tvConfigVentilacion;
    private TextView tvConfigRiego;
    private TextView tvConfigIluminacion;
    private TextView tvConfigDuracionRiego;
    private TextView tvAccesos;
    private TextView tvComandos;
    private TextView tvComandosPendientes;
    private View cardActBomba;
    private View cardActVentilador;
    private View cardActLampara;
    private SharedPreferences preferences;
    private ExecutorService executorService;
    private Handler autoRefreshHandler;
    private Runnable autoRefreshRunnable;
    private boolean isRefreshing = false;
    private Integer estadoActualBomba = null;
    private Integer estadoActualVentilador = null;
    private Integer estadoActualLampara = null;
    private boolean hayComandoPendienteBomba = false;
    private boolean hayComandoPendienteVentilador = false;
    private boolean hayComandoPendienteLampara = false;
    private JSONObject configuracionActual = null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        preferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        executorService = Executors.newSingleThreadExecutor();
        autoRefreshHandler = new Handler(Looper.getMainLooper());

        etApiBaseUrl = findViewById(R.id.etApiBaseUrl);
        tvEstadoApi = findViewById(R.id.tvEstadoApi);
        tvUltimaActualizacion = findViewById(R.id.tvUltimaActualizacion);
        txtSensorTemperatura = findViewById(R.id.txtSensorTemperatura);
        txtSensorHumedadAmbiente = findViewById(R.id.txtSensorHumedadAmbiente);
        txtSensorHumedadSuelo = findViewById(R.id.txtSensorHumedadSuelo);
        txtSensorHumedadRaw = findViewById(R.id.txtSensorHumedadRaw);
        txtSensorLuz = findViewById(R.id.txtSensorLuz);
        txtActVentilador = findViewById(R.id.txtActVentilador);
        txtActBomba = findViewById(R.id.txtActBomba);
        txtActLampara = findViewById(R.id.txtActLampara);
        txtActServo = findViewById(R.id.txtActServo);
        txtEstadoBombaControl = findViewById(R.id.txtEstadoBombaControl);
        txtEstadoVentiladorControl = findViewById(R.id.txtEstadoVentiladorControl);
        txtEstadoLamparaControl = findViewById(R.id.txtEstadoLamparaControl);
        tvConfigTempMax = findViewById(R.id.tvConfigTempMax);
        tvConfigHumedadMin = findViewById(R.id.tvConfigHumedadMin);
        tvConfigLuzMin = findViewById(R.id.tvConfigLuzMin);
        tvConfigVentilacion = findViewById(R.id.tvConfigVentilacion);
        tvConfigRiego = findViewById(R.id.tvConfigRiego);
        tvConfigIluminacion = findViewById(R.id.tvConfigIluminacion);
        tvConfigDuracionRiego = findViewById(R.id.tvConfigDuracionRiego);
        tvAccesos = findViewById(R.id.tvAccesos);
        tvComandos = findViewById(R.id.tvComandos);
        tvComandosPendientes = findViewById(R.id.tvComandosPendientes);
        Button btnProbarConexion = findViewById(R.id.btnProbarConexion);
        cardActBomba = findViewById(R.id.cardActBomba);
        cardActVentilador = findViewById(R.id.cardActVentilador);
        cardActLampara = findViewById(R.id.cardActLampara);

        etApiBaseUrl.setText(obtenerApiBaseUrl());
        etApiBaseUrl.setOnFocusChangeListener((view, hasFocus) -> {
            if (!hasFocus) {
                guardarUrlSiEsNecesario();
            }
        });

        btnProbarConexion.setOnClickListener(view -> probarConexion());
        cardActBomba.setOnClickListener(view -> crearComandoSegunEstado("bomba"));
        cardActVentilador.setOnClickListener(view -> crearComandoSegunEstado("ventilador"));
        cardActLampara.setOnClickListener(view -> crearComandoSegunEstado("lampara"));
        configurarEdicionConfiguracion();

        autoRefreshRunnable = new Runnable() {
            @Override
            public void run() {
                actualizarDatos();
                autoRefreshHandler.postDelayed(this, AUTO_REFRESH_INTERVAL_MS);
            }
        };

        mostrarApiDesconectada();
        actualizarControlesRemotos();
    }

    @Override
    protected void onResume() {
        super.onResume();
        iniciarAutoActualizacion();
    }

    @Override
    protected void onPause() {
        detenerAutoActualizacion();
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        detenerAutoActualizacion();

        if (executorService != null) {
            executorService.shutdown();
        }

        super.onDestroy();
    }

    private String obtenerApiBaseUrl() {
        return preferences.getString(PREF_API_BASE_URL, DEFAULT_API_BASE_URL);
    }

    private ApiClient crearApiClient(String apiBaseUrl) {
        return new ApiClient(apiBaseUrl);
    }

    private String guardarUrlSiEsNecesario() {
        String apiBaseUrl = etApiBaseUrl.getText().toString().trim();

        if (apiBaseUrl.isEmpty()) {
            apiBaseUrl = DEFAULT_API_BASE_URL;
            etApiBaseUrl.setText(apiBaseUrl);
        }

        String guardada = preferences.getString(PREF_API_BASE_URL, "");

        if (!apiBaseUrl.equals(guardada)) {
            preferences.edit().putString(PREF_API_BASE_URL, apiBaseUrl).apply();
        }

        return apiBaseUrl;
    }

    private void iniciarAutoActualizacion() {
        detenerAutoActualizacion();
        actualizarDatos();
        autoRefreshHandler.postDelayed(autoRefreshRunnable, AUTO_REFRESH_INTERVAL_MS);
    }

    private void detenerAutoActualizacion() {
        if (autoRefreshHandler != null && autoRefreshRunnable != null) {
            autoRefreshHandler.removeCallbacks(autoRefreshRunnable);
        }
    }

    private void probarConexion() {
        String apiBaseUrl = guardarUrlSiEsNecesario();

        executorService.execute(() -> {
            try {
                boolean conectado = consultarEstadoApi(crearApiClient(apiBaseUrl));

                runOnUiThread(() -> {
                    if (conectado) {
                        mostrarApiConectada();
                    } else {
                        mostrarApiDesconectada();
                    }

                    actualizarHora();
                });
            } catch (Exception e) {
                runOnUiThread(() -> {
                    mostrarApiDesconectada();
                    actualizarHora();
                });
            }
        });
    }

    private void actualizarDatos() {
        if (isRefreshing) {
            return;
        }

        isRefreshing = true;
        String apiBaseUrl = guardarUrlSiEsNecesario();

        executorService.execute(() -> {
            boolean apiConectada = false;

            try {
                ApiClient apiClient = crearApiClient(apiBaseUrl);
                apiConectada = consultarEstadoApi(apiClient);
                cargarSensores(apiClient);
                cargarActuadores(apiClient);
                actualizarComandosPendientes(apiClient);

                cargarConfiguracion(apiClient);
                String accesos = cargarAccesos(apiClient);
                String comandos = cargarComandos(apiClient);
                boolean finalApiConectada = apiConectada;

                runOnUiThread(() -> {
                    if (finalApiConectada) {
                        mostrarApiConectada();
                    } else {
                        mostrarApiDesconectada();
                    }

                    tvAccesos.setText(accesos);
                    tvComandos.setText(comandos);
                    actualizarControlesRemotos();
                    actualizarHora();
                    isRefreshing = false;
                });
            } catch (Exception e) {
                runOnUiThread(() -> {
                    mostrarApiDesconectada();
                    actualizarControlesRemotos();
                    actualizarHora();
                    isRefreshing = false;
                });
            }
        });
    }

    private boolean consultarEstadoApi(ApiClient apiClient) {
        try {
            JSONObject status = apiClient.getJson("/status.php");
            return status.optBoolean("ok", false) && status.optBoolean("conexion_bd", false);
        } catch (Exception e) {
            return false;
        }
    }

    private void cargarSensores(ApiClient apiClient) {
        try {
            JSONObject response = apiClient.getJson("/lecturas.php?limite=1");
            JSONArray lecturas = response.optJSONArray("lecturas");

            if (lecturas == null || lecturas.length() == 0) {
                runOnUiThread(() -> {
                    txtSensorTemperatura.setText("Sin datos");
                    txtSensorHumedadAmbiente.setText("Sin datos");
                    txtSensorHumedadSuelo.setText("Sin datos");
                    txtSensorHumedadRaw.setText("Sin datos");
                    txtSensorLuz.setText("Sin datos");
                });
                return;
            }

            JSONObject lectura = lecturas.getJSONObject(0);
            String temperatura = valor(lectura, "temperatura_c") + " C";
            String humedadAmbiente = valor(lectura, "humedad_ambiente_pct") + " %";
            String humedadSuelo = valor(lectura, "humedad_suelo_pct") + " %";
            String humedadRaw = valor(lectura, "humedad_suelo_raw") + " raw";
            String luz = valor(lectura, "intensidad_luz_lux") + " lux";

            runOnUiThread(() -> {
                txtSensorTemperatura.setText(temperatura);
                txtSensorHumedadAmbiente.setText(humedadAmbiente);
                txtSensorHumedadSuelo.setText(humedadSuelo);
                txtSensorHumedadRaw.setText(humedadRaw);
                txtSensorLuz.setText(luz);
            });
        } catch (Exception e) {
            runOnUiThread(() -> txtSensorTemperatura.setText("Sin datos"));
        }
    }

    private void cargarActuadores(ApiClient apiClient) {
        try {
            JSONObject response = apiClient.getJson("/actuadores.php");
            JSONObject estado = response.optJSONObject("estado");

            if (estado == null) {
                estadoActualBomba = null;
                estadoActualVentilador = null;
                estadoActualLampara = null;
                runOnUiThread(() -> {
                    txtActVentilador.setText("Sin datos");
                    txtActBomba.setText("Sin datos");
                    txtActLampara.setText("Sin datos");
                    txtActServo.setText("Sin datos");
                    txtActVentilador.setTextColor(getResources().getColor(R.color.color_text));
                    txtActBomba.setTextColor(getResources().getColor(R.color.color_text));
                    txtActLampara.setTextColor(getResources().getColor(R.color.color_text));
                });
                return;
            }

            estadoActualVentilador = estado.optInt("ventilador", 0);
            estadoActualBomba = estado.optInt("bomba", 0);
            estadoActualLampara = estado.optInt("lampara", 0);
            String ventilador = binario(estadoActualVentilador, "Encendido", "Apagado");
            String bomba = binario(estadoActualBomba, "Encendido", "Apagado");
            String lampara = binario(estadoActualLampara, "Encendido", "Apagado");
            String servo = binario(estado.optInt("servo_acceso", 0), "Abierto", "Cerrado");

            runOnUiThread(() -> {
                txtActVentilador.setText(ventilador);
                txtActBomba.setText(bomba);
                txtActLampara.setText(lampara);
                txtActServo.setText(servo);
                txtActVentilador.setTextColor(getResources().getColor(estadoActualVentilador == 1 ? R.color.white : R.color.color_text));
                txtActBomba.setTextColor(getResources().getColor(estadoActualBomba == 1 ? R.color.white : R.color.color_text));
                txtActLampara.setTextColor(getResources().getColor(estadoActualLampara == 1 ? R.color.white : R.color.color_text));
            });
        } catch (Exception e) {
            estadoActualBomba = null;
            estadoActualVentilador = null;
            estadoActualLampara = null;
            runOnUiThread(() -> {
                txtActVentilador.setText("Sin datos");
                txtActBomba.setText("Sin datos");
                txtActLampara.setText("Sin datos");
                txtActVentilador.setTextColor(getResources().getColor(R.color.color_text));
                txtActBomba.setTextColor(getResources().getColor(R.color.color_text));
                txtActLampara.setTextColor(getResources().getColor(R.color.color_text));
            });
        }
    }

    private void actualizarComandosPendientes(ApiClient apiClient) {
        hayComandoPendienteBomba = hayComandoPendienteParaActuador("bomba", apiClient);
        hayComandoPendienteVentilador = hayComandoPendienteParaActuador("ventilador", apiClient);
        hayComandoPendienteLampara = hayComandoPendienteParaActuador("lampara", apiClient);
    }

    private boolean hayComandoPendienteParaActuador(String actuador, ApiClient apiClient) {
        try {
            JSONObject response = apiClient.getJson("/comandos.php?estado=pendiente&limite=100");
            JSONArray comandos = response.optJSONArray("comandos");

            if (comandos == null) {
                return false;
            }

            for (int i = 0; i < comandos.length(); i++) {
                JSONObject comando = comandos.getJSONObject(i);

                if (actuador.equals(valor(comando, "actuador"))) {
                    return true;
                }
            }
        } catch (Exception e) {
            if ("bomba".equals(actuador)) {
                return hayComandoPendienteBomba;
            }

            if ("ventilador".equals(actuador)) {
                return hayComandoPendienteVentilador;
            }

            if ("lampara".equals(actuador)) {
                return hayComandoPendienteLampara;
            }
        }

        return false;
    }

    private void cargarConfiguracion(ApiClient apiClient) {
        try {
            JSONObject response = apiClient.getJson("/configuracion.php");
            JSONObject configuracion = response.optJSONObject("configuracion");

            if (configuracion == null) {
                configuracionActual = null;
                runOnUiThread(() -> actualizarCardsConfiguracion(null));
                return;
            }

            configuracionActual = configuracion;
            runOnUiThread(() -> actualizarCardsConfiguracion(configuracion));
        } catch (Exception e) {
            runOnUiThread(() -> tvConfigTempMax.setText("Error al cargar"));
        }
    }

    private void actualizarCardsConfiguracion(JSONObject configuracion) {
        if (configuracion == null) {
            tvConfigTempMax.setText("Sin datos");
            tvConfigHumedadMin.setText("Sin datos");
            tvConfigLuzMin.setText("Sin datos");
            tvConfigVentilacion.setText("Sin datos");
            tvConfigRiego.setText("Sin datos");
            tvConfigIluminacion.setText("Sin datos");
            tvConfigDuracionRiego.setText("Sin datos");
            return;
        }

        tvConfigTempMax.setText(valor(configuracion, "temperatura_max_c") + " C");
        tvConfigHumedadMin.setText(valor(configuracion, "humedad_suelo_min_pct") + " %");
        tvConfigLuzMin.setText(valor(configuracion, "luz_min_lux") + " lux");
        tvConfigVentilacion.setText(activo(configuracion.optInt("ventilacion_automatica", 0)));
        tvConfigRiego.setText(activo(configuracion.optInt("riego_automatico", 0)));
        tvConfigIluminacion.setText(activo(configuracion.optInt("iluminacion_automatica", 0)));
        tvConfigDuracionRiego.setText(valor(configuracion, "duracion_riego_seg") + " s");
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

    private void crearComandoSegunEstado(String actuador) {
        Integer estadoActual = obtenerEstadoActual(actuador);

        if (estadoActual == null) {
            mostrarMensajeControl("Estado desconocido. Esperando estado del actuador.", false);
            actualizarControlesRemotos();
            return;
        }

        if (hayComandoPendiente(actuador)) {
            mostrarMensajeControl("Comando pendiente para " + nombreActuador(actuador), false);
            actualizarControlesRemotos();
            return;
        }

        int estadoSolicitado = estadoActual == 1 ? 0 : 1;
        crearComando(actuador, estadoSolicitado);
    }

    private void crearComando(String actuador, int estadoSolicitado) {
        if (!esActuadorControlPermitido(actuador)) {
            mostrarMensajeControl("Actuador no permitido desde la app", false);
            return;
        }

        String apiBaseUrl = guardarUrlSiEsNecesario();
        marcarPendienteLocal(actuador, true);
        actualizarControlesRemotos();
        tvComandosPendientes.setText("Esperando ejecucion de comandos");

        executorService.execute(() -> {
            try {
                ApiClient apiClient = crearApiClient(apiBaseUrl);
                JSONObject body = new JSONObject();
                body.put("actuador", actuador);
                body.put("estado_solicitado", estadoSolicitado);
                body.put("origen", "app");

                JSONObject response = apiClient.postJson("/comandos.php", body);

                if (!response.optBoolean("ok", false)) {
                    throw new Exception(response.optString("mensaje", "No se pudo crear comando"));
                }

                String comandos = cargarComandos(apiClient);

                runOnUiThread(() -> {
                    mostrarMensajeControl("Comando creado correctamente", true);
                    tvComandos.setText(comandos);
                    actualizarHora();
                    actualizarDatos();
                });
            } catch (Exception e) {
                marcarPendienteLocal(actuador, false);
                runOnUiThread(() -> {
                    mostrarMensajeControl("Error al crear comando", false);
                    actualizarControlesRemotos();
                    actualizarHora();
                });
            }
        });
    }

    private void actualizarControlesRemotos() {
        actualizarControlActuador(
                "bomba",
                estadoActualBomba,
                hayComandoPendienteBomba,
                txtEstadoBombaControl,
                cardActBomba
        );
        actualizarControlActuador(
                "ventilador",
                estadoActualVentilador,
                hayComandoPendienteVentilador,
                txtEstadoVentiladorControl,
                cardActVentilador
        );
        actualizarControlActuador(
                "lampara",
                estadoActualLampara,
                hayComandoPendienteLampara,
                txtEstadoLamparaControl,
                cardActLampara
        );
        actualizarMensajeGeneralControl();
    }

    private void actualizarControlActuador(
            String actuador,
            Integer estadoActual,
            boolean tieneComandoPendiente,
            TextView estadoView,
            View card
    ) {
        if (estadoView == null || card == null) {
            return;
        }

        if (estadoActual == null) {
            estadoView.setText("Esperando estado");
            estadoView.setTextColor(getResources().getColor(R.color.color_text));
            card.setBackgroundResource(R.drawable.bg_actuator_pending);
            card.setEnabled(false);
            card.setClickable(false);
            return;
        }

        if (tieneComandoPendiente) {
            estadoView.setText("Esperando ejecucion");
            estadoView.setTextColor(getResources().getColor(R.color.color_text));
            card.setBackgroundResource(R.drawable.bg_actuator_pending);
            card.setEnabled(false);
            card.setClickable(false);
            return;
        }

        estadoView.setText(estadoActual == 1 ? "Toca para apagar" : "Toca para encender");
        estadoView.setTextColor(getResources().getColor(estadoActual == 1 ? R.color.white : R.color.color_muted));
        card.setBackgroundResource(estadoActual == 1 ? R.drawable.bg_actuator_on : R.drawable.bg_actuator_off);
        card.setEnabled(true);
        card.setClickable(true);
    }

    private void actualizarMensajeGeneralControl() {
        boolean hayPendientes = hayComandoPendienteBomba
                || hayComandoPendienteVentilador
                || hayComandoPendienteLampara;

        if (hayPendientes) {
            tvComandosPendientes.setBackgroundResource(R.drawable.bg_status_warning);
            tvComandosPendientes.setTextColor(getResources().getColor(R.color.color_warning));
            tvComandosPendientes.setText("Comandos pendientes detectados");
            return;
        }

        tvComandosPendientes.setBackgroundResource(R.drawable.bg_status_success);
        tvComandosPendientes.setTextColor(getResources().getColor(R.color.color_success));
        tvComandosPendientes.setText("Sin comandos pendientes");
    }

    private Integer obtenerEstadoActual(String actuador) {
        if ("bomba".equals(actuador)) {
            return estadoActualBomba;
        }

        if ("ventilador".equals(actuador)) {
            return estadoActualVentilador;
        }

        if ("lampara".equals(actuador)) {
            return estadoActualLampara;
        }

        return null;
    }

    private boolean hayComandoPendiente(String actuador) {
        if ("bomba".equals(actuador)) {
            return hayComandoPendienteBomba;
        }

        if ("ventilador".equals(actuador)) {
            return hayComandoPendienteVentilador;
        }

        if ("lampara".equals(actuador)) {
            return hayComandoPendienteLampara;
        }

        return false;
    }

    private void marcarPendienteLocal(String actuador, boolean pendiente) {
        if ("bomba".equals(actuador)) {
            hayComandoPendienteBomba = pendiente;
        } else if ("ventilador".equals(actuador)) {
            hayComandoPendienteVentilador = pendiente;
        } else if ("lampara".equals(actuador)) {
            hayComandoPendienteLampara = pendiente;
        }
    }

    private String nombreActuador(String actuador) {
        if ("bomba".equals(actuador)) {
            return "bomba";
        }

        if ("ventilador".equals(actuador)) {
            return "ventilador";
        }

        if ("lampara".equals(actuador)) {
            return "lampara";
        }

        return "actuador";
    }

    private void mostrarApiConectada() {
        tvEstadoApi.setBackgroundResource(R.drawable.bg_status_success);
        tvEstadoApi.setTextColor(getResources().getColor(R.color.color_success));
        tvEstadoApi.setText("API conectada");
    }

    private void mostrarApiDesconectada() {
        tvEstadoApi.setBackgroundResource(R.drawable.bg_status_error);
        tvEstadoApi.setTextColor(getResources().getColor(R.color.color_error));
        tvEstadoApi.setText("API desconectada");
    }

    private void mostrarMensajeControl(String mensaje, boolean ok) {
        tvComandosPendientes.setBackgroundResource(ok ? R.drawable.bg_status_success : R.drawable.bg_status_warning);
        tvComandosPendientes.setTextColor(getResources().getColor(ok ? R.color.color_success : R.color.color_warning));
        tvComandosPendientes.setText(mensaje);
    }

    private void configurarEdicionConfiguracion() {
        configurarCardEditable(R.id.cardConfigTempMax, "temperatura_max_c", "Temperatura maxima");
        configurarCardEditable(R.id.cardConfigHumedadMin, "humedad_suelo_min_pct", "Humedad minima de suelo");
        configurarCardEditable(R.id.cardConfigLuzMin, "luz_min_lux", "Luz minima");
        configurarCardEditable(R.id.cardConfigVentilacion, "ventilacion_automatica", "Ventilacion automatica");
        configurarCardEditable(R.id.cardConfigRiego, "riego_automatico", "Riego automatico");
        configurarCardEditable(R.id.cardConfigIluminacion, "iluminacion_automatica", "Iluminacion automatica");
        configurarCardEditable(R.id.cardConfigDuracionRiego, "duracion_riego_seg", "Duracion de riego");
    }

    private void configurarCardEditable(int viewId, String campo, String titulo) {
        View view = findViewById(viewId);

        if (view != null) {
            view.setOnClickListener(v -> mostrarEditorConfiguracion(campo, titulo));
        }
    }

    private void mostrarEditorConfiguracion(String campo, String titulo) {
        if (configuracionActual == null) {
            return;
        }

        if (esConfiguracionBooleana(campo)) {
            mostrarSelectorBooleanoConfiguracion(campo, titulo);
            return;
        }

        EditText input = new EditText(this);
        input.setSingleLine(true);
        input.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_DECIMAL);
        input.setText(valor(configuracionActual, campo));

        new AlertDialog.Builder(this)
                .setTitle(titulo)
                .setView(input)
                .setPositiveButton("Guardar", (dialog, which) -> guardarConfiguracion(campo, input.getText().toString().trim()))
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void mostrarSelectorBooleanoConfiguracion(String campo, String titulo) {
        String[] opciones = {"Activa", "Inactiva"};
        int seleccionInicial = configuracionActual.optInt(campo, 0) == 1 ? 0 : 1;
        final int[] seleccion = {seleccionInicial};

        new AlertDialog.Builder(this)
                .setTitle(titulo)
                .setSingleChoiceItems(opciones, seleccionInicial, (dialog, which) -> seleccion[0] = which)
                .setPositiveButton("Guardar", (dialog, which) -> guardarConfiguracion(campo, seleccion[0] == 0 ? "1" : "0"))
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void guardarConfiguracion(String campo, String valorNuevo) {
        if (configuracionActual == null || valorNuevo.isEmpty()) {
            return;
        }

        String apiBaseUrl = guardarUrlSiEsNecesario();

        executorService.execute(() -> {
            try {
                JSONObject body = new JSONObject(configuracionActual.toString());
                body.put(campo, valorNuevo);
                ApiClient apiClient = crearApiClient(apiBaseUrl);
                JSONObject response = apiClient.putJson("/configuracion.php", body);

                if (!response.optBoolean("ok", false)) {
                    throw new Exception(response.optString("mensaje", "No se pudo actualizar configuracion"));
                }

                cargarConfiguracion(apiClient);
                runOnUiThread(this::actualizarHora);
            } catch (Exception e) {
                runOnUiThread(() -> tvConfigTempMax.setText("Error al guardar"));
            }
        });
    }

    private void actualizarHora() {
        String ahora = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(new Date());
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
        return value == 1 ? "Activa" : "Inactiva";
    }

    private boolean esActuadorControlPermitido(String actuador) {
        return "ventilador".equals(actuador)
                || "bomba".equals(actuador)
                || "lampara".equals(actuador);
    }

    private boolean esConfiguracionBooleana(String campo) {
        return "ventilacion_automatica".equals(campo)
                || "riego_automatico".equals(campo)
                || "iluminacion_automatica".equals(campo);
    }
}
