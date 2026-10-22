@tool
class_name SfondoVintage
extends ColorRect

@export var tinta: Color = Color("f6f0e0"):               # bianco carta, leggermente caldo
	set(v): tinta = v; _aggiorna()
@export_range(0.05, 0.5) var bordo: float = 0.25:         # quanto entra il nero dai lati
	set(v): bordo = v; _aggiorna()
@export_range(0.0, 1.0) var buio_bordo: float = 0.9:
	set(v): buio_bordo = v; _aggiorna()
@export_range(0.0, 0.3) var grana: float = 0.08:
	set(v): grana = v; _aggiorna()
@export_range(0.0, 1.0) var graffi: float = 0.5:
	set(v): graffi = v; _aggiorna()
@export_range(0.0, 0.1) var flicker: float = 0.03:        # tremolio di luce da pellicola
	set(v): flicker = v; _aggiorna()

const SHADER_CODE := """
shader_type canvas_item;

uniform vec4 tinta : source_color = vec4(0.96, 0.94, 0.88, 1.0);
uniform float bordo = 0.25;
uniform float buio_bordo = 0.9;
uniform float grana = 0.08;
uniform float graffi = 0.5;
uniform float flicker = 0.03;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = tinta.rgb;

	// macchie di carta vecchia
	float macchie = noise(uv * vec2(5.0, 7.0)) * 0.6 + noise(uv * 22.0) * 0.4;
	col *= 1.0 - macchie * 0.14;
	col = mix(col, col * vec3(1.0, 0.93, 0.8), macchie * 0.5);   // ingiallimento

	// grana da pellicola, cambia 12 volte al secondo
	float t = floor(TIME * 12.0);
	col += (hash(uv * vec2(900.0, 700.0) + t) - 0.5) * grana;

	// graffi verticali che compaiono a caso
	float slot = floor(TIME * 8.0);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float x = hash(vec2(slot, fi));
		float on = step(0.65, hash(vec2(slot, fi + 10.0)));
		float h = hash(vec2(slot, fi + 20.0));
		float line = (1.0 - smoothstep(0.0, 0.0012, abs(uv.x + (noise(vec2(uv.y * 30.0, fi)) - 0.5) * 0.004 - x)));
		line *= on * step(abs(uv.y - h), 0.35);
		col -= line * graffi * 0.35;
	}

	// polvere
	float polvere = step(0.9985, hash(floor(uv * vec2(260.0, 160.0)) + slot));
	col -= polvere * graffi * 0.4;

	// bordi neri sfumati ai lati
	float lato = smoothstep(0.0, bordo, uv.x) * smoothstep(0.0, bordo, 1.0 - uv.x);
	lato = pow(lato, 1.4);
	float angoli = smoothstep(0.0, 0.18, uv.y) * smoothstep(0.0, 0.18, 1.0 - uv.y);
	float luce = mix(lato, lato * angoli, 0.35);
	col = mix(vec3(0.0), col, 1.0 - (1.0 - luce) * buio_bordo);

	// tremolio di luce
	col *= 1.0 + (hash(vec2(floor(TIME * 14.0), 3.0)) - 0.5) * flicker * 2.0;

	COLOR = vec4(col, 1.0);
}
"""

var _mat: ShaderMaterial


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	material = _mat
	_aggiorna()


func _aggiorna() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("tinta", tinta)
	_mat.set_shader_parameter("bordo", bordo)
	_mat.set_shader_parameter("buio_bordo", buio_bordo)
	_mat.set_shader_parameter("grana", grana)
	_mat.set_shader_parameter("graffi", graffi)
	_mat.set_shader_parameter("flicker", flicker)
