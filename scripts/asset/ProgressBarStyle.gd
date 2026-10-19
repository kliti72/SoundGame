@tool
extends ProgressBar

@export var spike_size: float = 10.0       # quanto escono le spine
@export var spike_base: float = 16.0       # larghezza alla base della spina
@export var bg_color: Color = Color("0a0a0a")
@export var fill_color: Color = Color("c4001a")
@export var border_color: Color = Color("e8e8e8")
@export var border_width: float = 2.0

func _ready() -> void:
	show_percentage = false
	# togliamo lo stile di default, qui disegniamo noi
	add_theme_stylebox_override("background", StyleBoxEmpty.new())
	add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	value_changed.connect(func(_v): queue_redraw())
	resized.connect(queue_redraw)

func _build_shape() -> PackedVector2Array:
	var w := size.x
	var h := size.y
	var m := spike_size
	var b := spike_base
	return PackedVector2Array([
		# angolo alto-sinistra
		Vector2(m, m + b), Vector2(0, 0), Vector2(m + b, m),
		# angolo alto-destra
		Vector2(w - m - b, m), Vector2(w, 0), Vector2(w - m, m + b),
		# angolo basso-destra
		Vector2(w - m, h - m - b), Vector2(w, h), Vector2(w - m - b, h - m),
		# angolo basso-sinistra
		Vector2(m + b, h - m), Vector2(0, h), Vector2(m, h - m - b),
	])

func _draw() -> void:
	var shape := _build_shape()

	# sfondo
	draw_colored_polygon(shape, bg_color)

	# fill: la forma tagliata in base al valore
	var ratio := get_as_ratio()
	if ratio > 0.0:
		var clip := PackedVector2Array([
			Vector2(0, 0), Vector2(size.x * ratio, 0),
			Vector2(size.x * ratio, size.y), Vector2(0, size.y),
		])
		for poly in Geometry2D.intersect_polygons(shape, clip):
			if poly.size() >= 3:
				draw_colored_polygon(poly, fill_color)

	# bordo affilato
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, border_color, border_width, true)
