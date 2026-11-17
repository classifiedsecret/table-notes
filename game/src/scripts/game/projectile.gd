class_name Projectile
extends Node2D
## An arrow or dart. When it reaches Boar-vhal it makes an attack roll against his AC.

var game: Node
var vel := Vector2.ZERO
var data := {"name": "Arrow"}
var weapon := {}
var color := Color(0.85, 0.75, 0.55)
var _life := 3.0


static func fire(g: Node, from: Vector2, velocity: Vector2, shooter: String, wpn: Dictionary, col: Color) -> Projectile:
	var p := Projectile.new()
	p.game = g
	p.position = from
	p.vel = velocity
	p.data = {"name": shooter}
	p.weapon = wpn
	p.color = col
	p.z_index = 5
	g.add_child(p)
	return p


func _physics_process(delta: float) -> void:
	position += vel * delta
	_life -= delta
	rotation = vel.angle()
	var room: Room = game.room
	if _life <= 0.0 or room.is_solid_cell(floori(position.x / Room.T), floori(position.y / Room.T)):
		queue_free()
		return
	var p: Player = game.player
	if p != null and not p.is_down() and p.hurt_rect().has_point(global_position):
		if not p.is_invulnerable():
			p.receive_attack(self, weapon)
			queue_free()


func _draw() -> void:
	draw_line(Vector2(-6, 0), Vector2(4, 0), color, 1.0)
	draw_line(Vector2(4, 0), Vector2(1, -2), Color(0.9, 0.9, 0.95), 1.0)
	draw_line(Vector2(4, 0), Vector2(1, 2), Color(0.9, 0.9, 0.95), 1.0)
	draw_line(Vector2(-6, 0), Vector2(-8, -2), Color(0.8, 0.3, 0.25), 1.0)
	draw_line(Vector2(-6, 0), Vector2(-8, 2), Color(0.8, 0.3, 0.25), 1.0)
