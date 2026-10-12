class_name backgroundMoonWithCity
extends Node

# Background B/N stile trap: città dark in zoom infinito + luna + fulmini rotti.
# Drop-in al posto di TunnelBackground: stessa API.

@export var velocita := 0.10          # zoom base (menu lento, gioco ~0.4)
@export var respiro := 0.35           # pulsazione automatica senza musica
@export var saturazione := 0.0        # 0 = bianco e nero puro, sali per far uscire i colori del gioco
@export var effetto_schermo := true   # grana, graffi, vignettatura
@export var fulmini_auto := true      # fulmini random quando non c'è musica collegata
@export var soglia_kick := 0.7        # sopra questa soglia di basso parte un fulmine
@export var layer_citta := -2
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
var mat_citta: ShaderMaterial
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

const SHADER_CITTA := """
uniform float viaggio = 0.0;
uniform float basso = 0.0;
uniform float pulse = 0.0;
uniform float flash = 0.0;
uniform float seed = 1.0;

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

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float asp = res.x / res.y;
	float hor = 0.58;
	float x0 = (UV.x - 0.5) * asp;
	float y0 = hor - UV.y;

	float zoomk = 1.0 - pulse * 0.05 - basso * 0.04;
	vec2 p = vec2(x0, y0) * zoomk;

	// cielo + bagliore all'orizzonte
	float sky = 0.05 + 0.28 * exp(-max(y0, 0.0) * 3.0) * (0.7 + basso * 0.6);

	// luna grande, alta e fissa: i palazzi non arrivano mai fin lassù
	vec2 mp = vec2(x0 + 0.30 * asp, y0 - 0.42);
	float dm = length(mp) - 0.12;
	float disc = smoothstep(0.004, -0.004, dm);
	float crat = 0.80 + 0.18 * noise(mp * 18.0) + 0.07 * noise(mp * 45.0);
	sky += disc * 0.95 * crat;
	sky += exp(-max(dm, 0.0) * 7.0) * 0.20 * (1.0 + basso * 0.5);
	vec3 col = vec3(sky);

	// fulmini (dietro la città), flickerano a scatti
	float f = flash * step(0.25, hash(vec2(floor(TIME * 28.0), 5.0)));
	col += f * 0.20;
	float b = bolt(UV, seed, 0.15 + 0.7 * hash(vec2(seed, 1.0)));
	b += 0.6 * bolt(UV, seed + 13.0, 0.15 + 0.7 * hash(vec2(seed, 2.0)));
	col += vec3(b * f * 1.3);

	// città in loop zoom: strati dal più lontano al più vicino
	for (int k = 0; k < STRATI; k++) {
		float t = (float(k) + fract(viaggio)) / float(STRATI);
		float id = float(k) - floor(viaggio);
		float sc = exp(mix(log(0.25), log(2.4), t));
		vec2 q = p / sc;

		// palazzi larghi, ogni strato ha la sua larghezza
		float cols = 0.09 + 0.07 * hash(vec2(id, 3.0));
		float cx = floor(q.x / cols);
		float rnd = hash(vec2(cx, id));
		float h = 0.01 + rnd * rnd * 0.12 + 0.02 * step(0.85, hash(vec2(cx, id + 5.0)));
		float inside = step(q.y, h);
		float a = smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.82, 1.0, t));

		// profondità: nebbia per strato, gradiente verticale, identità per palazzo
		float fog = mix(0.30, 0.0, pow(t, 0.7));
		float grad = mix(0.55, 1.0, smoothstep(h - 0.10, h, q.y));
		float tone = fog * grad * (0.85 + 0.3 * hash(vec2(cx + 7.0, id)));

		// bordo alto + lato sinistro illuminato dalla luna
		float rim = (1.0 - smoothstep(0.0, 0.010, h - q.y)) * (1.0 - t) * 0.35;
		float fxl = q.x / cols - cx;
		float edge = (1.0 - smoothstep(0.0, 0.07, fxl)) * 0.10 * (1.0 - t);

		// poche finestre, solo sugli strati vicini
		vec2 wc = vec2(floor(fxl * 3.0), floor(q.y / 0.035));
		float lit = step(0.93, hash(wc + vec2(cx, id) * 17.0));
		float wmask = step(0.2, fract(fxl * 3.0)) * step(0.2, fract(q.y / 0.035)) * step(q.y, h - 0.02);
		lit *= wmask * smoothstep(0.35, 0.6, t) * (0.55 + basso * 0.6);

		col = mix(col, vec3(tone + rim + edge + lit * 0.85), inside * a);
	}

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
	mat_citta = _schermo(SHADER_CITTA, layer_citta)
	mat_citta.set_shader_parameter("seed", randf() * 100.0)
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


# fa pulsare la città col basso di questa musica
func segui_musica(player: AudioStreamPlayer) -> void:
	bus_idx = AudioServer.get_bus_index(player.bus)
	effetto_analisi = AudioEffectSpectrumAnalyzer.new()
	AudioServer.add_bus_effect(bus_idx, effetto_analisi)
	analizzatore = AudioServer.get_bus_effect_instance(bus_idx, AudioServer.get_bus_effect_count(bus_idx) - 1)


func _exit_tree() -> void:
	if effetto_analisi == null:
		return
	for i in AudioServer.get_bus_effect_count(bus_idx):
		if AudioServer.get_bus_effect(bus_idx, i) == effetto_analisi:
			AudioServer.remove_bus_effect(bus_idx, i)
			break


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

	mat_citta.set_shader_parameter("viaggio", viaggio)
	mat_citta.set_shader_parameter("basso", basso)
	mat_citta.set_shader_parameter("flash", flash)
	if mat_fx:
		mat_fx.set_shader_parameter("tempo", t)


# ---- chiamabili dalle scene ----

func fulmine() -> void:
	flash = 1.0
	ultimo_fulmine = Time.get_ticks_msec() / 1000.0
	mat_citta.set_shader_parameter("seed", randf() * 100.0)


# colpo di zoom (hit giusto, nota ecc.)
func pulse() -> void:
	create_tween().tween_method(func(v): mat_citta.set_shader_parameter("pulse", v), 1.0, 0.0, 0.3)


# compatibilità col vecchio tunnel: in B/N il colore non conta, ma scatta fulmine + zoom
func burst_colore(_c: Color) -> void:
	fulmine()
	pulse()
