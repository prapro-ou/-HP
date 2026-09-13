extends Resource
class_name AnalysisWeapon

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var color: Color = Color.CYAN
@export var bullet_types: Array[StringName] = []


func matches_bullet(bullet_type: String) -> bool:
	return bullet_types.has(StringName(bullet_type))
