extends Area2D

@export_file("*.tscn") var target_scene: String = ""
@export var one_shot: bool = true

var _is_switching: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _is_switching:
		return
	if target_scene.is_empty():
		return
	if not body.is_in_group("player"):
		return

	_is_switching = true
	get_tree().change_scene_to_file(target_scene)

	if not one_shot:
		_is_switching = false
