extends RefCounted
class_name WeaponCatalog

const PRIMARY: Dictionary = {
	"machine_gun": {"name": "マシンガン", "description": "2本の直進弾を高速連射。連射力と安定した火力に優れる。", "stats": "連射 / 直進2射線", "interval": 0.16, "bullet": "machine_gun", "damage": 14, "speed": 1200.0},
	"burst_rifle": {"name": "3点バーストライフル", "description": "高威力の徹甲弾を3点バーストで発射。硬い敵と縦の敵列に強い。", "stats": "3点バースト / 1体貫通", "interval": 0.40, "bullet": "burst_rifle", "damage": 26, "speed": 1500.0},
	"pulse_gun": {"name": "パルスガン", "description": "3方向にパルス弾を発射。横に広がる敵の制圧に優れる。", "stats": "広角3射線 / 面制圧", "interval": 0.26, "bullet": "pulse", "damage": 18, "speed": 950.0},
	"plasma_emitter": {"name": "プラズマ放射器", "description": "低速の重いプラズマ球を発射。着弾地点に持続ダメージの熱場を残す。", "stats": "低速重弾 / 持続熱場", "interval": 0.42, "bullet": "plasma", "damage": 32, "speed": 600.0},
	"kinetic_tackle": {"name": "キネティックタックル", "description": "前方の至近距離に貫通衝撃波を放つ。接近するほど高い火力を発揮する。", "stats": "短射程 / 貫通衝撃波", "interval": 0.50, "bullet": "tackle", "damage": 60, "speed": 850.0}
}
const SHIELDS: Dictionary = {
	"counter": {"name": "カウンターシールド", "description": "追撃威力1.4倍。捕獲に成功すると熱を8返し、次の反撃につなげる。", "stats": "反撃型 / 追撃 ×1.4 / 成功時に熱8返却"},
	"gauge": {"name": "吸収マトリクス", "description": "基本半径140の広域吸収で弾幕をまとめて捕獲。COUNTER充填量1.5倍。再展開は基本3秒。", "stats": "広域型 / 広い捕獲範囲 / 再展開3秒"},
	"power": {"name": "増幅ブースター", "description": "捕獲成功時に半径125の攻撃衝撃波を放つ。成功後2秒間、主兵装威力1.25倍。", "stats": "強襲型 / 近距離衝撃波 / 主兵装 ×1.25"}
}
const COUNTER: Dictionary = {
	"turret": {"name": "支援砲台部隊", "description": "左右に2基の砲台を展開。ビームと誘導ミサイルで継続的に援護する。", "stats": "継続援護 / 自動照準"},
	"funnel": {"name": "サイバーファンネル", "description": "4機の端末が周囲を旋回。敵の砲台を優先して貫通レーザーを集中させる。", "stats": "砲台優先 / 4機展開"},
	"gigantic_orb": {"name": "ギガエネルギー弾", "description": "巨大な低速弾で前方の敵弾を消し、進路上の敵を繰り返し攻撃する。", "stats": "前方制圧 / 弾消し / 画面外で終了"},
	"chain_explosions": {"name": "5連鎖スーパノヴァ", "description": "前方を5つの爆発で横断。範囲内のパリィ可能弾を3倍威力で反射する。", "stats": "横断爆撃 / 反射 ×3 / 基本1.5秒"},
	"boss_beam": {"name": "ギガレーザー砲台", "description": "自機前方に極太レーザーを照射。射線上の敵と砲台を継続的に貫く。", "stats": "固定射線 / 多段貫通 / 基本6秒"},
	"boss_missile": {"name": "ハイパーミサイル砲台", "description": "複数の誘導ミサイルを連続発射。着弾時の爆風で密集した敵を破壊する。", "stats": "誘導斉射 / 範囲爆発"}
}
const ANALYSIS_RESOURCES = [
	preload("res://game/data/analysis/rapid.tres"), preload("res://game/data/analysis/spread.tres"),
	preload("res://game/data/analysis/pierce.tres"), preload("res://game/data/analysis/homing.tres"),
	preload("res://game/data/analysis/laser.tres"), preload("res://game/data/analysis/cyclone.tres"),
	preload("res://game/data/analysis/meteor.tres"), preload("res://game/data/analysis/thunder.tres"),
	preload("res://game/data/analysis/vortex.tres"), preload("res://game/data/analysis/blade.tres")
]

const CAPTURE_EFFECTS: Dictionary = {
	"rapid": {"name": "直進弾", "description": "捕まえた弾を高速の直進弾として撃ち返す。"},
	"spread": {"name": "拡散弾", "description": "捕まえた弾が3方向の追撃になる。"},
	"pierce": {"name": "貫通弾", "description": "重い追撃弾が敵を貫く。"},
	"homing": {"name": "誘導弾", "description": "捕まえたミサイルが敵へ向かう。"},
	"laser": {"name": "レーザー弾", "description": "速い光線の追撃で敵列を貫く。"},
	"cyclone": {"name": "波動弾", "description": "左右にうねる追撃弾を放つ。"},
	"meteor": {"name": "爆発弾", "description": "大きな追撃弾が着弾時に爆発する。"},
	"thunder": {"name": "電撃弾", "description": "追撃の命中から近くの敵へ電撃が連鎖する。"},
	"vortex": {"name": "渦弾", "description": "追撃の着弾地点に短い渦を残す。"},
	"blade": {"name": "刃弾", "description": "追撃の刃が敵を貫き、通常の敵弾を切る。"}
}

static func capture_kind(source_type: String) -> String:
	for weapon in ANALYSIS_RESOURCES:
		if weapon.matches_bullet(source_type):
			return String(weapon.id)
	return "rapid"

static func analysis_weapons() -> Array[AnalysisWeapon]:
	var result: Array[AnalysisWeapon] = []
	for weapon in ANALYSIS_RESOURCES:
		result.append(weapon)
	return result

static func analysis_info() -> Dictionary:
	var result := {}
	for weapon in ANALYSIS_RESOURCES:
		result[String(weapon.id)] = {
			"name": CAPTURE_EFFECTS[String(weapon.id)]["name"],
			"icon": "[" + String(weapon.id).to_upper() + "]", "color": weapon.color,
			"enemy_color": "対応する敵弾", "enemy_type": "パリィで捕獲",
			"effect": CAPTURE_EFFECTS[String(weapon.id)]["description"], "stats": "捕獲後、次の射撃で追撃",
			"description": CAPTURE_EFFECTS[String(weapon.id)]["description"]
		}
	return result
