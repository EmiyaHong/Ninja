@tool
extends Node2D

var preview_font := SystemFont.new()

# Editor-only framing. Real actors below Battle are also used by the running game.
func _ready() -> void:
	preview_font.font_names = PackedStringArray(["Microsoft YaHei"])
	visible = Engine.is_editor_hint()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	draw_rect(Rect2(0, 0, 1152, 768), Color("111c2a"))
	for x in range(0, 1152, 48):
		draw_line(Vector2(x, 160), Vector2(x, 640), Color("192838"))
	for y in range(160, 641, 48):
		draw_line(Vector2(0, y), Vector2(1152, y), Color("192838"))
	draw_rect(Rect2(0, 0, 1152, 768), Color("63808f"), false, 2)
	draw_string(preview_font, Vector2(40, 45), "场景预览 · F5 运行游戏", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("d4e3e9"))
	draw_string(preview_font, Vector2(40, 713), "在场景树选择 PlayerBody / BossBody 可调整站位。战斗界面运行时显示。", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("bac9dc"))
	var player := get_parent().get_node_or_null("PlayerBody") as Node2D
	if player == null: return
	var tip := player.position + Vector2(84, -13)
	draw_rect(Rect2(tip + Vector2(-5, 0), Vector2(10, 110)), Color("8de4ef"))
	draw_line(tip + Vector2(0, 110), tip + Vector2(0, 132), Color("cf9b61"), 9)
	draw_line(tip + Vector2(-12, 110), tip + Vector2(12, 110), Color("f0d9ac"), 5)
	draw_circle(tip, 4, Color.WHITE)

