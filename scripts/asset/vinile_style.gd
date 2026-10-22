@tool
class_name Vinile
extends TextureRect

@export var spinning: bool = true
@export var spin_speed: float = 1.5          # radianti al secondo
@export_range(0.1, 0.6) var label_radius: float = 0.34
@export_range(0.0, 0.1) var hole_radius: float = 0.03
@export var groove_freq: float = 140.0
@export var vinyl_color: Color = Color("080808")
@export_range(0.0, 0.5) var sheen_strength: float = 0.18

@export var bloccata: bool = false:
	set(v):
		bloccata = v
		if is_node_ready():
			_aggiorna_blocco()
@export_range(0.3, 1.0) var cover_visibile: float = 0.8:   # quanta larghezza copre la cover
	set(v):
		cover_visibile = v
		_adatta_cover()
@export_range(0.0, 1.0) var cover_dim: float = 0.0          # 0 = immagine pura, 1 = nera

const SHADER_CODE := """
shader_type canvas_item;

uniform float angle = 0.0;
uniform float label_radius = 0.34;
uniform float hole_radius = 0.03;
uniform float groove_freq = 140.0;
uniform vec4 vinyl_color : source_color = vec4(0.03, 0.03, 0.03, 1.0);
uniform float sheen_strength = 0.18;
uniform sampler2D noise;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fuoco : source_color = vec4(1.0, 0.35, 0.0, 1.0);
uniform float larghezza = 0.15;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float d = length(p);
	float aa = fwidth(d);

	float disc = 1.0 - smoothstep(1.0 - aa, 1.0, d);
	float hole = smoothstep(hole_radius - aa, hole_radius, d);

	vec3 col;
	if (d < label_radius) {
		// label: la cover ruota
		float c = cos(angle);
		float s = sin(angle);
		vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y) / label_radius;
		col = texture(TEXTURE, q * 0.5 + 0.5).rgb;
	} else {
		// solchi + riflesso fisso (non gira, fa più realistico)
		float grooves = sin(d * groove_freq) * 0.5 + 0.5;
		col = vinyl_color.rgb + grooves * 0.03;

		float a = atan(p.y, p.x);
		float sheen = pow(abs(cos(a * 2.0 - 0.8)), 24.0);
		float ring = smoothstep(label_radius, label_radius + 0.02, d);
		col += vec3(1.0) * sheen * sheen_strength * ring * (0.6 + 0.4 * grooves);

		// bordo scuro tra label e vinile
		col *= smoothstep(label_radius, label_radius + 0.012, d) * 0.7 + 0.3;
	}

	vec4 c = vec4(col, disc * hole);

	float v = texture(noise, UV).r * 0.6 + (1.0 - UV.y) * 0.4;   // dal basso verso l'alto
	float k = v - (progress * (1.0 + larghezza) - larghezza);
	if (k < 0.0) {
		c.a = 0.0;
	} else if (k < larghezza) {
		float f = k / larghezza;
		vec3 brace = mix(vec3(1.0, 0.9, 0.4), fuoco.rgb, f);
		brace = mix(brace, vec3(0.6, 0.17, 1.0), f * f);         // bordo viola neon
		c.rgb = mix(brace * 1.6, c.rgb, f * f);
	}
	COLOR = c;
}
"""

var _mat: ShaderMaterial
var _angle: float = 0.0
var _cover: Control
var _ultima_tex: Texture2D


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	material = _mat
	var rumore := NoiseTexture2D.new()
	rumore.noise = FastNoiseLite.new()
	_mat.set_shader_parameter("noise", rumore)

	resized.connect(_adatta_cover)
	_aggiorna_blocco()
	_update_params()


func _process(delta: float) -> void:
	if spinning:
		_angle = fmod(_angle + spin_speed * delta, TAU)
	_update_params()

	# se cambi texture la cover si ridisegna
	if is_instance_valid(_cover) and texture != _ultima_tex:
		_ultima_tex = texture
		_cover.queue_redraw()


func _update_params() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("angle", _angle)
	_mat.set_shader_parameter("label_radius", label_radius)
	_mat.set_shader_parameter("hole_radius", hole_radius)
	_mat.set_shader_parameter("groove_freq", groove_freq)
	_mat.set_shader_parameter("vinyl_color", vinyl_color)
	_mat.set_shader_parameter("sheen_strength", sheen_strength)


func set_fuoco(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("progress", v)


# ---------- COVER ----------

func _aggiorna_blocco() -> void:
	if bloccata:
		if not is_instance_valid(_cover):
			_crea_cover()
		_cover.modulate.a = 1.0
		_adatta_cover()
	elif is_instance_valid(_cover):
		_cover.queue_free()
		_cover = null


func _crea_cover() -> void:
	_cover = Control.new()
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.draw.connect(_disegna_cover)
	add_child(_cover)


func _adatta_cover() -> void:
	if not is_instance_valid(_cover):
		return
	_cover.position = Vector2.ZERO
	_cover.size = Vector2(size.x * cover_visibile, size.y)
	_cover.queue_redraw()


func _disegna_cover() -> void:
	var r := Rect2(Vector2.ZERO, _cover.size)
	if texture:
		var ts := texture.get_size()
		# taglia la texture alla stessa percentuale, così non si schiaccia
		var src := Rect2(Vector2.ZERO, Vector2(ts.x * cover_visibile, ts.y))
		var tint := Color(1, 1, 1).darkened(cover_dim)
		_cover.draw_texture_rect_region(texture, r, src, tint)
	else:
		_cover.draw_rect(r, Color("1b1b24"))
	_cover.draw_rect(r, Color(0, 0, 0, 0.35), false, 2.0)   # bordino sottile


func sblocca() -> void:
	if not bloccata or not is_instance_valid(_cover):
		return
	var c := _cover
	var t := create_tween().set_parallel(true)
	t.tween_property(c, "position:x", -c.size.x, 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(c, "modulate:a", 0.0, 0.6)
	await t.finished
	_cover = null        # prima lo scollego, poi lo elimino
	if is_instance_valid(c):
		c.queue_free()
	bloccata = false
