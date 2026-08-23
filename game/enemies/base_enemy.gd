extends Area2D
class_name BaseEnemy

## 敵キャラクターのベースクラス（共通のHP管理、被ダメージ、破壊演出を処理）

@export var max_hp: int = 10
var current_hp: int
var is_alive: bool = true

func _ready() -> void:
	current_hp = max_hp
	is_alive = true
	add_to_group("enemy")
	_ready_enemy()

## 子クラスで初期化処理を行うための仮想メソッド
func _ready_enemy() -> void:
	pass

## ダメージ処理（スコア加算とポップアップ演出を共通化）
func take_damage(amount: int, hit_pos: Vector2 = Vector2.ZERO, is_critical: bool = false) -> void:
	if not is_alive:
		return
	current_hp -= amount
	var is_dead = current_hp <= 0
	var actual_pos = hit_pos if hit_pos != Vector2.ZERO else global_position
	
	Global.play_hit(randf_range(0.95, 1.15))
	var spark_mode = "heavy" if is_critical else "normal"
	var spark_col = Color(1.0, 0.9, 0.2) if is_critical else (modulate if modulate != Color.WHITE else Color(1.0, 0.85, 0.3))
	HitSpark.create_spark(get_parent(), actual_pos, spark_mode, spark_col)
	
	# 被弾フラッシュ
	var orig_mod = modulate
	modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", orig_mod, 0.06)
	
	var main = get_node_or_null("/root/Main")
	if main:
		var manager = main.get_node_or_null("GameManager")
		if manager and manager.has_method("add_damage_score"):
			manager.add_damage_score(amount)
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_damage_popup"):
			ui_node.spawn_damage_popup(actual_pos, amount, is_dead, is_critical)
			
	if is_dead:
		is_alive = false
		call_deferred("die")

## 撃破時の処理（子クラスでオーバーライド可能）
func die() -> void:
	is_alive = false
	Global.play_explosion(1.2)
	# 敵撃破時に短く超巨大なテキスト演出（"DESTROY!"）を生成
	var main = get_node_or_null("/root/Main")
	if main:
		var ui_node = main.get_node_or_null("UI")
		if ui_node and ui_node.has_method("spawn_kill_popup"):
			ui_node.spawn_kill_popup(global_position, "撃破！")
			
	explode()
	queue_free()

## 爆発演出（パーティクル生成）
func explode() -> void:
	var ParryParticleScene = load("res://game/bullets/parry_particle.tscn")
	var parent_node = get_parent()
	if ParryParticleScene and parent_node:
		var particle = ParryParticleScene.instantiate()
		particle.global_position = global_position
		particle.modulate = modulate
		parent_node.call_deferred("add_child", particle)
