extends RefCounted
class_name CombatTargets

# Body/core collision areas forward to the same boss. Count that boss once.
static func resolve(node: Node) -> Node2D:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	var parent := node.get_parent()
	if parent != null and parent.has_method("take_damage_on_part"):
		return parent as Node2D
	if node.has_method("take_damage") or node.has_method("take_damage_on_part"):
		return node as Node2D
	if parent != null and parent.has_method("take_damage"):
		return parent as Node2D
	return null

static func enemies(tree: SceneTree) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for group in ["enemy", "boss", "boss_turrets", "drones"]:
		for node in tree.get_nodes_in_group(group):
			var target := resolve(node)
			if target == null or not target.is_visible_in_tree() or result.has(target):
				continue
			if target.get("is_alive") == false or (target.get("current_hp") != null and int(target.get("current_hp")) <= 0):
				continue
			result.append(target)
	return result

static func damage(target: Node2D, amount: int, point: Vector2, critical: bool = false) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	if target.has_method("take_damage"):
		target.take_damage(amount, point, critical)
	elif target.has_method("take_damage_on_part"):
		target.take_damage_on_part("core", amount, point, critical)

static func in_radius(source: Node2D, point: Vector2, radius: float) -> Array[Node2D]:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var result := _shape_targets(source, shape, point)
	for target in enemies(source.get_tree()):
		if point.distance_to(target.global_position) <= radius and not result.has(target):
			result.append(target)
	return result

static func in_rectangle(source: Node2D, rect: Rect2) -> Array[Node2D]:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var result := _shape_targets(source, shape, rect.get_center())
	for target in enemies(source.get_tree()):
		if rect.has_point(target.global_position) and not result.has(target):
			result.append(target)
	return result

static func _shape_targets(source: Node2D, shape: Shape2D, point: Vector2) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, point)
	query.collide_with_bodies = false
	query.collide_with_areas = true
	query.collision_mask = 0xFFFFFFFF
	for hit in source.get_world_2d().direct_space_state.intersect_shape(query, 256):
		var area: Node = hit["collider"]
		if not (area.is_in_group("boss") or area.is_in_group("boss_turrets") or area.is_in_group("enemy") or area.is_in_group("drones")):
			continue
		var target := resolve(area)
		if target != null and target.is_visible_in_tree() and target.get("is_alive") != false and not result.has(target):
			result.append(target)
	return result

static func projectiles(tree: SceneTree) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for group in ["enemy_bullets", "enemy_projectiles"]:
		for node in tree.get_nodes_in_group(group):
			if node is Node2D and node.is_visible_in_tree() and not node.is_queued_for_deletion() and not result.has(node) and node.get("is_friendly") == false:
				result.append(node)
	return result

static func can_parry(bullet: Node) -> bool:
	return is_instance_valid(bullet) and bullet.get("is_unparryable") != true and not str(bullet.get("bullet_type")).contains("unparryable")

static func erase(bullet: Node) -> void:
	if bullet.has_method("recycle_bullet"):
		bullet.recycle_bullet()
	else:
		bullet.queue_free()
