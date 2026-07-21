extends Area2D
class_name BaseEnemy

## 敵キャラクターのベースクラス（共通のHP管理、被ダメージ、破壊演出を処理）

@export var max_hp: int = 10
var current_hp: int

func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemy")
	_ready_enemy()

## 子クラスで初期化処理を行うための仮想メソッド
func _ready_enemy() -> void:
	pass

## ダメージ処理（スコア加算とポップアップ演出を共通化）
func take_damage(amount: int) -> void:
	current_hp -= amount
	var is_dead = current_hp <= 0
	
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("add_damage_score"):
			manager.add_damage_score(amount)
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_damage_popup"):
			ui_node.spawn_damage_popup(global_position, amount, is_dead)
			
	if is_dead:
		die()

## 撃破時の処理（子クラスでオーバーライド可能）
func die() -> void:
	# 敵撃破時に短く超巨大なテキスト演出（"DESTROY!"）を生成
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_kill_popup"):
			ui_node.spawn_kill_popup(global_position, "DESTROY!")
			
	explode()
	queue_free()

## 爆発演出（パーティクル生成）
func explode() -> void:
	var ParryParticleScene = load("res://game/bullets/parry_particle.tscn")
	if ParryParticleScene:
		var particle = ParryParticleScene.instantiate()
		particle.global_position = global_position
		particle.modulate = modulate
		get_parent().add_child(particle)
