extends Area2D
class_name BaseEnemy

## 敵キャラクターのベースクラス（共通のHP管理、被ダメージ、破壊演出を処理）

const SoundManager = preload("res://game/core/sound_manager.gd")
const HitSpark = preload("res://game/bullets/hit_spark.gd")

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
func take_damage(amount: int, hit_pos: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return
	current_hp -= amount
	var is_dead = current_hp <= 0
	var actual_pos = hit_pos if hit_pos != Vector2.ZERO else global_position
	
	SoundManager.play_hit(randf_range(0.95, 1.15))
	HitSpark.create_spark(get_parent(), actual_pos, "normal", modulate if modulate != Color.WHITE else Color(1.0, 0.85, 0.3))
	
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
			ui_node.spawn_damage_popup(actual_pos, amount, is_dead)
			
	if is_dead:
		die()

## 撃破時の処理（子クラスでオーバーライド可能）
func die() -> void:
	is_alive = false
	SoundManager.play_explosion(1.2)
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
	if ParryParticleScene:
		var particle = ParryParticleScene.instantiate()
		particle.global_position = global_position
		particle.modulate = modulate
		get_parent().add_child(particle)
