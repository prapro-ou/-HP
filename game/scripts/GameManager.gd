extends Node2D
## ゲーム進行管理
## - ゲーム状態（進行中・勝利・敗北）
## - UI 更新
## - ボス・プレイヤー参照

var player: CharacterBody2D
var boss: Node2D
var ui: Control

var game_state: String = "playing"  # "playing", "victory", "defeat"
var parry_count: int = 0


func _ready() -> void:
	# ノード参照取得（親子関係から兄弟関係へ修正）
	player = get_node("../Player")
	boss = get_node("../Boss")
	ui = get_node("../UI")
	
	# 敵弾リストをプレイヤーに渡す
	var bullet_pool = get_node_or_null("../BulletPool")
	if bullet_pool:
		player.enemy_bullets = bullet_pool.active_bullets



func _process(delta: float) -> void:
	if game_state == "playing":
		check_win_lose()
		update_ui()


func check_win_lose() -> void:
	"""勝敗判定"""
	if player.current_hp <= 0:
		game_state = "defeat"
		show_game_over("DEFEAT")
	elif boss.current_hp <= 0:
		game_state = "victory"
		show_game_over("VICTORY")


func update_ui() -> void:
	"""UI 更新"""
	ui.update_player_hp(player.current_hp, player.max_hp)
	ui.update_boss_hp(boss.current_hp, boss.max_hp * 3)
	ui.update_parry_count(parry_count)
	if ui.has_method("update_guard_status"):
		ui.update_guard_status(player.cooldown_timer, player.is_guarding)



func register_parry() -> void:
	"""パリィ成功をカウント"""
	parry_count += 1


func show_game_over(result: String) -> void:
	"""ゲームオーバー画面表示"""
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over(result)


func restart() -> void:
	"""ゲーム再開"""
	get_tree().reload_current_scene()
