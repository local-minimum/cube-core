extends Node
class_name EndBlob

@export var player: AnimationPlayer

func _ready() -> void:
    player.play("Idle")
