class_name backgroundGraffitiWall
extends Node

# Background B/N stile trap: muro di mattoni sotto un lampione che balla. A ogni colpo di basso
# una bomboletta spruzza un graffito (macchia con colature, tag, X, cerchio); i graffiti
# restano sul muro e poi sbiadiscono. Ragnatele negli angoli.
# Parallelo agli altri sfondi: stessa API (segui_musica, fulmine, pulse, burst_colore, combo).

@export var velocita := 0.10          # oscillazione del lampione (menu lento, gioco ~0.4)
@export var respiro := 0.35           # pulsazione automatica senza musica
@export var saturazione := 0.0        # 0 = bianco e nero puro
@export var effetto_schermo := true   # grana, graffi, vignettatura
@export var spray_auto := true        # spruzzi random quando non c'è musica collegata
@export var ragnatele := true         # ragnatele negli angoli
@export var soglia_kick := 0.7        # sopra questa soglia di basso parte uno spruzzo
@export var layer_muro := -2
@export var layer_fx := -1

const N_COLPI := 32                   # graffiti tenuti a schermo (deve coincidere con lo shader)

var combo := 0                        # lo setta la scena di gioco
var viaggio := 0.0
var basso := 0.0
var prossimo_auto := 1.0
var ultimo_colpo := -10.0
var indice := 0
var nascite := PackedFloat32Array()
var semi := PackedFloat32Array()
var analizzatore: AudioEffectSpectrumAnalyzerInstance
var effetto_analisi: AudioEffectSpectrumAnalyzer
var bus_idx := -1
var mat_muro: ShaderMaterial
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

const SHADER_MURO := """
uniform float ora = 0.0;
uniform float viaggio = 0.0;
uniform float basso = 0.0;
uniform float pulse = 0.0;
uniform float ragnatele = 1.0;
uniform float nascite[32];
uniform float semi[32];

// un graffito: 4 tipi (macchia con colature, tag a onda, X, cerchio), si "disegna" in 0.25s
float vernice(vec2 p, vec2 pos, float sd, float age) {
	vec2 l = p - pos;
	if (abs(l.x) > 0.45 || l.y < -0.25 || l.y > 0.65) { return 0.0; }
	float kind = hash(vec2(sd, 1.0));
	float s = 0.06 + 0.07 * hash(vec2(sd, 2.0));
	float reveal = clamp(age / 0.25, 0.0, 1.0);
	float m = 0.0;

	if (kind < 0.35) {
		// macchia di spray + colature che scendono col tempo
		float d = length(l) / (s * max(reveal, 0.05));
		float core = smoothstep(1.0, 0.35, d + 0.25 * noise(l * 30.0));
		float cw = s * 0.28;
		float cx = floor(l.x / cw);
		float fxd = abs(fract(l.x / cw) - 0.5);
		float dr = step(0.55, hash(vec2(cx, sd + 5.0))) * step(abs(l.x), s * 0.8);
		float lung = s * (0.6 + 2.0 * hash(vec2(cx, sd + 8.0))) * clamp((age - 0.2) / 3.0, 0.0, 1.0);
		float drip = dr * step(fxd, 0.08) * step(s * 0.4, l.y) * step(l.y, s * 0.4 + lung);
		m = max(core, drip);
	} else if (kind < 0.70) {
		// tag: linea a onda con una seconda linea sottile sopra
		float u = l.x / (s * 3.0);
		float yw = sin(u * 9.0 + sd) * s * 0.5 + sin(u * 17.0 + sd * 2.0) * s * 0.2;
		float thick = s * 0.10;
		float d1 = abs(l.y - yw);
		float d2 = abs(l.y - yw * 0.6 - s * 0.35);
		float stroke = max(smoothstep(thick, thick * 0.4, d1), 0.6 * smoothstep(thick * 0.6, thick * 0.2, d2));
		m = stroke * step(abs(u), 1.0) * step((u + 1.0) * 0.5, reveal);
	} else if (kind < 0.88) {
		// X
		float w = s * 0.12;
		float dd = min(abs(l.x - l.y), abs(l.x + l.y)) * 0.7071;
		float box = step(max(abs(l.x), abs(l.y)), s);
		m = smoothstep(w, w * 0.3, dd) * box * reveal;
	} else {
		// cerchio che si chiude
		float w = s * 0.12;
		float ring = smoothstep(w, w * 0.3, abs(length(l) - s));
		float ang = atan(l.y, l.x) / 6.2832 + 0.5;
		m = ring * step(ang, reveal);
	}

	// grana dello spray + puntini di overspray
	m *= 0.75 + 0.25 * noise(l * 120.0);
	float over = step(0.975, hash(floor(l * 260.0) + sd)) * smoothstep(s * 2.2, s * 0.5, length(l)) * step(0.1, reveal);
	return clamp(max(m, over * 0.8), 0.0, 1.0);
}

// bomboletta che trema + nebbia dello spruzzo; vec3(maschera, tono, nebbia)
vec3 lattina(vec2 p, vec2 pos, float sd, float age, float t) {
	if (age > 0.42 || length(p - pos) > 0.42) { return vec3(0.0); }
	float side = hash(vec2(sd, 20.0)) > 0.5 ? 1.0 : -1.0;
	vec2 cc = pos + vec2(side * 0.19, 0.13);
	cc += (vec2(hash(vec2(floor(t * 40.0), sd)), hash(vec2(floor(t * 40.0), sd + 1.0))) - 0.5) * 0.006;
	vec2 verso = pos - cc;
	float dist = length(verso);
	vec2 ax = verso / dist;
	vec2 v = p - cc;
	float al = dot(v, ax);
	float pe = dot(v, vec2(-ax.y, ax.x));
	float fade = smoothstep(0.0, 0.05, age) * (1.0 - smoothstep(0.28, 0.42, age));

	float body = step(abs(pe), 0.026) * step(-0.12, al) * step(al, 0.0);
	float cap = step(abs(pe), 0.02) * step(0.0, al) * step(al, 0.03);
	float nozzle = step(abs(pe), 0.007) * step(0.03, al) * step(al, 0.045);
	float label = step(-0.095, al) * step(al, -0.05);
	float shade = mix(0.78, 0.22, label);
	float mask = max(max(body, cap), nozzle);

	float la = al - 0.045;
	float cone = step(0.0, la) * step(la, dist - 0.045) * step(abs(pe), la * 0.30 + 0.004);
	float dots = step(0.5, hash(floor(vec2(la, pe) * 170.0) + floor(t * 30.0))) * cone * (1.0 - la / dist) * 0.8;
	return vec3(mask * fade, shade, dots * fade);
}

// ragnatela in un angolo: p = distanza dall'angolo (entrambe le componenti >= 0)
float web(vec2 p, float size, float sd, float t, float vib) {
	float r = length(p);
	if (r > size || r < 0.001) { return 0.0; }
	float u = atan(p.y, p.x) / 1.5708 * 6.0;
	float fu = fract(u);
	float sector = floor(u);
	float rr0 = size / 9.0;
	float swing = 0.004 * sin(t * 1.3 + r * 9.0 + sd) * (1.0 + vib * 3.0);
	float sag = 0.016 * sin(fu * 3.14159);
	float rr = (r + sag + swing) / rr0;
	float rf = fract(rr);
	float ring_d = min(rf, 1.0 - rf) * rr0;
	float ring = smoothstep(0.0022, 0.0006, ring_d) * step(0.25, hash(vec2(floor(rr), sector + sd * 7.0)));
	float spoke_d = min(fu, 1.0 - fu) * r;
	float spoke = smoothstep(0.0025, 0.0007, spoke_d) * step(0.08, hash(vec2(floor(r * 14.0), sector + sd * 3.0)));
	float fade = 1.0 - smoothstep(0.6, 1.0, r / size);
	return max(ring, spoke) * fade;
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float asp = res.x / res.y;
	float zoomk = 1.0 - pulse * 0.04 - basso * 0.03;
	vec2 uvz = (UV - 0.5) * zoomk + 0.5;
	vec2 p = vec2(uvz.x * asp, uvz.y);

	// mattoni sfalsati con malta scura
	float bw = 0.17;
	float bh = 0.07;
	float row = floor(p.y / bh);
	float bx = p.x / bw + 0.5 * mod(row, 2.0);
	vec2 cell = vec2(floor(bx), row);
	vec2 fc = vec2(fract(bx), fract(p.y / bh));
	float edge = min(min(fc.x * bw, (1.0 - fc.x) * bw), min(fc.y * bh, (1.0 - fc.y) * bh));
	float mortar = 1.0 - smoothstep(0.003, 0.008, edge);
	float brick = 0.15 + 0.10 * hash(cell) + 0.10 * (noise(p * 38.0) - 0.5) + 0.12 * (noise(p * 7.0 + cell) - 0.5);
	float wall = mix(brick, 0.045, mortar);
	wall *= 0.8 + 0.4 * noise(vec2(p.x * 9.0, p.y * 1.2));   // macchie d'umido
	wall += (1.0 - smoothstep(0.0, 0.012, fc.y * bh)) * (1.0 - mortar) * 0.03;

	// lampione che dondola, si accende col basso e ogni tanto "salta"
	vec2 lp = vec2(0.5 + 0.18 * sin(viaggio * 2.0), 0.15);
	float dl = length((UV - lp) * vec2(asp * 0.8, 1.0));
	float flick = 1.0 - 0.55 * step(0.965, hash(vec2(floor(ora * 14.0), 3.0)));
	float light = (0.18 + 0.95 * exp(-dl * 1.9)) * (0.85 + 0.5 * basso) * flick;
	vec3 col = vec3(wall * light);

	// vecchi graffiti sbiaditi, sempre presenti
	for (int i = 0; i < 6; i++) {
		float sd = 200.0 + float(i) * 7.3;
		vec2 pos = vec2(0.1 + 0.8 * hash(vec2(sd, 0.0)), 0.12 + 0.6 * hash(vec2(sd, 1.0))) * vec2(asp, 1.0);
		float m = vernice(p, pos, sd, 30.0);
		col = mix(col, vec3(0.6) * light, m * 0.18);
	}

	// graffiti nuovi: uno per ogni colpo, sbiadiscono tra 8 e 14 secondi
	for (int i = 0; i < 32; i++) {
		float age = ora - nascite[i];
		if (age < 0.0 || age > 14.0) { continue; }
		float sd = semi[i];
		vec2 pos = vec2(0.10 + 0.80 * hash(vec2(sd, 0.0)), 0.12 + 0.70 * hash(vec2(sd, 1.0))) * vec2(asp, 1.0);
		float alpha = 1.0 - smoothstep(8.0, 14.0, age);
		float m = vernice(p, pos, sd, age) * alpha;
		float nero = step(hash(vec2(sd, 3.0)), 0.25);   // ogni tanto vernice nera sopra il bianco
		vec3 paint = mix(vec3(0.95) * (0.55 + 0.5 * light), vec3(0.01), nero);
		col = mix(col, paint, m * 0.9);

		vec3 cn = lattina(p, pos, sd, age, ora);
		col = mix(col, vec3(cn.y), cn.x);
		col += vec3(cn.z) * 0.7;
	}

	// ragnatele sui bordi (non seguono lo zoom)
	if (ragnatele > 0.5) {
		float w1 = web(vec2(UV.x * asp, UV.y), 0.62, 1.0, ora, basso);
		float w2 = web(vec2((1.0 - UV.x) * asp, UV.y), 0.50, 2.0, ora, basso);
		float w3 = web(vec2((1.0 - UV.x) * asp, 1.0 - UV.y), 0.34, 3.0, ora, basso);
		float w = max(max(w1, w2), w3);
		col = mix(col, vec3(0.8), w * 0.6);
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
	# nessun graffito all'inizio: nascite molto nel passato = fuori dall'intervallo visibile
	nascite.resize(N_COLPI)
	nascite.fill(-1000.0)
	semi.resize(N_COLPI)
	semi.fill(0.0)

	mat_muro = _schermo(SHADER_MURO, layer_muro)
	mat_muro.set_shader_parameter("nascite", nascite)
	mat_muro.set_shader_parameter("semi", semi)
	mat_muro.set_shader_parameter("ragnatele", 1.0 if ragnatele else 0.0)
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


# fa partire uno spruzzo a ogni colpo di basso di questa musica
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
		# kick forte = spruzzo
		if basso > soglia_kick and prev <= soglia_kick and t - ultimo_colpo > 0.15:
			colpo()
	else:
		basso = (0.5 + 0.5 * sin(t * 0.6)) * respiro
		if spray_auto and t >= prossimo_auto:
			colpo()
			prossimo_auto = t + randf_range(0.5, 1.4)

	viaggio += delta * (velocita + minf(combo, 30) * 0.01 + (basso * 0.6 if analizzatore else 0.0))

	mat_muro.set_shader_parameter("viaggio", viaggio)
	mat_muro.set_shader_parameter("basso", basso)
	mat_muro.set_shader_parameter("ora", t)
	if mat_fx:
		mat_fx.set_shader_parameter("tempo", t)


# ---- chiamabili dalle scene ----

# nuovo graffito in un punto casuale del muro (sostituisce il vecchio più datato)
func colpo() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	nascite[indice] = t
	semi[indice] = randf() * 100.0
	indice = (indice + 1) % N_COLPI
	ultimo_colpo = t
	mat_muro.set_shader_parameter("nascite", nascite)
	mat_muro.set_shader_parameter("semi", semi)


# compatibilità con gli altri sfondi (le scene chiamano fulmine())
func fulmine() -> void:
	colpo()


# colpo di zoom (hit giusto, nota ecc.)
func pulse() -> void:
	create_tween().tween_method(func(v): mat_muro.set_shader_parameter("pulse", v), 1.0, 0.0, 0.3)


# compatibilità col vecchio tunnel: in B/N il colore non conta, ma scatta spruzzo + zoom
func burst_colore(_c: Color) -> void:
	colpo()
	pulse()
