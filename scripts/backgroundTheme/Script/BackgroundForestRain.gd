class_name backgroundForestRain
extends Node

# Background B/N stile trap: foresta di abeti al buio in zoom infinito + pioggia + fulmini rotti.
# Parallelo a backgroundMoonWithCity: stessa API (segui_musica, fulmine, pulse, burst_colore, combo).

@export var velocita := 0.10          # zoom base (menu lento, gioco ~0.4)
@export var respiro := 0.35           # pulsazione automatica senza musica
@export var saturazione := 0.0        # 0 = bianco e nero puro
@export var effetto_schermo := true   # grana, graffi, vignettatura
@export var fulmini_auto := true      # fulmini random quando non c'è musica collegata
@export var soglia_kick := 0.7        # sopra questa soglia di basso parte un fulmine
@export var pioggia := 1.0            # intensità della pioggia (0 = niente, 1 = normale, 2 = forte)
@export var vento := 0.12             # inclinazione delle gocce
@export var layer_foresta := -2
@export var layer_fx := -1

var combo := 0                        # lo setta la scena di gioco
var viaggio := 0.0
var basso := 0.0
var flash := 0.0
var prossimo_auto := 2.0
var ultimo_fulmine := -10.0
var analizzatore: AudioEffectSpectrumAnalyzerInstance
var effetto_analisi: AudioEffectSpectrumAnalyzer
var bus_idx := -1
var mat_foresta: ShaderMaterial
var mat_fx: ShaderMaterial

const FUNZIONI := """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
"""

const SHADER_FORESTA := """
uniform float viaggio = 0.0;
uniform float basso = 0.0;
uniform float pulse = 0.0;
uniform float flash = 0.0;
uniform float seed = 1.0;
uniform float pioggia = 1.0;
uniform float vento = 0.12;

const int STRATI = 7;

// fulmine "rotto": zigzag a segmenti, con buchi e fine random
float bolt(vec2 uv, float sd, float x0) {
	float y = uv.y;
	float n = 14.0;
	float seg = floor(y * n);
	float fy = fract(y * n);
	float xa = x0 + (hash(vec2(seg, sd)) - 0.5) * 0.28;
	float xb = x0 + (hash(vec2(seg + 1.0, sd)) - 0.5) * 0.28;
	float x = mix(xa, xb, fy);
	float d = abs(uv.x - x);
	float w = 0.0015 + 0.0025 * hash(vec2(seg, sd + 3.0));
	float core = smoothstep(w, 0.0, d);
	float glow = exp(-d * 55.0) * 0.25;
	float gap = step(0.22, hash(vec2(seg, sd + 7.0)));
	float reach = 0.35 + 0.5 * hash(vec2(sd, 11.0));
	float alive = step(y, reach);
	return (core + glow) * gap * alive;
}

// un livello di pioggia: strisce verticali (inclinate dal vento) che cadono
float rain(vec2 uv, float asp, float cols, float rows, float speed, float slant, float sd, float t) {
	vec2 st = vec2(uv.x * asp + uv.y * slant, uv.y);
	float cx = floor(st.x * cols);
	float r1 = hash(vec2(cx, sd));
	float r2 = hash(vec2(cx, sd + 9.0));
	float yy = st.y * rows - t * speed * (0.8 + 0.4 * r1) + r1 * 20.0;
	float row = floor(yy);
	float v = fract(yy);
	float present = step(0.65, hash(vec2(cx + row * 13.0, sd + 3.0)));
	float fx = fract(st.x * cols);
	float dx = abs(fx - (0.25 + 0.5 * r2));
	float line = smoothstep(0.07, 0.0, dx);
	float tail = smoothstep(0.0, 0.7, v) * step(v, 0.7);
	return present * line * tail;
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float asp = res.x / res.y;
	float hor = 0.58;
	float x0 = (UV.x - 0.5) * asp;
	float y0 = hor - UV.y;

	float zoomk = 1.0 - pulse * 0.05 - basso * 0.04;
	vec2 p = vec2(x0, y0) * zoomk;

	// cielo: bagliore basso all'orizzonte + nuvole lente
	float sky = 0.04 + 0.22 * exp(-max(y0, 0.0) * 3.5) * (0.7 + basso * 0.6);
	sky += 0.07 * noise(vec2(x0 * 1.6 + TIME * 0.02, y0 * 3.0)) * smoothstep(-0.1, 0.5, y0);
	vec3 col = vec3(sky);

	// fulmini (dietro la foresta), flickerano a scatti
	float f = flash * step(0.25, hash(vec2(floor(TIME * 28.0), 5.0)));
	col += f * (0.14 + 0.12 * noise(vec2(x0 * 2.0, y0 * 3.0)));
	float b = bolt(UV, seed, 0.15 + 0.7 * hash(vec2(seed, 1.0)));
	b += 0.6 * bolt(UV, seed + 13.0, 0.15 + 0.7 * hash(vec2(seed, 2.0)));
	col += vec3(b * f * 1.3);

	// foresta in loop zoom: strati di abeti dal più lontano al più vicino
	for (int k = 0; k < STRATI; k++) {
		float t = (float(k) + fract(viaggio)) / float(STRATI);
		float id = float(k) - floor(viaggio);
		float sc = exp(mix(log(0.25), log(2.4), t));
		vec2 q = p / sc;

		// alberi: larghezza cella, posizione, altezza e presenza random
		float cols = 0.10 + 0.06 * hash(vec2(id, 3.0));
		float cx = floor(q.x / cols);
		float fx = q.x / cols - cx - 0.5;
		float rnd = hash(vec2(cx, id));
		float esiste = step(0.22, hash(vec2(cx, id + 9.0)));
		float h = 0.10 + rnd * 0.20;
		float jitter = (hash(vec2(cx, id + 4.0)) - 0.5) * 0.3;
		float dx = abs(fx - jitter);

		// abete a gradini: chioma che si stringe verso la cima + tronco
		float yn = clamp(q.y / h, 0.0, 1.0);
		float tier = fract(yn * 6.0);
		float half_w = (1.0 - yn) * (0.38 + 0.12 * tier);
		float chioma = step(dx, half_w) * step(0.22, yn) * step(q.y, h);
		float tronco = step(dx, 0.035) * step(q.y, h * 0.25);
		float suolo = step(q.y, 0.0);
		float inside = max(max(chioma, tronco) * esiste, suolo);

		float a = smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.82, 1.0, t));

		// profondità: nebbia per strato (lontano più chiaro, vicino nero)
		float fog = mix(0.30, 0.0, pow(t, 0.7));
		float tone = fog * (0.85 + 0.3 * hash(vec2(cx + 7.0, id)));
		tone += f * 0.10 * (1.0 - t);

		col = mix(col, vec3(tone), inside * a);
	}

	// foschia bassa che scorre vicino al suolo
	float mist = noise(vec2(x0 * 2.5 + TIME * 0.04, y0 * 5.0 - TIME * 0.02)) * exp(-abs(y0 + 0.02) * 6.0);
	col += mist * 0.07 * (0.8 + basso * 0.5);

	// pioggia davanti a tutto: tre livelli (lontano, medio, vicino)
	float r = rain(UV, asp, 70.0, 9.0, 3.0, vento, 1.0, TIME) * 0.10
			+ rain(UV, asp, 38.0, 6.0, 5.0, vento, 2.0, TIME) * 0.18
			+ rain(UV, asp, 18.0, 3.5, 8.0, vento, 3.0, TIME) * 0.30;
	col += vec3(r * pioggia * (1.0 + f * 1.5 + basso * 0.5));

	COLOR = vec4(col, 1.0);
}
"""

const SHADER_FX := """
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float tempo = 0.0;
uniform float sat = 0.0;

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float f = floor(tempo * 24.0);
	float g = floor(tempo * 8.0);
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, sat);
	col = col * 0.92 + 0.02;
	col *= 0.85 + 0.3 * noise(SCREEN_UV * vec2(4.0, 7.0) + 3.0);
	col += (hash(SCREEN_UV * res + f) - 0.5) * 0.10;

	float x = floor(SCREEN_UV.x * 260.0);
	col += step(0.996, hash(vec2(x, floor(tempo * 5.0)))) * 0.2;
	col += step(0.9992, hash(floor(SCREEN_UV * res / 3.0) + g * 0.37)) * 0.5;

	col *= smoothstep(1.0, 0.3, length(SCREEN_UV - 0.5) * 1.35);
	COLOR = vec4(col, 1.0);
}
"""


func _ready() -> void:
	mat_foresta = _schermo(SHADER_FORESTA, layer_foresta)
	mat_foresta.set_shader_parameter("seed", randf() * 100.0)
	mat_foresta.set_shader_parameter("pioggia", pioggia)
	mat_foresta.set_shader_parameter("vento", vento)
	if effetto_schermo:
		mat_fx = _schermo(SHADER_FX, layer_fx)
		mat_fx.set_shader_parameter("sat", saturazione)


func _schermo(codice: String, layer: int) -> ShaderMaterial:
	var cl := CanvasLayer.new()
	cl.layer = layer
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\n" + FUNZIONI + codice
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	cl.add_child(r)
	add_child(cl)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return m


# fa pulsare la foresta col basso di questa musica
func segui_musica(player: AudioStreamPlayer) -> void:
	_rimuovi_effetto()   # se viene richiamata, non accumula analizzatori sul bus
	bus_idx = AudioServer.get_bus_index(player.bus)
	effetto_analisi = AudioEffectSpectrumAnalyzer.new()
	AudioServer.add_bus_effect(bus_idx, effetto_analisi)
	analizzatore = AudioServer.get_bus_effect_instance(bus_idx, AudioServer.get_bus_effect_count(bus_idx) - 1)


func _rimuovi_effetto() -> void:
	if effetto_analisi == null:
		return
	for i in AudioServer.get_bus_effect_count(bus_idx):
		if AudioServer.get_bus_effect(bus_idx, i) == effetto_analisi:
			AudioServer.remove_bus_effect(bus_idx, i)
			break
	effetto_analisi = null
	analizzatore = null


func _exit_tree() -> void:
	_rimuovi_effetto()


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var prev := basso

	if analizzatore:
		var mag := analizzatore.get_magnitude_for_frequency_range(30.0, 150.0).length()
		var target := clampf(remap(linear_to_db(maxf(mag, 0.00001)), -40.0, -12.0, 0.0, 1.0), 0.0, 1.0)
		basso = lerpf(basso, target, 1.0 - exp(-delta * (30.0 if target > basso else 6.0)))
		# kick forte = fulmine
		if basso > soglia_kick and prev <= soglia_kick and t - ultimo_fulmine > 0.3:
			fulmine()
	else:
		basso = (0.5 + 0.5 * sin(t * 0.6)) * respiro
		if fulmini_auto and t >= prossimo_auto:
			fulmine()
			prossimo_auto = t + randf_range(2.0, 5.0)

	viaggio += delta * (velocita + minf(combo, 30) * 0.01 + (basso * 0.6 if analizzatore else 0.0))
	flash = maxf(flash - delta * 3.0, 0.0)

	mat_foresta.set_shader_parameter("viaggio", viaggio)
	mat_foresta.set_shader_parameter("basso", basso)
	mat_foresta.set_shader_parameter("flash", flash)
	if mat_fx:
		mat_fx.set_shader_parameter("tempo", t)


# ---- chiamabili dalle scene ----

func fulmine() -> void:
	flash = 1.0
	ultimo_fulmine = Time.get_ticks_msec() / 1000.0
	mat_foresta.set_shader_parameter("seed", randf() * 100.0)


# colpo di zoom (hit giusto, nota ecc.)
func pulse() -> void:
	create_tween().tween_method(func(v): mat_foresta.set_shader_parameter("pulse", v), 1.0, 0.0, 0.3)


# compatibilità col vecchio tunnel: in B/N il colore non conta, ma scatta fulmine + zoom
func burst_colore(_c: Color) -> void:
	fulmine()
	pulse()
