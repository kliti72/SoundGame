class_name MostroPixel
extends Node

# Mostro pixel art che balla a tempo di musica e ogni tanto spara laser dagli occhi.
# Va messo DOPO lo sfondo nell'albero della scena (stesso layer -2, quindi disegna sopra la città).
# Lo sprite viene generato da codice (nessun asset da importare), lo shader lo anima.
#
# Uso:
#   var sfondo := backgroundMoonWithCity.new()
#   add_child(sfondo)
#   sfondo.segui_musica($Musica)
#   var mostro := MostroPixel.new()
#   mostro.sfondo = sfondo
#   add_child(mostro)

@export var sfondo: backgroundMoonWithCity   # legge il basso da qui; se vuoto usa un basso finto (~100 bpm)
@export var layer_mostro := -2               # stesso layer della città, ma sopra (sotto la grana, layer -1)
@export var pixel_verticali := 100.0         # risoluzione "virtuale": più basso = pixel più grossi
@export var scala := 1.0                     # 1 = sprite 32px, 2 = doppio
@export var posizione_x := 0.5               # 0..1 posizione orizzontale
@export var soglia_colpo := 0.55             # basso sopra cui il mostro salta/trema
@export var soglia_laser := 0.8              # basso sopra cui PUÒ partire un laser
@export var probabilita_laser := 0.45        # non spara a ogni kick: "ogni tanto"
@export var pausa_laser := 1.5               # secondi minimi tra due raffiche
@export var durata_laser := 0.6
@export var fulmine_sullo_sparo := true      # fa partire anche il fulmine/zoom dello sfondo

var basso := 0.0
var colpo := 0.0          # impulso 1 -> 0 a ogni colpo di basso (salto + tremolio)
var laser := 0.0          # inviluppo 0..1 del laser
var laser_t := 1.0        # progresso raffica, >= 1 = spenta
var ang := 4.0
var ang0 := 4.0
var ang1 := 4.0
var lunghezza := 0.0
var ultimo_laser := -10.0
var mat: ShaderMaterial

const L := 32             # lato dello sprite in pixel

const FUNZIONI := """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
"""

const SHADER_MOSTRO := """
uniform sampler2D sprite : filter_nearest;
uniform float tempo = 0.0;
uniform float basso = 0.0;
uniform float colpo = 0.0;
uniform float laser = 0.0;
uniform float ang = 4.0;
uniform float lunghezza = 0.0;
uniform float pixel_v = 100.0;
uniform float scala = 1.0;
uniform float pos_x = 0.5;

const float L = 32.0;

// ondina che attraversa il corpo riga per riga: più forte col basso
float wob(float row) {
	float w = sin(tempo * 5.0 + row * 0.30) * (0.6 + basso * 2.2);
	float s = (hash(vec2(floor(tempo * 30.0), 1.0)) - 0.5) * 4.0 * colpo;
	return floor(w + s + 0.5);
}

// raggio "rotto" come i fulmini: segmenti con buchi + alone sgranato
float raggio(vec2 p, vec2 o, vec2 d, float w, float lung) {
	vec2 v = p - o;
	float t = dot(v, d);
	float dist = length(v - d * t);
	float gap = step(0.2, hash(vec2(floor(t / 7.0), floor(tempo * 22.0))));
	float core = step(dist, w) * gap;
	float g = exp(-dist * 0.40) * 0.6;
	float glow = step(hash(p + floor(tempo * 24.0)), g) * 0.5;
	float vivo = step(0.0, t) * step(t, lung);
	return clamp(core + glow, 0.0, 1.0) * vivo;
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float pk = res.y / pixel_v;
	vec2 vsize = floor(res / pk);
	vec2 vp = floor(UV * res / pk);
	vec2 pc = vp + 0.5;

	// posizione + dondolio + salto sul basso (tutto a pixel interi, stop-motion)
	float sway = floor(sin(tempo * 1.3) * 10.0);
	float bob = floor(1.5 + 1.5 * sin(floor(tempo * 8.0) / 8.0 * 3.0));
	float hop = floor(colpo * 4.0);
	vec2 org = vec2(floor(vsize.x * pos_x - L * scala * 0.5 + sway),
					floor(vsize.y * 0.96 - L * scala - hop - bob));

	vec2 sp = floor((pc - org) / scala);
	sp.x -= wob(sp.y);

	float glow = clamp(max(laser, basso * 0.6), 0.0, 1.0);
	glow *= 0.8 + 0.2 * step(0.5, hash(vec2(floor(tempo * 30.0), 4.0)));
	float apri = step(0.6, basso) + step(0.01, laser);
	float frame = min(apri, 1.0);

	vec3 col = vec3(0.0);
	float a = 0.0;

	if (sp.x >= 0.0 && sp.x < L && sp.y >= 0.0 && sp.y < L) {
		vec2 uvs = vec2((sp.x + 0.5) / L, (sp.y + frame * L + 0.5) / (2.0 * L));
		int idx = int(floor(texture(sprite, uvs).r * 255.0 + 0.5));
		float v = 0.0;
		if (idx == 1) v = 0.03;
		else if (idx == 2) v = 0.30 + basso * 0.10 + laser * 0.25;
		else if (idx == 3) v = 0.55 + basso * 0.10 + laser * 0.25;
		else if (idx == 4) v = 0.65 + 0.35 * glow;
		else if (idx == 5) v = 0.92;
		else if (idx == 6) v = 0.0;
		else if (idx == 7) v = mix(0.02, 1.0, glow);
		if (idx != 0) {
			col = vec3(v);
			a = 1.0;
		}
	}

	// occhi (coordinate sprite -> pixel virtuali), seguono l'ondina della riga 14
	float we = wob(14.0);
	vec2 eL = org + vec2(10.5 + we, 14.5) * scala;
	vec2 eR = org + vec2(21.5 + we, 14.5) * scala;

	// alone attorno agli occhi quando spara
	float h = max(exp(-length(pc - eL) * 0.30), exp(-length(pc - eR) * 0.30)) * laser;
	float halo = step(hash(pc + floor(tempo * 24.0) + 3.0), h * 0.8) * 0.6;
	col = mix(col, vec3(1.0), halo);
	a = max(a, halo);

	// laser: i due raggi divergono verso l'alto, a specchio
	if (laser > 0.01) {
		vec2 dL = vec2(cos(ang), sin(ang));
		vec2 dR = vec2(-dL.x, dL.y);
		float flick = 0.8 + 0.4 * step(0.5, hash(vec2(floor(tempo * 30.0), 9.0)));
		float w = (0.5 + 1.8 * laser) * flick * scala;
		float lung = lunghezza * 400.0;
		float b = max(raggio(pc, eL, dL, w, lung), raggio(pc, eR, dR, w, lung));
		col = mix(col, vec3(1.0), b);
		a = max(a, b);
	}

	COLOR = vec4(col, a);
}
"""


func _ready() -> void:
	mat = _schermo(SHADER_MOSTRO, layer_mostro)
	mat.set_shader_parameter("sprite", _crea_sprite())
	mat.set_shader_parameter("pixel_v", pixel_verticali)
	mat.set_shader_parameter("scala", scala)
	mat.set_shader_parameter("pos_x", posizione_x)


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


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var prev := basso

	if sfondo:
		basso = sfondo.basso
	else:
		# senza musica: kick finto circa ogni 0.6 s
		basso = exp(-fposmod(t * 1.7, 1.0) * 6.0)

	# colpo di basso -> salto + tremolio
	if basso > soglia_colpo and prev <= soglia_colpo:
		colpo = 1.0
	colpo = maxf(colpo - delta * 5.0, 0.0)

	# basso forte -> ogni tanto parte il laser
	if basso > soglia_laser and prev <= soglia_laser \
			and t - ultimo_laser > pausa_laser and randf() < probabilita_laser:
		spara()

	if laser_t < 1.0:
		laser_t += delta / durata_laser
		laser = smoothstep(0.0, 0.08, laser_t) * (1.0 - smoothstep(0.7, 1.0, laser_t))
		ang = lerpf(ang0, ang1, clampf(laser_t, 0.0, 1.0))
		lunghezza = clampf(laser_t * 8.0, 0.0, 1.0)
	else:
		laser = 0.0

	mat.set_shader_parameter("tempo", t)
	mat.set_shader_parameter("basso", basso)
	mat.set_shader_parameter("colpo", colpo)
	mat.set_shader_parameter("laser", laser)
	mat.set_shader_parameter("ang", ang)
	mat.set_shader_parameter("lunghezza", lunghezza)


# ---- chiamabile dalle scene ----

func spara() -> void:
	laser_t = 0.0
	ultimo_laser = Time.get_ticks_msec() / 1000.0
	# angolo del raggio sinistro: PI = orizzontale a sinistra, 1.5*PI = dritto in su
	ang0 = randf_range(1.05, 1.30) * PI
	ang1 = clampf(ang0 + randf_range(-0.3, 0.3) * PI, 1.05 * PI, 1.45 * PI)
	if fulmine_sullo_sparo and sfondo:
		sfondo.fulmine()
		sfondo.pulse()


# ---- sprite generato da codice (2 frame impilati: bocca chiusa / bocca aperta) ----
# indici: 0 vuoto, 1 contorno, 2 corpo, 3 corpo chiaro, 4 occhio, 5 denti, 6 interno bocca, 7 pupilla

func _crea_sprite() -> ImageTexture:
	var img := Image.create(L, L * 2, false, Image.FORMAT_R8)
	img.fill(Color(0, 0, 0))
	_disegna(img, 0, false)
	_disegna(img, L, true)
	return ImageTexture.create_from_image(img)


func _px(img: Image, x: int, y: int, idx: int) -> void:
	if x < 0 or y < 0 or x >= L or y >= img.get_height():
		return
	img.set_pixel(x, y, Color(idx / 255.0, 0, 0))


func _rect(img: Image, oy: int, x: int, y: int, w: int, h: int, idx: int) -> void:
	for yy in h:
		for xx in w:
			_px(img, x + xx, oy + y + yy, idx)


func _dentro(x: int, y: int) -> bool:
	var nx := (x - 15.5) / 13.5
	var ny := (y - 17.5) / 11.0
	return nx * nx + ny * ny <= 1.0


func _corno(img: Image, oy: int, specchia: bool) -> void:
	for i in 8:
		var w := 3 if i < 5 else (2 if i < 7 else 1)
		var x := 10 - int(i * 0.85)
		var y := 10 - i
		for dx in range(-1, w + 1):
			var idx := 1 if (dx < 0 or dx >= w) else 2
			var px := x + dx
			if specchia:
				px = L - 1 - px
			_px(img, px, oy + y, idx)
		if i == 7:
			var tx := (L - 1 - x) if specchia else x
			_px(img, tx, oy + y - 1, 1)


func _disegna(img: Image, oy: int, aperto: bool) -> void:
	# piedi (dietro il corpo)
	for fx in [8, 18]:
		_rect(img, oy, fx, 27, 6, 5, 1)
		_rect(img, oy, fx + 1, 27, 4, 4, 2)

	# corna
	_corno(img, oy, false)
	_corno(img, oy, true)

	# corpo ovale con contorno e luce in alto a sinistra
	for y in range(5, 32):
		for x in L:
			if _dentro(x, y):
				var bordo := not (_dentro(x - 1, y) and _dentro(x + 1, y) and _dentro(x, y - 1) and _dentro(x, y + 1))
				var idx := 1 if bordo else 2
				if not bordo and (x - 15.5) + (y - 17.5) < -9.0:
					idx = 3
				_px(img, x, oy + y, idx)

	# occhi: orbita scura, iride, pupilla che si accende col basso/laser
	for ex in [8, 19]:
		_rect(img, oy, ex, 12, 5, 5, 1)
		_rect(img, oy, ex + 1, 13, 3, 3, 4)
		_px(img, ex + 2, oy + 14, 7)

	# bocca
	if aperto:
		_rect(img, oy, 9, 19, 14, 8, 1)
		_rect(img, oy, 10, 20, 12, 6, 6)
		for x in range(10, 22):
			_px(img, x, oy + 20, 5 if x % 4 != 3 else 6)
			if x % 4 == 1 or x % 4 == 2:
				_px(img, x, oy + 21, 5)
			_px(img, x, oy + 25, 5 if x % 4 != 1 else 6)
			if x % 4 == 3 or x % 4 == 0:
				_px(img, x, oy + 24, 5)
	else:
		_rect(img, oy, 9, 20, 14, 4, 1)
		_rect(img, oy, 10, 21, 12, 2, 6)
		for x in range(10, 22):
			if x % 3 != 0:
				_px(img, x, oy + 21, 5)
			else:
				_px(img, x, oy + 22, 5)
