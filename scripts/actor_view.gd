@tool
extends Node2D

@export var tint := Color("66ced7")
@export var actor_scale := 1.0
@export var head_texture: Texture2D
@export var body_texture: Texture2D
@export var actor_visual_scene: PackedScene
@export var head_offset := Vector2(0, -45)
@export var body_offset := Vector2(0, 18)
@export var left_shoulder_position := Vector2(-26, -12)
@export var right_shoulder_position := Vector2(26, -12)
var flash := 0.0
@onready var visual_root: Node2D = $VisualRoot

func _ready() -> void:
	if Engine.is_editor_hint():
		visual_root.scale = Vector2.ONE * actor_scale
		set_process(false)
		queue_redraw()
		return
	apply_appearance()

func apply_appearance() -> void:
	# Reuse a scene-authored visual instead of duplicating the editor's bear.
	var reuse_visual := false
	if actor_visual_scene != null and visual_root.get_child_count() == 1:
		var existing := visual_root.get_child(0)
		reuse_visual = not actor_visual_scene.resource_path.is_empty() and existing.scene_file_path == actor_visual_scene.resource_path
	if not reuse_visual:
		for child in visual_root.get_children():
			visual_root.remove_child(child)
			child.queue_free()
	visual_root.scale = Vector2.ONE * actor_scale
	if actor_visual_scene != null and not reuse_visual:
		visual_root.add_child(actor_visual_scene.instantiate())
	elif actor_visual_scene == null:
		_add_sprite("Head", head_texture, head_offset)
		_add_sprite("Body", body_texture, body_offset)
	# Both sockets are optional; floating weapons never depend on them.
	for side in ["LeftShoulder", "RightShoulder"]:
		var socket := get_node_or_null(side) as Node2D
		if socket != null:
			socket.position = (left_shoulder_position if side == "LeftShoulder" else right_shoulder_position) * actor_scale
			socket.scale = Vector2.ONE * actor_scale
	queue_redraw()

func _add_sprite(node_name: String, texture: Texture2D, at: Vector2) -> void:
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.position = at
	visual_root.add_child(sprite)

func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	visual_root.modulate = Color.WHITE.lerp(Color(2, 2, 2), minf(flash * 4.0, 0.9))
	queue_redraw()

func _draw() -> void:
	if actor_visual_scene != null:
		return
	var color := tint.lerp(Color.WHITE, minf(flash * 4.0, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * actor_scale)
	if head_texture == null:
		draw_circle(Vector2(0, -45), 23.0, color)
		draw_line(Vector2(-9, -48), Vector2(-4, -48), Color("13232e"), 4)
		draw_line(Vector2(4, -48), Vector2(9, -48), Color("13232e"), 4)
	if body_texture == null:
		draw_rect(Rect2(-26, -17, 52, 70), color)
