extends SceneTree
var b: Node
func _initialize() -> void: run.call_deferred()
func key(k: int, physical: int = 0) -> void:
 var e := InputEventKey.new()
 e.keycode = k
 e.physical_keycode = physical
 e.pressed = true
 Input.parse_input_event(e)
 await process_frame
 e.pressed = false
 Input.parse_input_event(e)
 await process_frame
func click(p: Vector2) -> void:
 var e := InputEventMouseButton.new()
 e.button_index = MOUSE_BUTTON_LEFT
 e.position = p
 e.pressed = true
 Input.parse_input_event(e)
 await process_frame
 e.pressed = false
 Input.parse_input_event(e)
 await process_frame
func state(label: String) -> void:
 print(label,': mode=',b.mode,' paused=',b.paused,' enabled=',b.gesture.enabled,' direct=',b.gesture.direct_control,' hp=',b.player_hp,' result=',b.result,' focus=',root.gui_get_focus_owner())

var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
 checks += 1
 state(label)
 if not ok: failures.append(label); push_error(label)
func mouse(p: Vector2, down: bool) -> void:
 var e := InputEventMouseButton.new()
 e.button_index = MOUSE_BUTTON_LEFT
 e.pressed = down
 e.position = p
 Input.parse_input_event(e)
 await create_timer(0.02).timeout
func swipe(d: Vector2) -> void:
 var p := Vector2(140,550)
 await mouse(p,true)
 for n in [10,30,50]:
  var e := InputEventMouseMotion.new()
  e.position = p + d*n
  e.button_mask = MOUSE_BUTTON_MASK_LEFT
  Input.parse_input_event(e)
  await create_timer(0.02).timeout
 await mouse(p+d*50,false)
func capture(path: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run() -> void:
 b=load('res://scenes/battle.tscn').instantiate()
 root.add_child(b)
 await create_timer(0.3).timeout
 check(b.mode==0 and b.is_processing(),'normal startup')
 await key(KEY_1); await key(KEY_5)
 check(b.mode==4 and b.tuning.player_health==100,'1-5')
 await key(KEY_1)
 check(b.mode==0 and b.gesture.direct_control and b.player_hp==10000,'5-1 restores tuning')
 await click(Vector2(440,128))
 check(b.mode==4 and root.gui_get_focus_owner()!=null,'click5 focus')
 await key(KEY_1)
 check(b.mode==0,'focused keyboard1')
 await key(0,KEY_5)
 check(b.mode==4,'physical5')
 await key(KEY_KP_1)
 check(b.mode==0,'keypad1')
 await mouse(Vector2(100,550),true)
 var m := InputEventMouseMotion.new(); m.position=Vector2(250,450)
 Input.parse_input_event(m)
 await create_timer(0.03).timeout
 check(b.player_weapon.tip.distance_to(b.clamp_tip(Vector2(250,450)))<1,'original tip follows actual pointer')
 await mouse(Vector2(250,450),false)
 await key(KEY_ESCAPE)
 check(b.paused and not b.gesture.enabled,'esc pauses')
 await key(KEY_5)
 check(b.mode==4 and not b.paused,'mode shortcut exits pause safely')
 await swipe(Vector2.RIGHT)
 await create_timer(0.3).timeout
 check(b.boss_hp==290 and b.settlement_count==1,'real clock normal strike one damage')
 await capture('res://docs/screenshots/interaction-directional-real-clock.png')
 for i in range(3):
  while b.boss.phase!='windup' or b.boss.deadline-b.now()>0.15:
   await process_frame
  var previous: int = b.parry_count
  await swipe(-b.boss.direction)
  check(b.parry_count==previous+1,'normal clock parry '+str(i))
 await key(KEY_R)
 check(b.player_hp==100 and b.parry_count==0 and b.result.is_empty(),'R reset')
 await key(KEY_ESCAPE); await key(KEY_ESCAPE)
 check(not b.paused and b.gesture.enabled,'pause resume')
 # Let the normal timeline deliver all five missed attacks, without altering HP.
 while b.result.is_empty(): await process_frame
 check(b.player_hp==0 and not b.directional.active,'normal timeline death')
 await key(KEY_1)
 check(b.mode==0 and b.player_hp==10000 and b.gesture.enabled,'1 recovers after defeat')
 await capture('res://docs/screenshots/interaction-original-restored.png')
 await key(KEY_R)
 check(b.result.is_empty() and not b.paused,'R in original mode')
 print('INTERACTION_TESTS: %d checks, %d failures: %s' % [checks,failures.size(),failures])
 quit(0 if failures.is_empty() else 1)
