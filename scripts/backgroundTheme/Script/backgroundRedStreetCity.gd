class_name backgroundRedStreetCity
extends Node

@export var velocita := 1.5           # avanzamento nel vicolo (menu lento, gioco ~4)
@export var respiro := 0.35           # pulsazione automatica senza musica
@export var saturazione := 1.0        # 0 = tutto grigio, 1 = rosso pieno
@export var effetto_schermo := true   # grana, vignettatura
@export var onde_auto := true         # onde random quando non c'è musica collegata
@export var soglia_kick := 0.7        # sopra questa soglia di basso parte l'onda
@export var layer_strada := -2
@export var layer_fx := -1

var combo := 0                        # lo setta la scena di gioco
var viaggio := 0.0
var basso := 0.0
var onda := 100.0                     # distanza del fronte d'onda (>45 = spenta)
var prossimo_auto := 2.0
var ultimo_colpo := -10.0
var analizzatore: AudioEffectSpectrumAnalyzerInstance
var effetto_analisi: AudioEffectSpectrumAnalyzer
var bus_idx := -1
var mat_strada: ShaderMaterial
var mat_fx: ShaderMaterial

const ROSSO := Color(1.0, 0.05, 0.08)

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

const SHADER_STRADA := """
uniform float viaggio = 0.0;
uniform float basso = 0.0;
uniform float pulse = 0.0;
uniform float onda = 100.0;
uniform vec4 tint : source_color = vec4(1.0, 0.05, 0.08, 1.0);

const float CAMH = 1.0;   // altezza camera
const float W = 2.2;      // mezza larghezza strada

// muro del palazzo: rgb + a (a = 0 se sopra il tetto, quindi cielo)
vec4 muro(float zw, float y, float side) {
	float blk = floor(zw / 4.0);
	float rnd = hash(vec2(blk, side * 7.0 + 1.0));
	float H = 2.5 + rnd * 4.0;
	if (y > H) return vec4(0.0);

	float n = noise(vec2(zw * 1.3, y * 1.3));
	vec3 c = vec3((0.02 + 0.03 * n) * (0.7 + 0.6 * rnd));

	// poche finestre accese
	vec2 g = vec2(zw / 0.9, y / 1.1);
	vec2 gc = floor(g);
	vec2 gf = fract(g);
	float win = step(0.2, gf.x) * step(gf.x, 0.8) * step(0.25, gf.y) * step(gf.y, 0.85) * step(0.8, y);
	float on = step(0.92, hash(gc + blk * 3.1 + side * 5.0));
	c += vec3(win * 0.012) + win * on * vec3(0.55, 0.12, 0.05);

	// lampione sul muro
	vec2 lp = vec2((fract(zw / 6.0) - 0.5) * 6.0, y - 2.4);
	float d2 = dot(lp, lp);
	c += vec3(1.0, 0.12, 0.1) * exp(-d2 * 1.2) * 1.2;
	c += vec3(0.5, 0.03, 0.05) * exp(-d2 * 0.12) * 0.5;

	// l'acqua rossa macchia il muro in basso
	c += vec3(0.28, 0.0, 0.03) * (1.0 - smoothstep(0.0, 0.9, y)) * (0.6 + 0.8 * n);
	return vec4(c, 1.0);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float asp = res.x / res.y;
	float zk = 1.0 - pulse * 0.05 - basso * 0.03;
	float sx = (UV.x - 0.5) * asp * zk;
	float sy = (0.47 - UV.y) * zk;

	float ax = max(abs(sx), 0.0001);
	float tw = W / ax;
	float side = sign(sx);

	// nebbia: più intensa e luminosa verso il fondo della strada
	float glow = exp(-length(vec2(sx, sy * 1.2)) * 2.2);
	vec3 fogcol = vec3(0.10, 0.0, 0.02) + vec3(0.45, 0.03, 0.07) * glow * (0.7 + basso * 0.8);

	float tf = 1.0e6;
	if (sy < -0.0001) { tf = CAMH / (-sy); }

	vec3 col;
	float tdist;

	if (tf < tw) {
		// ---- pavimento: acqua rossa che scorre ----
		tdist = tf;
		float x = sx * tf;
		float zw = tf + viaggio;
		float zwat = zw + TIME * 0.9;
		float acqua = 1.0 - smoothstep(1.4, 1.8, abs(x));
		float graz = exp(sy * 6.0);   // più riflesso vicino all'orizzonte

		float fl = noise(vec2(x * 3.0, zwat * 0.7));
		float fl2 = noise(vec2(x * 7.0 + 3.0, zwat * 1.6));
		float streak = smoothstep(0.5, 0.9, fl * 0.6 + fl2 * 0.5);
		vec3 w = vec3(0.09, 0.0, 0.015) + vec3(0.9, 0.04, 0.06) * streak * (0.15 + 0.85 * graz) * (0.8 + basso * 0.8);

		// ondine di pioggia
		vec2 g = vec2(x, zwat) * 1.5;
		vec2 gi = floor(g);
		vec2 gf = fract(g) - 0.5;
		float ph = fract(TIME * 0.8 + hash(gi));
		vec2 off = (vec2(hash(gi + 1.0), hash(gi + 2.0)) - 0.5) * 0.4;
		float ring = (1.0 - smoothstep(0.0, 0.04, abs(length(gf - off) - ph * 0.45))) * (1.0 - ph);
		w += vec3(0.8, 0.12, 0.12) * ring * 0.45 * exp(-tf * 0.08);

		// marciapiede bagnato ai lati
		vec3 pav = vec3(0.025) + vec3(0.12, 0.0, 0.02) * graz * 0.3;
		col = mix(pav, w, acqua);

		// pozze di luce sotto i lampioni
		vec2 pl = vec2(abs(x) - 1.9, (fract(zw / 6.0) - 0.5) * 6.0);
		col += vec3(0.7, 0.05, 0.07) * exp(-dot(pl, pl) * 0.5) * 0.5;
	} else {
		// ---- muri dei palazzi o cielo ----
		tdist = tw;
		float y = CAMH + sy * tw;
		vec4 m = muro(tw + viaggio, y, side);
		if (m.a > 0.5) {
			col = m.rgb;
		} else {
			tdist = 100.0;
			col = fogcol * 0.7 + vec3(0.04, 0.0, 0.01) * noise(vec2(sx * 2.0 + TIME * 0.05, sy * 4.0));
		}
	}

	// onda di luce che corre lungo la strada a ogni kick
	float band = exp(-pow(tdist - onda, 2.0) * 0.12) * (1.0 - clamp(onda / 45.0, 0.0, 1.0));
	col += tint.rgb * band * 0.7;

	// nebbia in profondità
	float fogf = 1.0 - exp(-tdist * 0.07);
	col = mix(col, fogcol, fogf);

	// pioggia in primo piano
	float rc = floor(UV.x * 220.0);
	float rsp = 0.6 + hash(vec2(rc, 1.0));
	float yy = UV.y * 8.0 - TIME * rsp * 4.0;
	float rx = 1.0 - smoothstep(0.08, 0.14, abs(fract(UV.x * 220.0) - 0.5));
	col += vec3(0.5, 0.15, 0.15) * step(0.985, hash(vec2(rc, floor(yy)))) * fract(yy) * rx * 0.25;

	// più scuro in basso, dove di solito c'è il gioco
	col *= mix(1.0, 0.75, UV.y);
	COLOR = vec4(col, 1.0);
}
"""

const SHADER_FX := """
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float tempo = 0.0;
uniform float sat = 1.0;

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float f = floor(tempo * 24.0);
	float g = floor(tempo * 8.0);
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, sat);
	col = col * 0.95 + 0.01;
	col += (hash(SCREEN_UV * res + f) - 0.5) * 0.09;
	col += step(0.9992, hash(floor(SCREEN_UV * res / 3.0) + g * 0.37)) * vec3(0.5, 0.2, 0.2);
	col *= 1.0 - 0.03 * hash(vec2(f, 7.0));
	col *= smoothstep(1.0, 0.25, length(SCREEN_UV - 0.5) * 1.4);
	COLOR = vec4(col, 1.0);
}
"""


func _ready() -> void:
	mat_strada = _schermo(SHADER_STRADA, layer_strada)
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


# fa pulsare la strada col basso di questa musica
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
		# kick forte = onda di luce lungo la strada
		if basso > soglia_kick and prev <= soglia_kick and t - ultimo_colpo > 0.3:
			colpo()
	else:
		basso = (0.5 + 0.5 * sin(t * 0.6)) * respiro
		if onde_auto and t >= prossimo_auto:
			colpo()
			prossimo_auto = t + randf_range(3.0, 6.0)

	viaggio += delta * (velocita + minf(combo, 30) * 0.05 + (basso * 2.0 if analizzatore else 0.0))
	onda = minf(onda + delta * 35.0, 100.0)

	mat_strada.set_shader_parameter("viaggio", viaggio)
	mat_strada.set_shader_parameter("basso", basso)
	mat_strada.set_shader_parameter("onda", onda)
	if mat_fx:
		mat_fx.set_shader_parameter("tempo", t)


# ---- chiamabili dalle scene ----

# onda di luce che parte dalla camera e corre in fondo alla strada
func colpo() -> void:
	onda = 0.0
	ultimo_colpo = Time.get_ticks_msec() / 1000.0


# colpo di zoom (hit giusto, nota ecc.)
func pulse() -> void:
	create_tween().tween_method(func(v): mat_strada.set_shader_parameter("pulse", v), 1.0, 0.0, 0.3)


# onda + zoom col colore che vuoi, poi torna rosso
func burst_colore(c: Color) -> void:
	colpo()
	pulse()
	create_tween().tween_method(func(v): mat_strada.set_shader_parameter("tint", c.lerp(ROSSO, v)), 0.0, 1.0, 0.8)
