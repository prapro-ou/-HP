extends Area2D
## プレイヤー弾スクリプト
## - 前方移動
## - 画面外判定で削除
## - 敵（BossDamageShape）との衝突検知

@export var speed: float = 800.0
@export var damage: int = 10

var velocity: Vector2 = Vector2.ZERO
var bullet_type: String = "analysis":
	set(val):
		bullet_type = val
		update_visual()

const MAX_PLAYER_BULLETS: int = 80
const MAX_LIFE_TIME: float = 3.5

# 強化属性・変異パラメータ
var pierce_limit: int = 0
var hits_done: int = 0
var homing_strength: float = 0.0
var wave_amp: float = 0.0
var explosion_radius: float = 0.0
var explosion_dmg: int = 0

# 新変異属性パラメータ
var chain_count: int = 0
var chain_damage: int = 0
var vortex_radius: float = 0.0
var vortex_dmg: int = 0
var is_blade: bool = false
var blade_lvl: int = 0


func _ready() -> void:
	z_index = 65
	z_as_relative = false
	update_visual()
	area_entered.connect(_on_area_entered)
	
	if is_blade:
		scale = Vector2(1.8 + blade_lvl * 0.4, 1.2 + blade_lvl * 0.3)
		modulate = Color(0.2, 1.0, 0.85)
		
	# メテオ・大玉属性（explosion_radius）が付与されている場合、弾丸サイズを大幅に巨大化＆灼熱発光
	if explosion_radius > 0.0:
		var m_scale_boost = 1.0 + (explosion_radius / 80.0) * 0.9 # 最大約2.2倍の大玉サイズ
		scale *= m_scale_boost
		modulate = modulate.lerp(Color(1.0, 0.45, 0.15), 0.65)
		
	# 貫通属性（pierce_limit）による白熱青白いコア発光
	if pierce_limit > 0 and not is_blade:
		modulate = modulate.lerp(Color(0.5, 0.9, 1.0), 0.35)
	
	# プレイヤー弾の最大同時存在数の制限（超過時は最古弾を自然消滅）
	var parent_node = get_parent()
	if is_instance_valid(parent_node) and parent_node.name.contains("Bullet"):
		var sibling_count = parent_node.get_child_count()
		if sibling_count > MAX_PLAYER_BULLETS:
			var oldest = parent_node.get_child(0)
			if is_instance_valid(oldest) and oldest != self:
				oldest.queue_free()


func update_visual() -> void:
	match bullet_type:
		"machine_gun":
			scale = Vector2(0.6, 1.2)
			modulate = Color(1.0, 0.85, 0.3) # 鮮烈な物理イエローゴールド
			damage = 14
			speed = 1200.0
		"burst_rifle":
			scale = Vector2(0.5, 2.0)
			modulate = Color(1.0, 0.5, 0.1) # 灼熱の徹甲オレンジ
			damage = 26
			speed = 1500.0
		"pulse":
			scale = Vector2(1.3, 0.8)
			modulate = Color(0.2, 1.0, 0.6) # エメラルドプラズマ波
			damage = 18
			speed = 950.0
		"plasma":
			scale = Vector2(1.8, 1.8)
			modulate = Color(0.3, 1.0, 0.4) # 高熱グリーンプラズマ球
			damage = 22
			speed = 600.0
		"tackle":
			scale = Vector2(2.8, 1.6)
			modulate = Color(0.3, 0.75, 1.0) # 強力キネティック衝撃波
			damage = 50
			speed = 850.0
		"analysis":
			scale = Vector2(0.6, 0.6)
			modulate = Color.GREEN
			damage = 10
			speed = 950.0
		"beam":
			scale = Vector2(0.5, 2.5)
			modulate = Color.CYAN
			damage = 18
			speed = 1600.0
		"giga_laser":
			scale = Vector2(1.6, 5.5)
			modulate = Color.GOLD
			damage = 32
			speed = 2200.0
		"missile":
			scale = Vector2(0.9, 0.9)
			modulate = Color(0.9, 0.4, 1.0) # 明るい紫
			damage = 24
			speed = 500.0
		"hyper_missile":
			scale = Vector2(1.4, 1.4)
			modulate = Color.ORANGE
			damage = 45
			speed = 650.0
		"charge_bolt":
			scale = Vector2(1.2, 2.8)
			modulate = Color(0.3, 0.8, 1.0)
			damage = 45
			speed = 1800.0
		"cyclone":
			scale = Vector2(1.2, 1.2)
			modulate = Color(1.0, 0.85, 0.2) # イエロー
			damage = 22
			speed = 800.0
		"photon_laser":
			scale = Vector2(1.8, 5.5)
			modulate = Color(0.4, 0.9, 1.0) # シアンレーザー
			damage = 30
			speed = 2400.0
		"player_meteor":
			scale = Vector2(2.0, 2.0)
			modulate = Color(1.0, 0.35, 0.2) # 隕石オレンジレッド
			damage = 55
			speed = 650.0
		# --- 固有融合兵装弾 (FUSION WEAPONS) ---
		"fusion_meteor_cluster":
			scale = Vector2(2.4, 2.4)
			modulate = Color(1.0, 0.45, 0.15) # 扇状大爆砕メテオ
			damage = 48
			speed = 800.0
		"fusion_gatling_storm":
			scale = Vector2(0.7, 1.8)
			modulate = Color(0.25, 0.95, 0.85) # 超高密度ガトリング
			damage = 18
			speed = 1750.0
		"fusion_swarm":
			scale = Vector2(1.2, 1.2)
			modulate = Color(0.75, 0.5, 1.0) # 多目標誘導スウォーム
			damage = 25
			speed = 700.0
		"fusion_cross_penetrator":
			scale = Vector2(0.9, 3.2)
			modulate = Color(1.0, 0.68, 0.2) # クロス多重徹甲槍
			damage = 32
			speed = 1700.0
		"fusion_prism_laser":
			scale = Vector2(1.3, 5.2)
			modulate = Color(0.35, 0.95, 1.0) # プリズム広角レーザー
			damage = 28
			speed = 2300.0
		"fusion_electric_spread":
			scale = Vector2(1.4, 1.4)
			modulate = Color(0.98, 0.95, 0.25) # 連鎖放電ボルト
			damage = 22
			speed = 1100.0
		"fusion_gravity_vortex":
			scale = Vector2(1.8, 1.8)
			modulate = Color(0.8, 0.35, 1.0) # 重力特異点弾頭
			damage = 22
			speed = 850.0
		"fusion_tempest_slash":
			scale = Vector2(3.4, 1.6)
			modulate = Color(0.2, 1.0, 0.8) # 扇状三日月真空刃
			damage = 35
			speed = 1150.0
		"fusion_spiral_cyclone":
			scale = Vector2(1.5, 1.5)
			modulate = Color(1.0, 0.85, 0.25) # 螺旋弾幕チャクラム
			damage = 26
			speed = 950.0
		"fusion_photon_repeater":
			scale = Vector2(1.4, 4.8)
			modulate = Color(0.4, 0.95, 1.0) # 超連射フォトン
			damage = 24
			speed = 2500.0
		"fusion_hyper_needler":
			scale = Vector2(0.6, 3.0)
			modulate = Color(1.0, 0.72, 0.3) # 高速ニードル徹甲
			damage = 20
			speed = 2000.0
		"fusion_homing_gatling":
			scale = Vector2(1.0, 1.0)
			modulate = Color(0.9, 0.45, 1.0) # 高速追尾ロケット
			damage = 18
			speed = 900.0
		"fusion_bomber_vulcan":
			scale = Vector2(1.4, 1.6)
			modulate = Color(1.0, 0.45, 0.2) # 連射重爆裂弾
			damage = 24
			speed = 1400.0
		"fusion_megaton_drill":
			scale = Vector2(2.4, 3.4)
			modulate = Color(1.0, 0.55, 0.1) # 貫通体内起爆ドリル
			damage = 60
			speed = 950.0
		"fusion_tesla_seeker":
			scale = Vector2(1.3, 1.3)
			modulate = Color(0.95, 0.9, 0.3) # 必中放電シーカー
			damage = 30
			speed = 750.0
		"fusion_singularity_missile":
			scale = Vector2(1.5, 1.5)
			modulate = Color(0.75, 0.3, 0.95) # 誘導特異点ミサイル
			damage = 32
			speed = 700.0
		"fusion_photon_blade":
			scale = Vector2(3.6, 4.2)
			modulate = Color(0.3, 1.0, 0.95) # 光子断絶レーザー刃
			damage = 52
			speed = 1700.0
		"fusion_supernova":
			scale = Vector2(3.0, 3.0)
			modulate = Color(1.0, 0.3, 0.65) # 超新星重力爆弾
			damage = 65
			speed = 650.0
		"fusion_twister_slasher":
			scale = Vector2(3.2, 2.4)
			modulate = Color(0.35, 1.0, 0.7) # 巨大回転ツイスター刃
			damage = 42
			speed = 1000.0
		"fusion_rail_cannon":
			scale = Vector2(2.0, 9.0)
			modulate = Color(0.45, 0.9, 1.0) # 極限貫通レール砲
			damage = 70
			speed = 3000.0
			
	# 通常攻撃弾の透明度を上げて少しだけ目立ちにくく調整（ジャストガードと敵弾の視認性を重視）
	modulate.a = 0.55
	
	if velocity == Vector2.ZERO:
		velocity = Vector2.UP * speed


var life_timer: float = 0.0

func _process(delta: float) -> void:
	life_timer += delta
	
	# 誘導補正 (ミサイルまたは変異誘導)
	if bullet_type == "missile" or bullet_type == "hyper_missile" or homing_strength > 0.0:
		var target = find_closest_target()
		var steer_rate = 6.5 if (bullet_type == "missile" or bullet_type == "hyper_missile") else homing_strength
		if is_instance_valid(target):
			var target_dir = (target.global_position - global_position).normalized()
			var target_velocity = target_dir * speed
			velocity = velocity.lerp(target_velocity, delta * steer_rate)
		else:
			if velocity == Vector2.ZERO:
				velocity = Vector2.UP * speed
			else:
				velocity = velocity.normalized() * speed
		rotation = velocity.angle() + PI/2
		
	# 螺旋波動補正
	if bullet_type == "cyclone" or wave_amp > 0.0:
		var amp = 280.0 if bullet_type == "cyclone" else wave_amp
		var side_wave = sin(life_timer * 14.0) * amp
		position.x += side_wave * delta
		if bullet_type == "cyclone":
			rotation += delta * 12.0
		
	elif bullet_type == "player_meteor":
		rotation += delta * 4.0
		var vp_rect = get_viewport_rect()
		if position.x < 30.0:
			position.x = 30.0
			velocity.x = abs(velocity.x)
		elif position.x > vp_rect.size.x - 30.0:
			position.x = vp_rect.size.x - 30.0
			velocity.x = -abs(velocity.x)

	position += velocity * delta
	
	# 寿命切れまたは画面外で消去
	if life_timer >= MAX_LIFE_TIME:
		queue_free()
		return
		
	var viewport_rect = get_viewport_rect()
	if position.y < -120 or position.y > viewport_rect.size.y + 120 or \
	   position.x < -120 or position.x > viewport_rect.size.x + 120:
		queue_free()


func find_closest_target() -> Node2D:
	var targets = get_tree().get_nodes_in_group("enemy")
	var closest: Node2D = null
	var min_dist = 999999.0
	for t in targets:
		if is_instance_valid(t) and t.visible:
			var dist = global_position.distance_to(t.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = t
	return closest


func _on_area_entered(area: Area2D) -> void:
	"""他のArea2Dに入った時の処理"""
	# 真空ブレードの敵弾消滅（斬り払い）処理
	if is_blade and is_instance_valid(area) and area.is_in_group("enemy_projectiles"):
		if area.has_method("recycle_bullet"):
			area.recycle_bullet()
		elif area.has_method("explode_and_free"):
			area.explode_and_free()
		else:
			area.queue_free()
		spawn_bullet_impact_particles(Color(0.2, 1.0, 0.85), 0.35)
		return
		
	var is_boss_part = area.is_in_group("boss") or area.is_in_group("boss_turrets") or area.name == "BossDamageShape" or area.name.contains("Cannon") or area.name.contains("Pod") or area.name == "Core"
	var is_enemy = area.is_in_group("enemy") or area.is_in_group("drones")
	
	if is_boss_part or is_enemy:
		var hit_pos = global_position
		var damage_target = area
		if not area.has_method("take_damage") and not area.has_method("take_damage_on_part") and area.get_parent() and (area.get_parent().has_method("take_damage") or area.get_parent().has_method("take_damage_on_part")):
			damage_target = area.get_parent()
			
		# --- 至近距離ボーナス（Point Blank Bonus）の算出 ---
		var dist_to_player = 999.0
		var player = get_node_or_null("/root/Main/Player")
		if is_instance_valid(player):
			dist_to_player = player.global_position.distance_to(hit_pos)
			
		var dmg_multiplier: float = 1.0
		var is_critical: bool = false
		if dist_to_player <= 140.0:
			dmg_multiplier = 1.15 # 超至近距離: 1.15倍クリティカル
			is_critical = true
		elif dist_to_player <= 260.0:
			dmg_multiplier = 1.08 # 近距離: 1.08倍
			
		var final_damage = max(1, int(damage * dmg_multiplier))
			
		if damage_target.has_method("take_damage"):
			damage_target.take_damage(final_damage, hit_pos, is_critical)
		elif damage_target.has_method("take_damage_on_part"):
			damage_target.take_damage_on_part("core", final_damage, hit_pos, is_critical)
		
		# 1. 電撃チェイン（Thunder Chain）の発動
		if chain_count > 0 and chain_damage > 0:
			trigger_chain_lightning(damage_target, chain_count, int(chain_damage * dmg_multiplier))
			
		# 2. 重力特異点（Gravity Vortex）の生成
		if vortex_radius > 0.0 and vortex_dmg > 0:
			spawn_gravity_vortex(hit_pos, vortex_radius, int(vortex_dmg * dmg_multiplier))
		
		# 3. 爆発・衝撃波エフェクト
		var cur_exp_dmg = max(1, int(explosion_dmg * dmg_multiplier))
		if explosion_radius > 0.0:
			trigger_explosion(explosion_radius, cur_exp_dmg, Color.ORANGE, 0.7 if is_critical else 0.6)
		elif bullet_type == "hyper_missile" or bullet_type == "player_meteor":
			trigger_explosion(80.0, int(14 * dmg_multiplier), Color.ORANGE, 0.9 if is_critical else 0.8)
		elif bullet_type == "plasma":
			trigger_explosion(50.0, int(10 * dmg_multiplier), Color(0.3, 1.0, 0.4), 0.7 if is_critical else 0.6)
		elif bullet_type == "tackle":
			trigger_explosion(70.0, int(18 * dmg_multiplier), Color(0.4, 0.8, 1.0), 0.9 if is_critical else 0.8)
		elif bullet_type == "missile":
			spawn_bullet_impact_particles(Color(0.8, 0.4, 1.0), 0.5 if is_critical else 0.4)
		else:
			var p_col = Color(0.2, 1.0, 0.85) if is_blade else modulate
			spawn_bullet_impact_particles(p_col, 0.45 if is_critical else 0.35)
			
		hits_done += 1
		# 貫通判定 (レーザー、プラズマ、タックル、サイクロン、隕石、ブレード、融合貫通弾、またはpierce_limit残存時は貫通)
		var is_piercing = (is_blade or pierce_limit >= 90 or bullet_type.contains("laser") or bullet_type.contains("blade") or bullet_type.contains("penetrator") or bullet_type.contains("drill") or bullet_type.contains("rail") or bullet_type.contains("needler") or bullet_type.contains("plasma") or bullet_type.contains("tackle") or bullet_type.contains("cyclone") or bullet_type.contains("meteor"))
		if not is_piercing:
			if hits_done > pierce_limit:
				queue_free()


const CHAIN_LIGHTNING_SCENE: PackedScene = preload("res://game/effects/chain_lightning.tscn")
const GRAVITY_VORTEX_SCENE: PackedScene = preload("res://game/effects/gravity_vortex.tscn")

func trigger_chain_lightning(origin_target: Node, count: int, chain_dmg: int) -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var hit_targets = [origin_target]
	var current_origin_pos = global_position
	var parent_node = get_parent()
	
	for i in range(count):
		var next_target: Node2D = null
		var min_d = 260.0 # 最大連鎖索敵半径
		for e in enemies:
			if is_instance_valid(e) and not hit_targets.has(e) and e.visible:
				var d = current_origin_pos.distance_to(e.global_position)
				if d < min_d:
					min_d = d
					next_target = e
					
		if is_instance_valid(next_target):
			hit_targets.append(next_target)
			var target_pos = next_target.global_position
			
			# 分離シーン（ChainLightningEffect）の呼び出し
			if CHAIN_LIGHTNING_SCENE and parent_node:
				var bolt = CHAIN_LIGHTNING_SCENE.instantiate()
				bolt.setup_lightning(current_origin_pos, target_pos)
				parent_node.add_child(bolt)
				
			if next_target.has_method("take_damage"):
				next_target.take_damage(chain_dmg, target_pos)
			elif next_target.has_method("take_damage_on_part"):
				next_target.take_damage_on_part("core", chain_dmg, target_pos)
				
			current_origin_pos = target_pos
		else:
			break


func spawn_gravity_vortex(vortex_pos: Vector2, radius: float, dmg_per_tick: int) -> void:
	var parent_node = get_parent()
	if not parent_node or not GRAVITY_VORTEX_SCENE:
		return
		
	# 分離シーン（GravityVortexEffect）の呼び出し
	var vortex = GRAVITY_VORTEX_SCENE.instantiate()
	vortex.setup_vortex(vortex_pos, radius, dmg_per_tick, 1.4)
	parent_node.add_child(vortex)


func trigger_explosion(radius: float = 80.0, splash_dmg: int = 10, fx_color: Color = Color.ORANGE, fx_scale: float = 0.6) -> void:
	# 周囲へのスプラッシュダメージ
	var targets = get_tree().get_nodes_in_group("enemy")
	for t in targets:
		if is_instance_valid(t) and t != self:
			var dist = global_position.distance_to(t.global_position)
			if dist < radius:
				if t.has_method("take_damage"):
					t.take_damage(splash_dmg)
					
	# 控えめな爆発パーティクル
	spawn_bullet_impact_particles(fx_color, fx_scale)


func spawn_bullet_impact_particles(color: Color, scale_multiplier: float = 0.4) -> void:
	var ParryParticleScene = load("res://game/bullets/parry_particle.tscn")
	if ParryParticleScene:
		var particle = ParryParticleScene.instantiate()
		particle.global_position = global_position
		particle.modulate = color
		particle.scale = Vector2(scale_multiplier, scale_multiplier)
		get_parent().add_child(particle)

