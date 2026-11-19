extends Node2D
const Walls=preload("res://scripts/wall_art.gd")
func _draw()->void:
 Walls.piece(self,Vector2(-20,0),{Vector2i(1,0):true})
 Walls.piece(self,Vector2(20,0),{Vector2i(-1,0):true})
