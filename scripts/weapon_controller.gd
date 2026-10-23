extends Node2D

var tip := Vector2.ZERO
var tangent := Vector2.UP
var trail := PackedVector2Array()
var active := false
@export var blade_length := 110.0
@export var blade_width := 10.0
@export var tint := Color("76e9ed")
@export_group("Replaceable blade visual")
@export var blade_texture: Texture2D
@export var texture_tip := Vector2(110, 5)
@export var visual_scale := Vector2.ONE
@export var blade_visual_scene: PackedScene
@export_group("Trail appearance only")
@export var trail_material: Material
@export var trail_texture: Texture2D
@export_range(0.1, 100.0) var trail_width := 3.0
@export var trail_color := Color(0.46, 0.91, 0.93, 0.38)
@onready var trail_line: Line2D = $Trail
@onready var blade_pivot: Node2D = $BladePivot
@onready var visual: Node2D = $BladePivot/Visual
@onready var tip_marker: Marker2D = $BladePivot/Tip

func _ready() -> void:
	apply_appearance()

func apply_appearance() -> void:
	trail_line.material = trail_material
	trail_line.texture = trail_texture
	trail_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	trail_line.width = trail_width
	trail_line.default_color = trail_color
	if trail_line.has_method("sync_appearance"):
		trail_line.sync_appearance()
	for child in visual.get_children():
		visual.remove_child(child)
		child.queue_free()
	visual.scale = visual_scale
	if blade_visual_scene != null:
		visual.add_child(blade_visual_scene.instantiate())
	elif blade_texture != null:
		var sprite := Sprite2D.new()
		sprite.name = "BladeSprite"
		sprite.texture = blade_texture
		sprite.centered = false
		sprite.position = -texture_tip
		visual.add_child(sprite)
	queue_redraw()

func follow(point: Vector2, direction: Vector2, drawing: bool) -> void:
	tip = point
	if direction.length_squared() > 0.001:
		tangent = direction.normalized()
	active = drawing
	if drawing:
		trail.append(point)
		trail_line.add_point(point)
		if trail_line.has_method("record_point"):
			trail_line.record_point(point)
	blade_pivot.position = tip
	blade_pivot.rotation = tangent.angle()
	queue_redraw()

func clear(rest: Vector2, fade_trail: bool = false) -> void:
	if trail_line.has_method("reset_trail"):
		trail_line.reset_trail(fade_trail)
	trail.clear()
	trail_line.clear_points()
	tip = rest
	tangent = Vector2.UP
	active = false
	follow(rest, Vector2.UP, false)

func _draw() -> void:
	if blade_texture == null and blade_visual_scene == null:
		var base := tip - tangent * blade_length
		var normal := tangent.orthogonal() * blade_width * 0.5
		draw_colored_polygon(PackedVector2Array([base + normal, tip + normal, tip - normal, base - normal]), tint)
		draw_line(base - tangent * 22.0, base, Color("cf9b61"), 9.0, true)
		draw_line(base - normal * 2.3, base + normal * 2.3, Color("f0d9ac"), 5.0, true)
	draw_circle(tip, 4.0, Color.WHITE)
