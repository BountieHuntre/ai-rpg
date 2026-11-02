class_name OrbitCamera
extends Camera3D
## Classic WoW camera. Left drag orbits, right drag also steers the player, the
## wheel zooms smoothly from first person out to 15 yards, keyboard turning
## carries the camera with the player, and after orbiting it swings back
## behind the player once they move ("only when moving" follow style).

## Emitted for a mouse press and release without dragging.
signal clicked(screen_position: Vector2, button: MouseButton)

const CLICK_DRAG_LIMIT := 8.0
## Closer than this is first person, with the character hidden.
const FIRST_PERSON_DISTANCE := 0.6

@export var target: Player
## Pivot at eye height.
@export var height := 1.6
@export var distance := 8.0
@export var min_distance := 0.0
## Classic's default maximum zoom.
@export var max_distance := 15.0
@export var zoom_step := 1.5
@export var zoom_speed := 10.0
@export var mouse_sensitivity := 0.002
@export var min_pitch_degrees := -85.0
@export var max_pitch_degrees := 60.0
@export var return_speed := 5.0
@export var collision_margin := 0.3
@export_flags_3d_physics var collision_mask := 1

var yaw := 0.0
var pitch := deg_to_rad(-20.0)

var _zoom_target := distance
var _orbiting := false
var _steering := false
var _last_facing := 0.0
var _returning := false
var _press_position := Vector2.ZERO
var _dragged := 0.0


func is_steering() -> bool:
	return _steering


## Holding both mouse buttons runs forward, as in WoW.
func is_auto_running() -> bool:
	return _orbiting and _steering


func snap_to_target() -> void:
	_zoom_target = distance
	yaw = target.facing
	_last_facing = target.facing
	_update_transform()


## Takes raw window-space mouse events. The root scene passes them in, because
## forwarding through the scaled game view would change drag speed with pixel scale.
func handle_mouse(event: InputEventMouse) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var is_drag_button := button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
		if is_drag_button and button.pressed and not _orbiting and not _steering:
			_press_position = button.position
			_dragged = 0.0
		elif is_drag_button and not button.pressed and _dragged < CLICK_DRAG_LIMIT:
			clicked.emit(_press_position, button.button_index)
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				_orbiting = button.pressed
			MOUSE_BUTTON_RIGHT:
				_steering = button.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_target = maxf(_zoom_target - zoom_step, min_distance)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_target = minf(_zoom_target + zoom_step, max_distance)
		_update_mouse_mode()
	elif event is InputEventMouseMotion and (_orbiting or _steering):
		var motion := event as InputEventMouseMotion
		_dragged += motion.relative.length()
		if _dragged < CLICK_DRAG_LIMIT:
			return
		_update_mouse_mode()
		yaw -= motion.relative.x * mouse_sensitivity
		pitch = clampf(
			pitch - motion.relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_orbiting = false
		_steering = false
		_update_mouse_mode()


func _physics_process(delta: float) -> void:
	if not target:
		return
	var turned := angle_difference(_last_facing, target.facing)
	_last_facing = target.facing
	var moving := Vector2(target.velocity.x, target.velocity.z).length() > 0.1
	if _orbiting or _steering:
		_returning = false
	else:
		yaw += turned
		if moving:
			_returning = true
	if _returning:
		yaw = lerp_angle(yaw, target.facing, 1.0 - exp(-return_speed * delta))
	distance = move_toward(distance, _zoom_target, maxf(absf(_zoom_target - distance), 0.5) * zoom_speed * delta)
	target.set_model_visible(distance > FIRST_PERSON_DISTANCE)
	_update_transform()


func _update_transform() -> void:
	var view := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var pivot := target.global_position + Vector3.UP * height
	global_transform = Transform3D(view, pivot + view.z * _clear_distance(pivot, view.z))


## Pulls the camera in when level geometry would block the view of the player.
func _clear_distance(pivot: Vector3, back: Vector3) -> float:
	if distance <= FIRST_PERSON_DISTANCE:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(pivot, pivot + back * distance, collision_mask)
	query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return distance
	return maxf(pivot.distance_to(hit.position) - collision_margin, 0.2)


func _update_mouse_mode() -> void:
	var held := _orbiting or _steering
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if held and not captured and _dragged >= CLICK_DRAG_LIMIT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not held and captured:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.warp_mouse(_press_position)
