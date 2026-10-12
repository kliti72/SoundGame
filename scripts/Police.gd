class_name backgroundCarChase
extends Node

# Background B/N stile trap: vista laterale, macchina in fuga su una strada di notte, inseguita
# da due volanti. Sul basso compare una rampa: la macchina salta, atterra slittando (fumo,
# scintille, segni di gomma, tremito di camera) e le volanti saltano dopo di lei, sulla stessa rampa.
# Drop-in come backgroundMoonWithCity: stessa API (segui_musica, combo, fulmine, pulse, burst_colore).
#
# Come ci sta il salto a tempo: ad ogni kick la rampa viene piazzata in modo che il suo bordo arrivi
# alla macchina dopo un "periodo" (stimato dagli ultimi kick), cioè sul PROSSIMO colpo di basso.
# Se un kick arriva mentre la macchina è già sulla rampa, decolla subito.

@export var velocita := 150.0           # velocità di scorrimento (px virtuali / secondo)
@export var respiro := 0.35             # pulsazione automatica senza musica
@export var saturazione := 0.0          # 0 = bianco e nero puro, sali per far uscire il rosso/blu delle sirene
@export var effetto_schermo := true     # grana, graffi, vignettatura
@export var salti_auto := true          # rampe random quando non c'è musica collegata
@export var soglia_kick := 0.7          # sopra questa soglia di basso parte una rampa
@export var pausa_rampa := 0.55         # secondi minimi tra due rampe (deve essere > tempo di volo)
@export var altezza_salto := 22.0       # px virtuali sopra la rampa
@export var gravita := 650.0
@export var pixel_verticali := 120.0    # risoluzione "virtuale": più basso = pixel più grossi
@export var terra := 0.88               # altezza (0..1) a cui poggiano le ruote
@export var layer_scena := -2
@export var layer_fx := -1

var combo := 0                          # lo setta la scena di gioco (più combo = più veloce, volanti più vicine)
var viaggio := 0.0
var basso := 0.0
var flash := 0.0
var tremito := 0.0
var prossimo_auto := 2.0
var ultimo_kick := -10.0
var ultimo_spawn := -10.0
var periodo := 0.5                      # distanza media tra i kick (secondi)
var analizzatore: AudioEffectSpectrumAnalyzerInstance
var effetto_analisi: AudioEffectSpectrumAnalyzer
var bus_idx := -1
var mat_scena: ShaderMaterial
var mat_fx: ShaderMaterial

var macchina := Attore.new()
var pula1 := Attore.new()
var pula2 := Attore.new()
var rampe: Array = []                   # x del bordo sinistro di ogni rampa
var segni: Array = []                   # Vector2(sinistra, destra) dei segni di gomma
var segno_attivo := false

const RAMPA_L := 36.0
const RAMPA_H := 12.0
const SW := 44                          # larghezza sprite veicolo
const SH := 18                          # altezza sprite veicolo


class Attore:
	var base := 0.0         # x senza scivolata
	var spinta := 0.0       # offset x dovuto alla slittata
	var alt := 0.0          # altezza da terra
	var vy := 0.0
	var ang := 0.0          # positivo = muso in giù
	var vang := 0.0
	var aria := false
	var era_su := false     # era sulla rampa nel frame precedente
	var rimbalzato := false
	var scivolo := 0.0      # 1 -> 0 dopo l'atterraggio
	var forza := 1.0        # moltiplicatore del salto
	var e_auto := false

	func x() -> float:
		return base + spinta


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

const SHADER_SCENA := """
uniform sampler2D sprite : filter_nearest;
uniform float tempo = 0.0;
uniform float viaggio = 0.0;
uniform float basso = 0.0;
uniform float pulse = 0.0;
uniform float flash = 0.0;
uniform float tremito = 0.0;
uniform float pixel_v = 120.0;
uniform float terra = 0.88;
uniform float ramp_l = 36.0;
uniform float ramp_h = 12.0;
uniform vec4 a_auto = vec4(0.0);     // x, y (suolo), angolo, scivolo
uniform vec4 a_pula1 = vec4(0.0);
uniform vec4 a_pula2 = vec4(0.0);
uniform vec4 a_rampe = vec4(-1000.0);
uniform vec4 a_segni = vec4(-1000.0);

const float SW = 44.0;
const float SH = 18.0;

// indice di palette dello sprite (0 = vuoto), con rotazione attorno al centro
int attore(vec2 pc, vec4 a, float riga) {
	float c = cos(a.z);
	float s = sin(a.z);
	vec2 d = pc - vec2(a.x, a.y - 9.0);
	vec2 l = vec2(c * d.x + s * d.y, -s * d.x + c * d.y) + vec2(SW * 0.5, SH * 0.5);
	vec2 f = floor(l);
	if (f.x < 0.0 || f.x >= SW || f.y < 0.0 || f.y >= SH) return 0;
	vec2 uvs = vec2((f.x + 0.5) / SW, (f.y + riga * SH + 0.5) / (2.0 * SH));
	return int(floor(texture(sprite, uvs).r * 255.0 + 0.5));
}

vec3 colore(int idx, float on_a, float on_b, float freno) {
	if (idx == 1) return vec3(0.03);
	if (idx == 2) return vec3(0.46 + basso * 0.08);
	if (idx == 3) return vec3(0.80);
	if (idx == 5) return vec3(0.95);
	if (idx == 6) return vec3(0.10);
	if (idx == 8) return mix(vec3(0.45, 0.05, 0.05), vec3(1.0, 0.35, 0.35), freno);
	if (idx == 9) return mix(vec3(0.12, 0.0, 0.0), vec3(1.0, 0.45, 0.45), on_a);
	if (idx == 10) return mix(vec3(0.0, 0.02, 0.12), vec3(0.45, 0.65, 1.0), on_b);
	if (idx == 11) return vec3(mix(0.10, 0.70, step(0.5, fract(tempo * 12.0))));
	return vec3(0.0);
}

float ombra(vec2 pc, vec4 a, float yg) {
	float alt = max(yg - a.y, 0.0);
	vec2 d = (pc - vec2(a.x, yg + 1.0)) / vec2(20.0, 2.6);
	float r = 1.0 - dot(d, d);
	return step(0.0, r) * 0.55 / (1.0 + alt * 0.08);
}

// fumo dalle gomme dopo l'atterraggio: blocchi da 3px che si diradano e scivolano indietro
float fumo(vec2 pc, vec4 a, float yg) {
	float s = a.w;
	if (s < 0.02) return 0.0;
	vec2 d = pc - vec2(a.x - 14.0, yg);
	d.x += (1.0 - s) * 50.0;
	d.y += (1.0 - s) * 10.0;
	float box = step(d.x, 0.0) * step(-48.0, d.x) * step(d.y, 0.0) * step(-16.0, d.y);
	float dens = s * (1.0 + d.x / 48.0) * (1.0 + d.y / 16.0);
	float n = hash(floor(d / 3.0) + floor(tempo * 10.0) * 1.7);
	return box * step(n, dens);
}

float scintille(vec2 pc, vec4 a, float yg) {
	float s = a.w;
	if (s < 0.45) return 0.0;
	vec2 d = pc - vec2(a.x - 13.0, yg - 1.0);
	float box = step(d.x, 0.0) * step(-26.0, d.x) * step(d.y, 1.0) * step(-8.0, d.y);
	return box * step(0.96, hash(floor(d / 2.0) + floor(tempo * 30.0) * 3.1));
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float pk = res.y / pixel_v;
	vec2 vsize = floor(res / pk);
	float H = vsize.y;

	// zoom (pulse/basso) + tremito di camera, tutto a pixel virtuali interi
	float zk = 1.0 - pulse * 0.05 - basso * 0.02;
	vec2 uvz = (UV - 0.5) * zk + 0.5;
	vec2 vp = floor(uvz * res / pk);
	float tf = floor(tempo * 30.0);
	vp += floor((vec2(hash(vec2(tf, 2.0)), hash(vec2(tf, 3.0))) - 0.5) * 3.0 * tremito + 0.5);
	vec2 pc = vp + 0.5;

	float yg = floor(H * terra);   // suolo su cui poggiano le ruote
	float yr = floor(H * 0.76);    // bordo alto della strada

	// cielo + bagliore all'orizzonte + luna
	float sky = 0.04 + 0.28 * exp(-max(yr - pc.y, 0.0) / H * 4.0) * (0.7 + basso * 0.6);
	vec2 mp = vec2(pc.x - vsize.x * 0.22, pc.y - H * 0.20);
	float dm = length(mp) - H * 0.11;
	float disc = smoothstep(1.0, -1.0, dm);
	float crat = 0.80 + 0.18 * noise(mp * 0.15) + 0.07 * noise(mp * 0.4);
	sky += disc * 0.95 * crat;
	sky += exp(-max(dm, 0.0) * 0.05) * 0.20 * (1.0 + basso * 0.5);
	vec3 col = vec3(sky);

	// due strati di palazzi in parallasse (lontano lento, vicino più veloce)
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		float cw = mix(16.0, 30.0, fk);
		float sx = pc.x + viaggio * mix(0.06, 0.22, fk) + fk * 77.0;
		float cx = floor(sx / cw);
		float rnd = hash(vec2(cx, fk + 1.0));
		float h = mix(14.0, 20.0, fk) + rnd * rnd * mix(36.0, 48.0, fk) + 8.0 * step(0.88, hash(vec2(cx, fk + 5.0)));
		float top = yr - h;
		float inside = step(top, pc.y) * step(pc.y, yr);
		float rel = clamp((pc.y - top) / h, 0.0, 1.0);
		float fog = mix(0.18, 0.06, fk);
		float tone = fog * mix(1.0, 0.55, rel) * (0.85 + 0.3 * hash(vec2(cx + 7.0, fk)));
		float rim = (1.0 - step(1.0, pc.y - top)) * mix(0.25, 0.12, fk);
		float fxl = fract(sx / cw);
		vec2 wc = vec2(floor(fxl * 4.0), floor(pc.y / 6.0));
		float lit = step(0.92 - fk * 0.03, hash(wc + vec2(cx, fk) * 13.0));
		float wmask = step(0.25, fract(fxl * 4.0)) * step(0.3, fract(pc.y / 6.0)) * step(top + 4.0, pc.y);
		lit *= wmask * (0.4 + 0.6 * fk) * (0.5 + basso * 0.6);
		col = mix(col, vec3(tone + rim + lit * 0.8), inside);
	}

	// strada: asfalto, strisce di velocità, cordolo, linea tratteggiata
	if (pc.y > yr) {
		float dy = (pc.y - yr) / (H - yr);
		float r = mix(0.10, 0.035, dy) + 0.02 * noise(vec2((pc.x + viaggio) * 0.15, pc.y * 0.7));
		r += step(0.985, hash(vec2(floor((pc.x + viaggio * 1.3) / 5.0), floor(pc.y)))) * 0.10;
		r += step(abs(pc.y - (yr + 1.0)), 0.6) * 0.30;
		float yd = floor(H * 0.945);
		r += step(abs(pc.y - yd), 1.0) * step(fract((pc.x + viaggio) / 36.0), 0.55) * 0.38;
		col = vec3(r);
	}

	// guard rail
	float post = step(fract((pc.x + viaggio) / 24.0), 0.09) * step(yr - 7.0, pc.y) * step(pc.y, yr);
	float rail = step(abs(pc.y - (yr - 5.0)), 0.6);
	col = mix(col, vec3(0.30), clamp(post + rail, 0.0, 1.0));

	// lampioni: palo scuro + alone che pulsa col basso
	float lx = pc.x + viaggio;
	float lc = floor(lx / 190.0);
	float lf = lx - lc * 190.0;
	float yt = yr - 62.0;
	float pole = step(abs(lf - 95.0), 1.0) * step(yt, pc.y) * step(pc.y, yr);
	float arm = step(abs(pc.y - yt), 0.6) * step(lf, 95.0) * step(78.0, lf);
	col = mix(col, vec3(0.02), clamp(pole + arm, 0.0, 1.0));
	vec2 lamp = vec2(lc * 190.0 + 80.0 - viaggio, yt + 2.0);
	float dl = length(pc - lamp);
	col += vec3(exp(-dl * 0.045) * 0.22 * (0.85 + 0.3 * hash(vec2(floor(tempo * 12.0), lc))) * (0.9 + basso * 0.3));
	col = mix(col, vec3(1.0), step(dl, 1.8));

	// rampe: cuneo a strisce con bordo chiaro
	for (int i = 0; i < 4; i++) {
		float rl = a_rampe[i];
		float dx = pc.x - rl;
		if (dx >= 0.0 && dx < ramp_l) {
			float hh = ramp_h * dx / ramp_l;
			float dyr = yg - pc.y;
			if (dyr >= 0.0 && dyr <= hh) {
				float stripe = step(0.5, fract((dx + dyr) / 8.0));
				float tone = mix(0.12, 0.55, stripe);
				float top = step(hh - dyr, 1.0);
				col = vec3(mix(tone, 0.95, top));
			}
		}
	}

	// segni di gomma lasciati dalla slittata
	for (int i = 0; i < 2; i++) {
		float sl = a_segni[i * 2];
		float sr = a_segni[i * 2 + 1];
		if (pc.x >= sl && pc.x <= sr) {
			float m = step(abs(pc.y - (yg - 0.5)), 0.6) + step(abs(pc.y - (yg + 2.5)), 0.6);
			m *= step(0.25, hash(vec2(floor((pc.x + viaggio) / 3.0), float(i))));
			col *= 1.0 - 0.85 * clamp(m, 0.0, 1.0);
		}
	}

	// ombre a terra
	col *= 1.0 - clamp(ombra(pc, a_auto, yg) + ombra(pc, a_pula1, yg) + ombra(pc, a_pula2, yg), 0.0, 0.7);

	// fumo (dietro ai veicoli)
	float fm = max(fumo(pc, a_auto, yg), max(fumo(pc, a_pula1, yg), fumo(pc, a_pula2, yg)));
	col = mix(col, vec3(0.75), fm * 0.85);

	// veicoli: volanti prima (dietro), macchina davanti
	float on_a = step(0.5, fract(tempo * 5.0));
	float on_b = 1.0 - on_a;
	int p2 = attore(pc, a_pula2, 1.0);
	if (p2 != 0) col = colore(p2, on_b, on_a, step(0.01, a_pula2.w));
	int p1 = attore(pc, a_pula1, 1.0);
	if (p1 != 0) col = colore(p1, on_a, on_b, step(0.01, a_pula1.w));
	int m0 = attore(pc, a_auto, 0.0);
	if (m0 != 0) col = colore(m0, on_a, on_b, step(0.01, a_auto.w));

	// scintille sopra a tutto
	float sc = max(scintille(pc, a_auto, yg), max(scintille(pc, a_pula1, yg), scintille(pc, a_pula2, yg)));
	col = mix(col, vec3(1.0), sc);

	// fari della macchina
	vec2 hd = pc - vec2(a_auto.x + 22.0, a_auto.y - 7.0);
	col += vec3(step(0.0, hd.x) * exp(-hd.x * 0.022) * exp(-hd.y * hd.y * (0.015 + hd.x * 0.0004)) * 0.28);

	// luce delle sirene sulla scena (le due volanti sono in controfase)
	float k1 = 0.28 * (0.8 + basso * 0.6);
	vec3 rosso = vec3(1.0, 0.2, 0.2);
	vec3 blu = vec3(0.3, 0.5, 1.0);
	vec3 lum = vec3(0.0);
	lum += rosso * on_a * exp(-length(pc - vec2(a_pula1.x - 3.0, a_pula1.y - 17.0)) * 0.07) * k1;
	lum += blu * on_b * exp(-length(pc - vec2(a_pula1.x + 3.0, a_pula1.y - 17.0)) * 0.07) * k1;
	lum += rosso * on_b * exp(-length(pc - vec2(a_pula2.x - 3.0, a_pula2.y - 17.0)) * 0.07) * k1;
	lum += blu * on_a * exp(-length(pc - vec2(a_pula2.x + 3.0, a_pula2.y - 17.0)) * 0.07) * k1;
	col += lum;

	// lampo a scatti
	col += flash * 0.20 * step(0.25, hash(vec2(floor(tempo * 28.0), 5.0)));

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
	macchina.e_auto = true
	pula1.forza = 0.85
	pula2.forza = 0.75
	mat_scena = _schermo(SHADER_SCENA, layer_scena)
	mat_scena.set_shader_parameter("sprite", _crea_sprite())
	mat_scena.set_shader_parameter("pixel_v", pixel_verticali)
	mat_scena.set_shader_parameter("terra", terra)
	mat_scena.set_shader_parameter("ramp_l", RAMPA_L)
	mat_scena.set_shader_parameter("ramp_h", RAMPA_H)
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


# fa saltare la macchina col basso di questa musica
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


func _dim_virtuale() -> Vector2:
	var s := get_viewport().get_visible_rect().size
	return Vector2(floorf(pixel_verticali * s.x / s.y), floorf(pixel_verticali))


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var prev := basso
	var kick := false

	if analizzatore:
		var mag := analizzatore.get_magnitude_for_frequency_range(30.0, 150.0).length()
		var target := clampf(remap(linear_to_db(maxf(mag, 0.00001)), -40.0, -12.0, 0.0, 1.0), 0.0, 1.0)
		basso = lerpf(basso, target, 1.0 - exp(-delta * (30.0 if target > basso else 6.0)))
		if basso > soglia_kick and prev <= soglia_kick and t - ultimo_kick > 0.15:
			kick = true
			var dt_k := t - ultimo_kick
			if dt_k > 0.25 and dt_k < 1.5:
				periodo = lerpf(periodo, dt_k, 0.4)
			ultimo_kick = t
	else:
		basso = (0.5 + 0.5 * sin(t * 0.6)) * respiro
		if salti_auto and t >= prossimo_auto:
			kick = true
			prossimo_auto = t + randf_range(1.5, 3.0)

	var vel := velocita * (1.0 + minf(combo, 30) * 0.015)
	viaggio += delta * vel
	flash = maxf(flash - delta * 3.0, 0.0)
	tremito = maxf(tremito - delta * 6.0, 0.0)

	# rampe e segni di gomma scorrono con la strada
	for i in rampe.size():
		rampe[i] -= vel * delta
	var i := rampe.size() - 1
	while i >= 0:
		if rampe[i] < -RAMPA_L - 40.0:
			rampe.remove_at(i)
		i -= 1
	for j in segni.size():
		var sg: Vector2 = segni[j]
		segni[j] = Vector2(sg.x - vel * delta, sg.y - vel * delta)
	while segni.size() > 0 and (segni[0] as Vector2).y < -20.0:
		segni.remove_at(0)

	# posizioni base: le volanti si avvicinano con la combo
	var vs := _dim_virtuale()
	var gap := 1.0 - minf(combo, 30) * 0.01
	macchina.base = vs.x * 0.68
	pula1.base = macchina.base - 58.0 * gap
	pula2.base = macchina.base - 106.0 * gap

	if kick:
		_kick(vel)

	_aggiorna(macchina, delta, kick)
	_aggiorna(pula1, delta, false)
	_aggiorna(pula2, delta, false)

	# il segno di gomma attivo resta attaccato alla ruota posteriore finché slitta
	if segno_attivo and segni.size() > 0:
		var ult: Vector2 = segni[segni.size() - 1]
		segni[segni.size() - 1] = Vector2(ult.x, maxf(macchina.x() - 12.0, ult.x))
		if macchina.scivolo <= 0.05:
			segno_attivo = false

	var vr := Vector4(-1000.0, -1000.0, -1000.0, -1000.0)
	for r in mini(rampe.size(), 4):
		vr[r] = rampe[r]
	var vg := Vector4(-1000.0, -1000.0, -1000.0, -1000.0)
	for s in mini(segni.size(), 2):
		var sv: Vector2 = segni[s]
		vg[s * 2] = sv.x
		vg[s * 2 + 1] = sv.y
	var yg := floorf(vs.y * terra)

	mat_scena.set_shader_parameter("tempo", t)
	mat_scena.set_shader_parameter("viaggio", viaggio)
	mat_scena.set_shader_parameter("basso", basso)
	mat_scena.set_shader_parameter("flash", flash)
	mat_scena.set_shader_parameter("tremito", tremito)
	mat_scena.set_shader_parameter("a_auto", _pacchetto(macchina, yg))
	mat_scena.set_shader_parameter("a_pula1", _pacchetto(pula1, yg))
	mat_scena.set_shader_parameter("a_pula2", _pacchetto(pula2, yg))
	mat_scena.set_shader_parameter("a_rampe", vr)
	mat_scena.set_shader_parameter("a_segni", vg)
	if mat_fx:
		mat_fx.set_shader_parameter("tempo", t)


func _pacchetto(a: Attore, yg: float) -> Vector4:
	# il "lift" tiene la ruota più bassa a contatto col suolo quando l'auto è inclinata
	var lift := absf(sin(a.ang)) * 12.0
	return Vector4(a.x(), yg - a.alt - lift, a.ang, a.scivolo)


# ---- logica salti ----

func _kick(vel: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var vicino := false
	for r in rampe:
		if r + RAMPA_L > macchina.x() - 12.0:
			vicino = true
	if not vicino and not macchina.aria and macchina.scivolo < 0.5 and t - ultimo_spawn > pausa_rampa:
		_spawn_rampa(periodo, vel)


# piazza una rampa in modo che il suo bordo raggiunga la macchina tra `arrivo` secondi
func _spawn_rampa(arrivo: float, vel: float) -> void:
	var x := macchina.x() + 11.0 + vel * arrivo - RAMPA_L
	rampe.append(maxf(x, macchina.x() + 14.0))
	ultimo_spawn = Time.get_ticks_msec() / 1000.0


func _aggiorna(a: Attore, dt: float, kick: bool) -> void:
	var x := a.x()
	var su := false
	var sup := 0.0
	for r in rampe:
		if x >= r and x <= r + RAMPA_L:
			su = true
			sup = RAMPA_H * (x - r) / RAMPA_L

	var target := 0.0
	var k := 260.0
	var c := 22.0

	if a.aria:
		a.vy -= gravita * dt
		a.alt += a.vy * dt
		target = clampf(-a.vy / 500.0, -0.45, 0.45)   # muso su in salita, giù in discesa
		k = 70.0
		c = 9.0
		if a.alt <= 0.0:
			_atterra(a)
	else:
		if su:
			a.alt = sup
			a.era_su = true
			target = -atan(RAMPA_H / RAMPA_L)
			if kick and a.e_auto:
				_lancia(a)   # il kick arriva con la macchina già sulla rampa: decolla ora
		elif a.era_su:
			_lancia(a)       # ha superato il bordo della rampa: decolla
		else:
			a.alt = 0.0

	# molla sull'angolo: rimbalzo del muso all'atterraggio
	var acc := -k * (a.ang - target) - c * a.vang
	a.vang += acc * dt
	a.ang += a.vang * dt

	a.scivolo = maxf(a.scivolo - dt * 1.6, 0.0)
	a.spinta = lerpf(a.spinta, 0.0, 1.0 - exp(-dt * 2.5))


func _lancia(a: Attore) -> void:
	a.aria = true
	a.era_su = false
	a.rimbalzato = false
	a.vy = sqrt(2.0 * gravita * altezza_salto) * a.forza
	a.alt = maxf(a.alt, 0.01)


func _atterra(a: Attore) -> void:
	if absf(a.vy) > 120.0 and not a.rimbalzato:
		# primo impatto: slittata + piccolo rimbalzo
		a.scivolo = 1.0
		a.spinta = -randf_range(12.0, 20.0) if a.e_auto else randf_range(-16.0, 6.0)
		a.vang += 3.0
		a.vy = -a.vy * 0.22
		a.alt = 0.01
		a.rimbalzato = true
		if a.e_auto:
			tremito = 1.0
			_nuovo_segno()
	else:
		a.alt = 0.0
		a.vy = 0.0
		a.aria = false
		a.rimbalzato = false


func _nuovo_segno() -> void:
	var dietro := macchina.x() - 12.0
	segni.append(Vector2(dietro, dietro))
	if segni.size() > 2:
		segni.remove_at(0)
	segno_attivo = true


# ---- chiamabili dalle scene ----

# fa partire un salto subito (rampa tra ~0.25 s)
func salta() -> void:
	if not macchina.aria:
		_spawn_rampa(0.25, velocita * (1.0 + minf(combo, 30) * 0.015))


func fulmine() -> void:
	flash = 1.0


# colpo di zoom (hit giusto, nota ecc.)
func pulse() -> void:
	create_tween().tween_method(func(v): mat_scena.set_shader_parameter("pulse", v), 1.0, 0.0, 0.3)


# compatibilità col vecchio tunnel: scatta lampo + zoom
func burst_colore(_c: Color) -> void:
	fulmine()
	pulse()


# ---- sprite generato da codice: riga 0 = macchina, riga 1 = volante ----
# indici: 0 vuoto, 1 contorno nero, 2 carrozzeria, 3 chiaro, 5 bianco, 6 vetro,
#         8 fanale posteriore, 9/10 sirena rossa/blu, 11 mozzo ruota (lampeggia = ruota che gira)

func _crea_sprite() -> ImageTexture:
	var img := Image.create(SW, SH * 2, false, Image.FORMAT_R8)
	img.fill(Color(0, 0, 0))
	_disegna_veicolo(img, 0, false)
	_disegna_veicolo(img, SH, true)
	return ImageTexture.create_from_image(img)


func _px(img: Image, x: int, y: int, idx: int) -> void:
	if x < 0 or y < 0 or x >= SW or y >= SH * 2:
		return
	img.set_pixel(x, y, Color(idx / 255.0, 0, 0))


func _rect(img: Image, oy: int, x: int, y: int, w: int, h: int, idx: int) -> void:
	for yy in h:
		for xx in w:
			_px(img, x + xx, oy + y + yy, idx)


func _disegna_veicolo(img: Image, oy: int, polizia: bool) -> void:
	# cabina: tetto a trapezio, vetri scuri
	for y in range(2, 8):
		var x0 := 14 - (y - 2)
		var x1 := 27 + int((y - 2) * 1.2)
		for x in range(x0, x1 + 1):
			var idx := 6
			if y == 2:
				idx = 3 if polizia else 1
			if x == x0 or x == x1:
				idx = 1
			_px(img, x, oy + y, idx)
	if not polizia:
		# riflesso sul vetro
		for g in 4:
			_px(img, 25 - g, oy + 3 + g, 3)

	# carrozzeria
	for y in range(8, 15):
		for x in range(2, 42):
			var idx := 2
			if polizia:
				idx = 1 if y < 11 else 3
				if y == 8:
					idx = 3
			else:
				if y == 8:
					idx = 3
			if y == 14:
				idx = 1
			if x == 21 and y >= 9 and y <= 13:
				idx = 1      # linea della portiera
			if x == 2 or x == 41:
				idx = 1
			_px(img, x, oy + y, idx)

	# fari davanti, fanali dietro
	_px(img, 41, oy + 10, 5)
	_px(img, 41, oy + 11, 5)
	_px(img, 2, oy + 10, 8)
	_px(img, 2, oy + 11, 8)

	if polizia:
		# barra luminosa sul tetto: metà rossa, metà blu
		for x in range(17, 27):
			var s := 9 if x < 22 else 10
			_px(img, x, oy, s)
			_px(img, x, oy + 1, s)
	else:
		# alettone
		for x in range(2, 10):
			_px(img, x, oy + 5, 1)
		_px(img, 3, oy + 6, 1)
		_px(img, 3, oy + 7, 1)
		_px(img, 8, oy + 6, 1)
		_px(img, 8, oy + 7, 1)

	# ruote (sopra la carrozzeria)
	for cx in [11.0, 33.0]:
		for y in range(10, 18):
			for x in range(int(cx) - 4, int(cx) + 4):
				var dx = x + 0.5 - cx 
				var dy = y + 0.5 - 14.0
				if dx * dx + dy * dy <= 16.0:
					_px(img, x, oy + y, 1)
		_rect(img, oy, int(cx) - 1, 13, 2, 2, 11)
