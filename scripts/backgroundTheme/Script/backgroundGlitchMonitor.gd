class_name backgroundGlitchMonitor
extends Node

@export var velocita := 0.08          # scorrimento base (menu lento, gioco ~0.5)
@export var respiro := 0.35           # pulsazione automatica quando non c'è musica collegata
@export var saturazione := 0.35       # 0.12 = look duro, 0.35 = UI leggibile
@export var effetto_schermo := true   # grana, graffi, vignettatura
@export var layer_tunnel := -2
@export var layer_fx := -1

var combo := 0                        # lo setta la scena di gioco
var viaggio := 0.0
var basso := 0.0
var analizzatore: AudioEffectSpectrumAnalyzerInstance
var effetto_analisi: AudioEffectSpectrumAnalyzer
var bus_idx := -1
var mat_tunnel: ShaderMaterial
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

const SHADER_TUNNEL := """
uniform float viaggio = 0.0;
uniform float basso = 0.0;
uniform float pulse = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.1, 0.15, 1.0);
uniform float tint_amount = 0.0;

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (UV - 0.5) * vec2(res.x / res.y, 1.0);
	float r = max(length(p) * (1.0 - basso * 0.10), 0.0001);
	float z = 0.3 / r + viaggio;
	vec2 d = p / r;
	float anelli = smoothstep(0.42, 0.5, abs(fract(z * 1.2) - 0.5));
	float spicchi = smoothstep(0.46, 0.5, abs(fract(atan(p.y, p.x) / 6.28318 * 10.0) - 0.5));
	float muro = noise(d * 2.5 + vec2(z * 0.8, z * 0.35));
	float v = 0.05 + muro * 0.10 + anelli * (0.07 + basso * 0.20) + spicchi * 0.05;
	float centro = smoothstep(0.02, 0.45, r);
	v *= centro;
	v *= 1.0 + pulse * 1.2 + basso * 0.7;
	vec3 col = vec3(v) + tint.rgb * tint_amount * (0.15 + anelli * 0.5) * centro;
	COLOR = vec4(col, 1.0);
}
"""

const SHADER_FX := """
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float tempo = 0.0;
uniform float sat = 0.35;
uniform float chroma = 0.0;

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float f = floor(tempo * 24.0);
	float g = floor(tempo * 8.0);
	vec2 uv = SCREEN_UV + vec2((hash(vec2(f, 1.0)) - 0.5) * 0.002, 0.0);
	float ca = 0.0012 + chroma * 0.01;
	vec3 col = vec3(
		texture(screen_tex, uv + vec2(ca, 0.0)).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - vec2(ca, 0.0)).b);

	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, sat);
	col = col * 0.9 + 0.035;
	col *= 0.8 + 0.4 * noise(SCREEN_UV * vec2(4.0, 7.0) + 3.0);
	col += (hash(SCREEN_UV * res + f) - 0.5) * 0.13;

	float x = floor(SCREEN_UV.x * 260.0);
	col += step(0.996, hash(vec2(x, floor(tempo * 5.0)))) * 0.2;
	col += step(0.9992, hash(floor(SCREEN_UV * res / 3.0) + g * 0.37)) * 0.5;

	col *= 0.94 + 0.06 * sin(SCREEN_UV.y * res.y * 3.14159);
	col *= 1.0 - 0.05 * hash(vec2(f, 7.0));
	col *= smoothstep(1.0, 0.3, length(SCREEN_UV - 0.5) * 1.35);
	COLOR = vec4(col, 1.0);
}
"""


func _ready() -> void:
	mat_tunnel = _schermo(SHADER_TUNNEL, layer_tunnel)
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


# fa pulsare il tunnel col basso di questa musica
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
	if analizzatore:
		var mag := analizzatore.get_magnitude_for_frequency_range(30.0, 150.0).length()
		var target := clampf(remap(linear_to_db(maxf(mag, 0.00001)), -40.0, -12.0, 0.0, 1.0), 0.0, 1.0)
		basso = lerpf(basso, target, 1.0 - exp(-delta * (30.0 if target > basso else 6.0)))
	else:
		basso = (0.5 + 0.5 * sin(t * 0.6)) * respiro

	viaggio += delta * (velocita + minf(combo, 30) * 0.03 + (basso * 1.2 if analizzatore else 0.0))
	mat_tunnel.set_shader_parameter("viaggio", viaggio)
	mat_tunnel.set_shader_parameter("basso", basso)
	if mat_fx:
		mat_fx.set_shader_parameter("tempo", t)


# ---- chiamabili dalle scene ----

func pulse() -> void:
	create_tween().tween_method(func(v): mat_tunnel.set_shader_parameter("pulse", v), 1.0, 0.0, 0.3)


func burst_colore(c: Color) -> void:
	mat_tunnel.set_shader_parameter("tint", c)
	var tw := create_tween().set_parallel()
	tw.tween_method(func(v): mat_tunnel.set_shader_parameter("tint_amount", v), 1.0, 0.0, 0.9)
	if mat_fx:
		tw.tween_method(func(v): mat_fx.set_shader_parameter("sat", v), 0.9, saturazione, 0.7)
		tw.tween_method(func(v): mat_fx.set_shader_parameter("chroma", v), 1.0, 0.0, 0.4)
