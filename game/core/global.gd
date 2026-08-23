extends Node

const SAVE_PATH = "user://savegame.cfg"
const SETTINGS_PATH = "user://settings.cfg"

# Save Game variables
var is_continue: bool = false
var has_save: bool = false

# Weapon Selection variables
var equipped_weapon: String = "machine_gun"

# New game state variables for customization & progression
var is_first_launch: bool = true
var tech_points: int = 0
var equipped_shield: String = "counter" # "counter" (damage/rebound), "gauge" (faster charge/absorb), "power" (buff primary)
var unlocked_shields: Array = ["counter"] # Available shield frameworks
var unlocked_weapons: Array = ["machine_gun", "burst_rifle", "pulse_gun"] # Available primary weapon frameworks
var unlocked_counter_weapons: Array = [] # Boss weapons unlocked for COUNTER SYSTEM
var unlocked_stages: Array = [1] # Unlocked stages (Stage 1 is unlocked by default)
var discovered_analysis_weapons: Array = [] # Discovered analysis mutation patterns
var upgrade_levels: Dictionary = {
	"hp": 0,
	"parry_window": 0,
	"cooldown": 0
}

# 各シールド固有のジャストガード範囲強化レベル (Lv.0〜5)
var shield_radius_upgrades: Dictionary = {
	"counter": 0,
	"gauge": 0,
	"power": 0
}

# ジャストガード フォーカス設定 (0: 標準 100%/1.0x, 1: 集中 75%/1.5x, 2: 極小ピンポイント 50%/2.2x)
var just_guard_focus_mode: int = 0

# COUNTER SYSTEM 強化レベル (Lv.0〜5)
var counter_system_duration_lvl: int = 0 # 10s -> 12s -> 14s -> 16s -> 18s -> 20s
var counter_system_power_lvl: int = 0    # 1.0x -> 1.2x -> 1.5x -> 2.0x -> 3.0x -> 5.0x

# エンドコンテンツ: COUNTER ONLY 出撃モード (ステージ5を5回クリア + 150 TPで解放)
var stage5_clears_count: int = 0
var counter_only_mode_unlocked: bool = false
var counter_only_mode_enabled: bool = false

# ハードモード設定 (敵HP 2.0倍 / 攻撃頻度 1.3倍 [攻撃スパン短縮])
var hard_mode_enabled: bool = false

func get_enemy_hp_multiplier() -> float:
	return 2.0 if hard_mode_enabled else 1.0

func get_enemy_attack_interval_multiplier() -> float:
	return (1.0 / 1.3) if hard_mode_enabled else 1.0

# TIPS 戦術アーカイブ管理 (出撃ごとに1つずつ解放)
var unlocked_tips: Array = ["tip_move", "tip_shoot"]
var unread_tips: Array = ["tip_move", "tip_shoot"]

var tips_categories: Dictionary = {
	"all": "すべて",
	"basic": "基本操作",
	"shield": "シールド",
	"attack": "攻撃",
	"boss": "ボス",
	"upgrade": "強化要素",
	"other": "その他"
}

var tips_catalog: Array[Dictionary] = [
	{
		"id": "tip_move",
		"category": "basic",
		"category_name": "基本操作",
		"title": "機体の基本移動と回避",
		"desc": "方向キーまたはWASDキーで機体を360度自在に移動できます。マウス移動にも対応しており、状況に応じた直感的な回避行動が可能です。",
		"hint": "操作: [WASD] / [方向キー] / [マウス移動]"
	},
	{
		"id": "tip_shoot",
		"category": "basic",
		"category_name": "基本操作",
		"title": "主兵装の連続射撃",
		"desc": "Zキーまたは左クリックを押し続けることで自動連射が行われます。射撃中も移動速度は低下しないため、常に位置取りを意識して攻撃を継続できます。",
		"hint": "操作: [Zキー] または [左クリック] (長押し対応)"
	},
	{
		"id": "tip_guard_basic",
		"category": "shield",
		"category_name": "シールド",
		"title": "シールドの展開と熱管理",
		"desc": "スペースキーまたは右クリックでシールドを展開し、敵弾を完全に遮断します。連続展開を行うとシールド熱量が上昇し、オーバーヒート時に一時的な防御不能と装甲脆弱化が発生します。",
		"hint": "操作: [SPACE] または [右クリック] (熱ゲージに注意)"
	},
	{
		"id": "tip_just_guard",
		"category": "shield",
		"category_name": "シールド",
		"title": "ジャストガードと反射反撃",
		"desc": "敵弾が自機周囲の有効範囲に入った瞬間にシールドを展開するとジャストガードが発動します。敵弾を強力な味方反射弾へと変換し、機体耐久値の修復も行われます。",
		"hint": "判定: 自機周囲のサイバーリング内に敵弾侵入時"
	},
	{
		"id": "tip_focus_tuning",
		"category": "shield",
		"category_name": "シールド",
		"title": "ジャストガードのフォーカス設定",
		"desc": "技術研究所にて判定範囲を縮小する代わりに反射威力を最大2.2倍まで引き上げることが可能です。リスクは高まりますが、強敵相手に圧倒的なカウンターダメージを与えられます。",
		"hint": "設定場所: 技術研究所 (STANDARD / FOCUS / PINPOINT)"
	},
	{
		"id": "tip_analysis_slot",
		"category": "attack",
		"category_name": "攻撃",
		"title": "敵弾解析とスロット固定",
		"desc": "敵弾をジャストガードすることで解析が進み、100%に達すると変異兵装が解放されます。最大2つまでスロットに固定装備され、以降の解析でLvアップ集中強化されます。",
		"hint": "仕様: 最大2スロット固定 / 上書きなし集中強化"
	},
	{
		"id": "tip_fusion_weapon",
		"category": "attack",
		"category_name": "攻撃",
		"title": "2属性融合兵装の完成",
		"desc": "2つの変異兵装スロットが埋まると自動的に固有の融合兵装が完成します。拡散×3連射やメテオ×拡散など、2つの兵装特性を兼ね備えた強力な複合効果を発揮します。",
		"hint": "発動条件: 変異スロット2枠の解放完了"
	},
	{
		"id": "tip_counter_system",
		"category": "attack",
		"category_name": "攻撃",
		"title": "COUNTER SYSTEMの展開",
		"desc": "Xキーを押すことで自機カラーのボスタレット支援部隊が一定時間出撃します。敵を自動索敵して高火力支援射撃を行い、全画面が機体カラーのサイバーティントで包まれます。",
		"hint": "操作: [Xキー] (支援タレット部隊の召喚)"
	},
	{
		"id": "tip_boss_turret",
		"category": "boss",
		"category_name": "ボス",
		"title": "要塞ボスのサブ砲台と装甲",
		"desc": "サブ砲台が稼働している間、ボスの強固な防壁により本体へのダメージが大幅に軽減されます。まず左右のサブ砲台を集中破壊することで本体の装甲を破り大ダメージを与えられます。",
		"hint": "攻略要点: サブ砲台の破壊でボス装甲を解除"
	},
	{
		"id": "tip_unparryable",
		"category": "boss",
		"category_name": "ボス",
		"title": "ガード不可攻撃の緊急回避",
		"desc": "画面上部が赤く点灯した際はガード不可能な断絶レーザー攻撃の合図です。シールドを貫通して致命傷を与えるため、照射軸から直ちに機体を横移動させて回避してください。",
		"hint": "警告: 赤色点灯時はシールド無効・即座に離脱"
	},
	{
		"id": "tip_tech_points",
		"category": "upgrade",
		"category_name": "強化要素",
		"title": "調査ポイント(TP)と機体強化",
		"desc": "敵ドローンの撃破やサブ砲台の破壊、ステージクリアによりTPを獲得できます。獲得したTPは技術研究所にて最大HP増加、シールド範囲拡大、新兵装開発に使用します。",
		"hint": "用途: 技術研究所での恒久アップグレード"
	},
	{
		"id": "tip_shield_research",
		"category": "upgrade",
		"category_name": "強化要素",
		"title": "特殊シールドフレームの換装",
		"desc": "標準のカウンターシールドに加え、エナジーオーブを磁力吸引する吸収マトリクスや攻撃力をスタック強化する増幅ブースターが開発可能です。作戦に合わせて自由に換装できます。",
		"hint": "開発: 技術研究所にて各30 TPで開発"
	},
	{
		"id": "tip_counter_only",
		"category": "other",
		"category_name": "その他",
		"title": "極秘作戦：COUNTER ONLY出撃",
		"desc": "ステージ5を5回クリアし150 TPを消費することで解放される特殊作戦です。自機射撃を停止し、常駐する4基の支援砲台部隊が敵を自動殲滅します。",
		"hint": "解放条件: STAGE 5を5回クリア ＆ 150 TP"
	}
]

# Catalog of all 10 Enemy Analysis Mutation Patterns
var analysis_catalog: Dictionary = {
	"rapid": {
		"name": "高速連射",
		"icon": "[RAPID]",
		"color": Color(0.3, 0.8, 1.0),
		"enemy_color": "青色",
		"enemy_type": "直進フォトン弾ドローン",
		"effect": "主兵装の連射速度を+30%〜+50%短縮＆弾速を大幅加速",
		"stats": "連射速度: ＋30%〜50% | 弾速: ＋200〜450",
		"description": "青色ドローンの高速演算機構を解析。主兵装のエネルギー装填サイクルを極限まで短縮し、圧倒的な高速弾速と連射密度を実現する。"
	},
	"spread": {
		"name": "拡散射撃",
		"icon": "[SPREAD]",
		"color": Color(0.2, 1.0, 0.6),
		"enemy_color": "緑色",
		"enemy_type": "拡散ウェイブ弾ドローン",
		"effect": "主兵装の同時発射ライン数を増加（2連装->3連装->多方向拡散）",
		"stats": "同時発射数: ＋1〜3発 | 攻撃範囲: 扇状広域",
		"description": "緑色ドローンの広角プラズマ照射機構を解析。主兵装の射撃ラインを前方扇状に拡張し、複数の敵を一網打尽にする。"
	},
	"pierce": {
		"name": "貫通重弾",
		"icon": "[PIERCE]",
		"color": Color(1.0, 0.6, 0.2),
		"enemy_color": "赤色",
		"enemy_type": "重装甲チャージ砲巡洋艦",
		"effect": "主兵装の弾丸に装甲貫通属性を付与し、単発威力を大幅強化",
		"stats": "単発威力: ＋6〜14 | 貫通数: 1体〜全貫通",
		"description": "赤色大型艦の高密度エネルギー充填コアを解析。主兵装に強力な貫通重力を付与し、硬い敵や後方の敵をまとめて貫通粉砕する。"
	},
	"homing": {
		"name": "誘導弾道",
		"icon": "[HOMING]",
		"color": Color(0.85, 0.45, 1.0),
		"enemy_color": "紫色",
		"enemy_type": "クラスター追尾ミサイル艦",
		"effect": "主兵装の弾道に索敵誘導補正を付与し、敵を自動追尾",
		"stats": "追尾誘導力: ＋2.0〜4.5 | 命中率: 大幅向上",
		"description": "紫色ミサイル艦の生体誘導センサーを解析。主兵装の弾道が最寄りの敵へ向かって弧を描いて自動追尾し、敏捷な敵も逃さず仕留める。"
	},
	"laser": {
		"name": "集束光線",
		"icon": "[LASER]",
		"color": Color(0.4, 0.9, 1.0),
		"enemy_color": "シアン色",
		"enemy_type": "高出力ビーム砲台／要塞光線部",
		"effect": "主兵装をエネルギー集束光線ボルト化（弾速加速＆追加威力を付与）",
		"stats": "光線追加威力: ＋6〜14 | 弾速: ＋150",
		"description": "要塞レーザー砲台の集束照射技術を解析。主兵装の弾丸を高密度エネルギー光線ボルトへ変換し、高い貫通破壊力をもたらす。"
	},
	"cyclone": {
		"name": "旋回スピン",
		"icon": "[CYCLONE]",
		"color": Color(1.0, 0.85, 0.2),
		"enemy_color": "黄色",
		"enemy_type": "不規則旋回ドローン／サイクロンポッド",
		"effect": "主兵装の弾道に螺旋スピン波動を付与し、攻撃幅を大幅拡張",
		"stats": "波動振幅: 80〜160px | 制圧面積: 広域",
		"description": "黄色不規則ドローンのジャイロ運動機構を解析。主兵装の弾道が螺旋状にうねりながら飛翔し、広範囲の敵機を巻き込んで攻撃する。"
	},
	"meteor": {
		"name": "重爆装填",
		"icon": "[METEOR]",
		"color": Color(1.0, 0.35, 0.2),
		"enemy_color": "橙色",
		"enemy_type": "要塞迎撃ギガメテオランチャー",
		"effect": "主兵装の弾丸に着弾時爆裂衝撃波を付与",
		"stats": "爆発半径: 45〜80px | 爆風威力: ＋6〜14",
		"description": "要塞メテオ射出砲の重力破砕技術を解析。主兵装が敵に着弾した瞬間、周囲へ爆発衝撃波が広がり周囲の敵ごと吹き飛ばす。"
	},
	"thunder": {
		"name": "電撃連鎖",
		"icon": "[THUNDER]",
		"color": Color(0.95, 0.9, 0.2),
		"enemy_color": "金色・放電色",
		"enemy_type": "成層圏超放電ストーム／放電ドローン",
		"effect": "主兵装に着弾時連鎖雷撃を付与。周囲の敵・砲台へ最大3〜5連鎖放電！",
		"stats": "連鎖数: 3〜5体 | 雷撃威力: ＋8〜18",
		"description": "成層圏超放電ストームの高圧プラズマアークを解析。弾丸が敵に命中した瞬間、周囲の敵機や砲台へ雷撃が電光石火で連鎖し一網打尽にする。"
	},
	"vortex": {
		"name": "重力特異点",
		"icon": "[VORTEX]",
		"color": Color(0.75, 0.3, 1.0),
		"enemy_color": "深紫色",
		"enemy_type": "特異点重力弾／空間歪曲ユニット",
		"effect": "着弾地点に敵を引き寄せるブラックホール重力場（1.5秒）を生成",
		"stats": "引力半径: 80〜160px | 持続ダメージ: ＋10〜25",
		"description": "深宇宙重力歪曲フィールドを解析。着弾地点に微小ブラックホールを発生させ、周囲の敵やドローンを吸引拘束しながら粉砕する。"
	},
	"blade": {
		"name": "真空斬撃",
		"icon": "[BLADE]",
		"color": Color(0.2, 1.0, 0.85),
		"enemy_color": "青緑色",
		"enemy_type": "超振動カッター／真空スラッシャー",
		"effect": "主兵装を巨大な三日月斬撃波へ変換。敵弾を切り裂きながら多段貫通！",
		"stats": "斬撃幅: 80〜140px | 弾消し性能: 有効",
		"description": "超高周波ブレードの位相切断波を解析。巨大な三日月状の真空カッターを放ち、進行ルート上の敵弾を切り払いながら敵陣を両断する。"
	}
}

var fusion_catalog: Dictionary = {
	"meteor+spread": {
		"name": "クラスター・メテオバースト",
		"title_en": "CLUSTER METEOR BURST",
		"summary": "扇状多弾頭大爆砕弾",
		"description": "広角に散開する巨大隕石弾。着弾時に広範囲の誘爆衝撃波を巻き起こす。",
		"color": Color(1.0, 0.45, 0.2)
	},
	"rapid+spread": {
		"name": "ガトリング・ストーム",
		"title_en": "GATLING STORM",
		"summary": "超高密度扇状弾幕",
		"description": "圧倒的な連射速度と広角掃射により、前方全域を覆い尽くす弾幕の嵐を形成する。",
		"color": Color(0.25, 0.9, 0.8)
	},
	"homing+spread": {
		"name": "マルチロック・スウォーム",
		"title_en": "MULTI-LOCK SWARM",
		"summary": "多目標追尾ミサイル群",
		"description": "扇状に射出された複数の弾丸が、個別に周囲の敵を自動索敵して追尾殲滅する。",
		"color": Color(0.7, 0.5, 1.0)
	},
	"pierce+spread": {
		"name": "クロス・ペネトレーター",
		"title_en": "CROSS PENETRATOR",
		"summary": "扇状多重装甲貫通弾",
		"description": "放射状に放たれる高密度徹甲弾。密集する敵陣と硬質装甲を一瞬で貫き通す。",
		"color": Color(1.0, 0.65, 0.25)
	},
	"laser+spread": {
		"name": "プリズム・ビームアレイ",
		"title_en": "PRISM BEAM ARRAY",
		"summary": "広角拡散集束光線",
		"description": "前方広角に放たれる高密度レーザー群。高速照射で広範囲の敵を蒸発させる。",
		"color": Color(0.35, 0.95, 1.0)
	},
	"spread+thunder": {
		"name": "エレクトリック・スプレッド",
		"title_en": "ELECTRIC SPREAD",
		"summary": "広角放電連鎖ボルト",
		"description": "拡散弾の着弾地点それぞれから高圧アーク放電が周囲の敵機へ連鎖する。",
		"color": Color(0.95, 0.95, 0.3)
	},
	"spread+vortex": {
		"name": "マルチ・グラビティフィールド",
		"title_en": "MULTI GRAVITY FIELD",
		"summary": "広域特異点重力網",
		"description": "複数の着弾地点に敵を引き寄せる重力渦を同時発生させ、敵陣を拘束粉砕する。",
		"color": Color(0.75, 0.35, 1.0)
	},
	"blade+spread": {
		"name": "テンペスト・スラッシュ",
		"title_en": "TEMPEST SLASH",
		"summary": "扇状三日月真空刃",
		"description": "放射状に放たれる巨大な真空カッター。敵弾を切り裂きながら敵前線を両断する。",
		"color": Color(0.2, 1.0, 0.8)
	},
	"cyclone+spread": {
		"name": "スパイラル・ボルテックス",
		"title_en": "SPIRAL VORTEX",
		"summary": "広域螺旋波状弾幕",
		"description": "扇状に広がった弾丸が各々うねるように旋回飛翔し、逃げ場のない弾幕網を作る。",
		"color": Color(1.0, 0.85, 0.2)
	},
	"laser+rapid": {
		"name": "フォトン・リピーター",
		"title_en": "PHOTON REPEATER",
		"summary": "光速超連射ビーム",
		"description": "装填サイクルを極限まで短縮した光速レーザーの乱射。途切れぬ光線が敵を穿つ。",
		"color": Color(0.4, 0.9, 1.0)
	},
	"pierce+rapid": {
		"name": "ハイパー・ニードラー",
		"title_en": "HYPER NEEDLER",
		"summary": "高速超装甲貫通弾",
		"description": "極限連射される極細徹甲弾の奔流。どれほど硬い敵装甲も瞬時に穴だらけにする。",
		"color": Color(1.0, 0.7, 0.3)
	},
	"homing+rapid": {
		"name": "マイクロ・ホーミングガトリング",
		"title_en": "MICRO HOMING GATLING",
		"summary": "超高速追尾弾幕",
		"description": "高速連射される小型追尾弾の群れ。俊敏な敵もロックオンから逃れることはできない。",
		"color": Color(0.85, 0.45, 1.0)
	},
	"meteor+rapid": {
		"name": "ボンバー・バルカン",
		"title_en": "BOMBER VULCAN",
		"summary": "連続重爆裂装填弾",
		"description": "小型爆砕弾を高速連射。着弾地点で連続誘爆が発生し敵陣を制圧する。",
		"color": Color(1.0, 0.4, 0.2)
	},
	"meteor+pierce": {
		"name": "ドリル・メガトンバスター",
		"title_en": "DRILL MEGATON BUSTER",
		"summary": "貫通体内起爆重弾",
		"description": "装甲を貫通しながら内部で超爆発を引き起こす破壊力特化の超重量徹甲爆弾。",
		"color": Color(1.0, 0.5, 0.1)
	},
	"homing+thunder": {
		"name": "テスラ・シーカー",
		"title_en": "TESLA SEEKER",
		"summary": "必中連鎖電磁ボルト",
		"description": "確実に敵を捉える誘導弾が命中した瞬間、周囲の敵機へ強烈な電撃が自動連鎖する。",
		"color": Color(0.9, 0.85, 0.25)
	},
	"homing+vortex": {
		"name": "シンギュラリティ・ミサイル",
		"title_en": "SINGULARITY MISSILE",
		"summary": "誘導特異点弾頭",
		"description": "敵を自動追尾して直撃。直撃地点に局所ブラックホールを生成し敵を閉じ込める。",
		"color": Color(0.7, 0.3, 0.95)
	},
	"blade+laser": {
		"name": "光子断絶ブレード",
		"title_en": "PHOTON RUPTURE BLADE",
		"summary": "光速超切断レーザー刃",
		"description": "光速の推進力と超位相切断力を併せ持つ長距離斬撃。敵弾を蒸発させ敵を両断する。",
		"color": Color(0.3, 1.0, 0.95)
	},
	"meteor+vortex": {
		"name": "スーパーノヴァ・イグニッション",
		"title_en": "SUPERNOVA IGNITION",
		"summary": "引力爆砕ブラックホール",
		"description": "周囲の敵を重力特異点に一気に吸引拘束し、中心で超新星大爆発を引き起こす。",
		"color": Color(1.0, 0.3, 0.6)
	},
	"blade+cyclone": {
		"name": "ツイスター・スラッシャー",
		"title_en": "TWISTER SLASHER",
		"summary": "巨大旋回回転斬撃",
		"description": "渦を巻きながら飛翔する巨大な真空回転刃。自機前方の広大な空間の敵弾を薙ぎ払う。",
		"color": Color(0.3, 1.0, 0.7)
	},
	"laser+pierce": {
		"name": "リニア・レールキャノン",
		"title_en": "LINEAR RAIL CANNON",
		"summary": "極限貫通フォトン砲",
		"description": "射線上のあらゆる敵と障害物を完全に貫通・融解させる究極の直線火砲。",
		"color": Color(0.4, 0.85, 1.0)
	}
}

func get_fusion_info(trait_a: String, trait_b: String) -> Dictionary:
	var keys = [trait_a.to_lower(), trait_b.to_lower()]
	keys.sort()
	var pair_key = "%s+%s" % [keys[0], keys[1]]
	
	if fusion_catalog.has(pair_key):
		return fusion_catalog[pair_key]
		
	# カタログ未登録ペアの動的生成
	var name_a = analysis_catalog.get(trait_a, {}).get("name", trait_a)
	var name_b = analysis_catalog.get(trait_b, {}).get("name", trait_b)
	return {
		"name": "複合融合: %s × %s" % [name_a, name_b],
		"title_en": "DUAL FUSION WEAPON",
		"summary": "特性融合兵装",
		"description": "%s と %s の特性を融合したハイブリッド兵装。" % [name_a, name_b],
		"color": Color.CYAN
	}

func get_fusion_name(trait_a: String, trait_b: String) -> String:
	return get_fusion_info(trait_a, trait_b).get("name", "複合融合兵装")

func is_stage_unlocked(stage_num: int) -> bool:
	return stage_num == 1 or unlocked_stages.has(stage_num)

func unlock_stage(stage_num: int) -> bool:
	if not unlocked_stages.has(stage_num):
		unlocked_stages.append(stage_num)
		unlocked_stages.sort()
		save_game()
		return true
	return false

func get_stage_difficulty_multiplier(stage_num: int) -> float:
	# ステージが進むごとの敵の強さ（HP・攻撃力）の上昇率を大幅に緩和
	# Stage 1: 1.000x, Stage 2: 1.080x, Stage 3: 1.166x, Stage 4: 1.260x, Stage 5: 1.360x
	var exp_step = max(0, stage_num - 1)
	return pow(1.08, float(exp_step))

# Weapon Dictionary Definition
var available_weapons: Dictionary = {
	"machine_gun": {
		"name": "マシンガン",
		"description": "標準的な物理連射弾。高速連射と安定した制圧力を持つ主兵装。",
		"stats": "連射:★★★ | 威力:★★☆ | 弾速:★★☆",
		"unlocked": true
	},
	"burst_rifle": {
		"name": "ライフル (3点バースト)",
		"description": "単発火力・射程重視の徹甲3連射ライフル。硬い敵を貫通粉砕する。",
		"stats": "連射:★★☆ | 威力:★★★ | 弾速:★★★",
		"unlocked": true
	},
	"pulse_gun": {
		"name": "パルスガン",
		"description": "扇状に広がるプラズマ波動弾。広範囲の雑魚敵を一網打尽にする。",
		"stats": "連射:★★★ | 威力:★★☆ | 弾速:★☆☆",
		"unlocked": true
	},
	"plasma_emitter": {
		"name": "プラズマ放射器",
		"description": "超高熱のプラズマ球を射出。着弾時に持続放電フィールドを形成する。",
		"stats": "連射:★★☆ | 威力:★★★ | 弾速:★☆☆",
		"unlocked": false
	},
	"kinetic_tackle": {
		"name": "キネティックタックル",
		"description": "機体前方に強力な衝撃破砕波を発生させる超近接・突撃用兵装。",
		"stats": "連射:★☆☆ | 威力:★★★ | 弾速:★★☆",
		"unlocked": false
	}
}

# Player Appearance variables
var player_color: String = "blue"
var available_player_colors: Dictionary = {
	"blue": {
		"name": "コバルトブルー (標準)",
		"path": "res://game/assets/player/spaceship_small_blue.png",
		"accent_color": Color(0.2, 0.65, 1.0)
	},
	"red": {
		"name": "クリムゾンレッド",
		"path": "res://game/assets/player/spaceship_small_red.png",
		"accent_color": Color(1.0, 0.3, 0.3)
	},
	"green": {
		"name": "エメラルドグリーン",
		"path": "res://game/assets/player/spaceship_small_green.png",
		"accent_color": Color(0.2, 0.9, 0.4)
	},
	"yellow": {
		"name": "トパーズイエロー",
		"path": "res://game/assets/player/spaceship_small_yellow.png",
		"accent_color": Color(1.0, 0.85, 0.2)
	},
	"purple": {
		"name": "アメジストパープル",
		"path": "res://game/assets/player/spaceship_small_purple.png",
		"accent_color": Color(0.8, 0.35, 1.0)
	},
	"orange": {
		"name": "ソーラーオレンジ",
		"path": "res://game/assets/player/spaceship_small_orange.png",
		"accent_color": Color(1.0, 0.55, 0.1)
	}
}

func get_player_texture_path(color_key: String = "") -> String:
	var key = color_key if color_key != "" else player_color
	if available_player_colors.has(key):
		return available_player_colors[key]["path"]
	return "res://game/assets/player/spaceship_small_blue.png"

# Settings variables
var master_volume: float = 80.0
var bgm_volume: float = 80.0
var sfx_volume: float = 80.0
var screen_shake: bool = true
var window_mode: int = 0 # 0: Windowed, 1: Fullscreen, 2: Borderless Windowed
var window_scale: float = 1.0 # 0.5, 0.75, 1.0, 1.25, 1.5
var aspect_ratio: int = 0 # 0: 2:3, 1: 3:4, 2: 9:16
var vsync: bool = true

func _ready() -> void:
	load_settings()
	check_save_game()
	apply_all_settings()
	init_sound_pool()

func check_save_game() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		has_save = true
	else:
		has_save = false

var tutorial_flags: Dictionary = {
	"controls": false,
	"weapon_analysis": false,
	"time_limit": false,
	"boss_info": false
}

func save_game(stage_num: int = -1, score: int = -1, weapons: Dictionary = {}) -> void:
	var config = ConfigFile.new()
	var prev_stage = 1
	var prev_score = 0
	if config.load(SAVE_PATH) == OK:
		prev_stage = config.get_value("game", "stage_num", 1)
		prev_score = config.get_value("game", "score", 0)
		
	var final_stage = stage_num if stage_num > 0 else prev_stage
	var final_score = score if score >= 0 else prev_score
	
	config.set_value("game", "stage_num", final_stage)
	config.set_value("game", "score", final_score)
	config.set_value("game", "weapons", weapons)
	config.set_value("game", "equipped_weapon", equipped_weapon)
	config.set_value("game", "is_first_launch", is_first_launch)
	config.set_value("game", "tech_points", tech_points)
	config.set_value("game", "equipped_shield", equipped_shield)
	config.set_value("game", "unlocked_shields", unlocked_shields)
	config.set_value("game", "unlocked_weapons", unlocked_weapons)
	config.set_value("game", "unlocked_counter_weapons", unlocked_counter_weapons)
	config.set_value("game", "unlocked_stages", unlocked_stages)
	config.set_value("game", "discovered_analysis_weapons", discovered_analysis_weapons)
	config.set_value("game", "upgrade_levels", upgrade_levels)
	config.set_value("game", "shield_radius_upgrades", shield_radius_upgrades)
	config.set_value("game", "just_guard_focus_mode", just_guard_focus_mode)
	config.set_value("game", "counter_system_duration_lvl", counter_system_duration_lvl)
	config.set_value("game", "counter_system_power_lvl", counter_system_power_lvl)
	config.set_value("game", "stage5_clears_count", stage5_clears_count)
	config.set_value("game", "counter_only_mode_unlocked", counter_only_mode_unlocked)
	config.set_value("game", "counter_only_mode_enabled", counter_only_mode_enabled)
	config.set_value("game", "hard_mode_enabled", hard_mode_enabled)
	config.set_value("game", "unlocked_tips", unlocked_tips)
	config.set_value("game", "unread_tips", unread_tips)
	config.set_value("game", "tutorial_flags", tutorial_flags)
	config.save(SAVE_PATH)
	has_save = true

func load_game_data(sync_globals: bool = true) -> Dictionary:
	var config = ConfigFile.new()
	var data = {
		"stage_num": 1,
		"score": 0,
		"weapons": {},
		"equipped_weapon": equipped_weapon,
		"is_first_launch": is_first_launch,
		"tech_points": tech_points,
		"equipped_shield": equipped_shield,
		"unlocked_shields": unlocked_shields,
		"unlocked_weapons": unlocked_weapons,
		"unlocked_counter_weapons": unlocked_counter_weapons,
		"unlocked_stages": unlocked_stages,
		"discovered_analysis_weapons": discovered_analysis_weapons,
		"upgrade_levels": upgrade_levels,
		"shield_radius_upgrades": shield_radius_upgrades,
		"just_guard_focus_mode": just_guard_focus_mode,
		"counter_system_duration_lvl": counter_system_duration_lvl,
		"counter_system_power_lvl": counter_system_power_lvl,
		"stage5_clears_count": stage5_clears_count,
		"counter_only_mode_unlocked": counter_only_mode_unlocked,
		"counter_only_mode_enabled": counter_only_mode_enabled,
		"hard_mode_enabled": hard_mode_enabled,
		"unlocked_tips": ["tip_move", "tip_shoot"],
		"unread_tips": ["tip_move", "tip_shoot"],
		"tutorial_flags": tutorial_flags
	}
	if config.load(SAVE_PATH) == OK:
		data["stage_num"] = config.get_value("game", "stage_num", 1)
		data["score"] = config.get_value("game", "score", 0)
		data["weapons"] = config.get_value("game", "weapons", {})
		data["equipped_weapon"] = config.get_value("game", "equipped_weapon", equipped_weapon)
		data["is_first_launch"] = config.get_value("game", "is_first_launch", true)
		data["tech_points"] = config.get_value("game", "tech_points", 0)
		data["equipped_shield"] = config.get_value("game", "equipped_shield", equipped_shield)
		data["unlocked_shields"] = config.get_value("game", "unlocked_shields", ["counter"])
		data["unlocked_weapons"] = config.get_value("game", "unlocked_weapons", ["machine_gun", "burst_rifle", "pulse_gun"])
		data["unlocked_counter_weapons"] = config.get_value("game", "unlocked_counter_weapons", [])
		data["unlocked_stages"] = config.get_value("game", "unlocked_stages", [1])
		data["discovered_analysis_weapons"] = config.get_value("game", "discovered_analysis_weapons", [])
		data["upgrade_levels"] = config.get_value("game", "upgrade_levels", {"hp": 0, "parry_window": 0, "cooldown": 0})
		data["shield_radius_upgrades"] = config.get_value("game", "shield_radius_upgrades", {"counter": 0, "gauge": 0, "power": 0})
		data["just_guard_focus_mode"] = config.get_value("game", "just_guard_focus_mode", 0)
		data["counter_system_duration_lvl"] = config.get_value("game", "counter_system_duration_lvl", 0)
		data["counter_system_power_lvl"] = config.get_value("game", "counter_system_power_lvl", 0)
		data["stage5_clears_count"] = config.get_value("game", "stage5_clears_count", 0)
		data["counter_only_mode_unlocked"] = config.get_value("game", "counter_only_mode_unlocked", false)
		data["counter_only_mode_enabled"] = config.get_value("game", "counter_only_mode_enabled", false)
		data["hard_mode_enabled"] = config.get_value("game", "hard_mode_enabled", false)
		data["unlocked_tips"] = config.get_value("game", "unlocked_tips", ["tip_move", "tip_shoot"])
		data["unread_tips"] = config.get_value("game", "unread_tips", ["tip_move", "tip_shoot"])
		data["tutorial_flags"] = config.get_value("game", "tutorial_flags", {
			"controls": false,
			"weapon_analysis": false,
			"time_limit": false,
			"boss_info": false
		})
		
		if sync_globals:
			equipped_weapon = data["equipped_weapon"]
			is_first_launch = data["is_first_launch"]
			tech_points = data["tech_points"]
			equipped_shield = data["equipped_shield"]
			unlocked_shields = data["unlocked_shields"]
			unlocked_weapons = data["unlocked_weapons"]
			unlocked_counter_weapons = data["unlocked_counter_weapons"]
			unlocked_stages = data["unlocked_stages"]
			if not unlocked_stages.has(1):
				unlocked_stages.append(1)
				unlocked_stages.sort()
			discovered_analysis_weapons = data["discovered_analysis_weapons"]
			upgrade_levels = data["upgrade_levels"]
			shield_radius_upgrades = data["shield_radius_upgrades"]
			just_guard_focus_mode = data["just_guard_focus_mode"]
			counter_system_duration_lvl = data["counter_system_duration_lvl"]
			counter_system_power_lvl = data["counter_system_power_lvl"]
			stage5_clears_count = data["stage5_clears_count"]
			counter_only_mode_unlocked = data["counter_only_mode_unlocked"]
			counter_only_mode_enabled = data["counter_only_mode_enabled"]
			hard_mode_enabled = data["hard_mode_enabled"]
			unlocked_tips = data["unlocked_tips"]
			unread_tips = data["unread_tips"]
			tutorial_flags = data["tutorial_flags"]
	return data

func reset_upgrade_levels() -> void:
	upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0}
	shield_radius_upgrades = {"counter": 0, "gauge": 0, "power": 0}
	just_guard_focus_mode = 0
	counter_system_duration_lvl = 0
	counter_system_power_lvl = 0
	save_game()

func reset_tech_points() -> void:
	tech_points = 0
	save_game()

func reset_development_progress() -> void:
	discovered_analysis_weapons = []
	unlocked_weapons = ["machine_gun", "burst_rifle", "pulse_gun"]
	unlocked_counter_weapons = []
	unlocked_shields = ["counter"]
	equipped_shield = "counter"
	equipped_weapon = "machine_gun"
	unlocked_stages = [1]
	shield_radius_upgrades = {"counter": 0, "gauge": 0, "power": 0}
	just_guard_focus_mode = 0
	counter_system_duration_lvl = 0
	counter_system_power_lvl = 0
	stage5_clears_count = 0
	counter_only_mode_unlocked = false
	counter_only_mode_enabled = false
	tutorial_flags = {
		"controls": false,
		"weapon_analysis": false,
		"time_limit": false,
		"boss_info": false
	}
	save_game()

func delete_save_game() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		if dir.file_exists("savegame.cfg"):
			dir.remove("savegame.cfg")
	has_save = false
	is_continue = false
	equipped_weapon = "machine_gun"
	is_first_launch = true
	tech_points = 0
	equipped_shield = "counter"
	unlocked_shields = ["counter"]
	unlocked_weapons = ["machine_gun", "burst_rifle", "pulse_gun"]
	unlocked_counter_weapons = []
	unlocked_stages = [1]
	discovered_analysis_weapons = []
	upgrade_levels = {"hp": 0, "parry_window": 0, "cooldown": 0}
	shield_radius_upgrades = {"counter": 0, "gauge": 0, "power": 0}
	just_guard_focus_mode = 0
	counter_system_duration_lvl = 0
	counter_system_power_lvl = 0
	stage5_clears_count = 0
	counter_only_mode_unlocked = false
	counter_only_mode_enabled = false
	unlocked_tips = ["tip_move", "tip_shoot"]
	unread_tips = ["tip_move", "tip_shoot"]
	tutorial_flags = {
		"controls": false,
		"weapon_analysis": false,
		"time_limit": false,
		"boss_info": false
	}

# --- TIPS 戦術アーカイブ ヘルパー関数 ---

func unlock_next_tip() -> String:
	for tip in tips_catalog:
		var tip_id: String = tip["id"]
		if not unlocked_tips.has(tip_id):
			unlocked_tips.append(tip_id)
			unread_tips.append(tip_id)
			save_game()
			return tip["title"]
	return ""

func mark_tip_as_read(tip_id: String) -> void:
	if unread_tips.has(tip_id):
		unread_tips.erase(tip_id)
		save_game()

func is_tip_unread(tip_id: String) -> bool:
	return unread_tips.has(tip_id)

func get_unread_tips_count() -> int:
	return unread_tips.size()

var readable_font: Font = null

func get_readable_font() -> Font:
	if readable_font == null:
		var sf = SystemFont.new()
		sf.font_names = PackedStringArray([
			"Yu Gothic UI",
			"Meiryo",
			"Hiragino Sans",
			"Hiragino Kaku Gothic ProN",
			"Noto Sans CJK JP",
			"Noto Sans JP",
			"MS Gothic",
			"sans-serif"
		])
		sf.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		readable_font = sf
	return readable_font

# --- COUNTER SYSTEM パラメータ計算 ---

func get_counter_system_duration() -> float:
	# 10.0秒 -> 12.0秒 -> 14.0秒 -> 16.0秒 -> 18.0秒 -> 20.0秒
	return 10.0 + counter_system_duration_lvl * 2.0

func get_counter_system_power_multiplier() -> float:
	# 1.0倍 -> 1.2倍 -> 1.5倍 -> 2.0倍 -> 3.0倍 -> 5.0倍
	match counter_system_power_lvl:
		0: return 1.0
		1: return 1.2
		2: return 1.5
		3: return 2.0
		4: return 3.0
		5: return 5.0
	return 1.0

# --- ジャストガード判定範囲 ＆ 威力倍率の計算 ---

func get_just_guard_radius(shield_type: String = "") -> float:
	var s_type = shield_type if shield_type != "" else equipped_shield
	var s_lvl = shield_radius_upgrades.get(s_type, 0)
	var global_window_lvl = upgrade_levels.get("parry_window", 0)
	
	# シールド別基礎半径
	var base_radius = 85.0
	match s_type:
		"counter":
			base_radius = 85.0 + s_lvl * 6.0 + global_window_lvl * 4.0
		"gauge":
			# 吸収マトリクス: 広域吸収仕様
			base_radius = 105.0 + s_lvl * 8.0 + global_window_lvl * 4.0
		"power":
			# パワーシールド: タイトな集中仕様
			base_radius = 75.0 + s_lvl * 5.0 + global_window_lvl * 4.0
			
	# フォーカス設定による範囲補正
	var focus_mult = 1.0
	match just_guard_focus_mode:
		0: focus_mult = 1.00 # STANDARD: 100%
		1: focus_mult = 0.75 # FOCUS: 75%
		2: focus_mult = 0.50 # PINPOINT: 50%
		
	return base_radius * focus_mult

func get_just_guard_damage_multiplier() -> float:
	# フォーカス設定によるジャストガード反射威力倍率
	match just_guard_focus_mode:
		0: return 1.00 # 標準
		1: return 1.50 # 集中: 1.5倍 (+50%)
		2: return 2.20 # 極小ピンポイント: 2.2倍 (+120%)
	return 1.00

func get_focus_mode_info(mode: int = -1) -> Dictionary:
	var m = mode if mode >= 0 else just_guard_focus_mode
	match m:
		0:
			return {
				"mode": 0,
				"name": "STANDARD [標準範囲]",
				"radius_pct": "100%",
				"dmg_mult": "1.0倍",
				"description": "安定した標準範囲でのジャストガード。安全な防御重視モード。"
			}
		1:
			return {
				"mode": 1,
				"name": "FOCUS [集中]",
				"radius_pct": "75% (-25%)",
				"dmg_mult": "1.5倍 (+50%)",
				"description": "有効範囲を25%絞る代わりに、ジャストガード反射弾の威力が1.5倍に強化。"
			}
		2:
			return {
				"mode": 2,
				"name": "PINPOINT [極小高出力]",
				"radius_pct": "50% (-50%)",
				"dmg_mult": "2.2倍 (+120%)",
				"description": "有効範囲が半分になるハイリスク設定。成功時は反射弾が2.2倍の壊滅的破壊力に跳ね上がる！"
			}
	return {}

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "bgm_volume", bgm_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "window_scale", window_scale)
	config.set_value("display", "aspect_ratio", aspect_ratio)
	config.set_value("display", "vsync", vsync)
	config.set_value("gameplay", "screen_shake", screen_shake)
	config.set_value("player", "player_color", player_color)
	config.save(SETTINGS_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = config.get_value("audio", "master_volume", 80.0)
		bgm_volume = config.get_value("audio", "bgm_volume", 80.0)
		sfx_volume = config.get_value("audio", "sfx_volume", 80.0)
		window_mode = config.get_value("display", "window_mode", 0)
		window_scale = config.get_value("display", "window_scale", 1.0)
		aspect_ratio = config.get_value("display", "aspect_ratio", 0)
		vsync = config.get_value("display", "vsync", true)
		screen_shake = config.get_value("gameplay", "screen_shake", true)
		player_color = config.get_value("player", "player_color", "blue")

func apply_all_settings() -> void:
	apply_audio()
	apply_display()

func apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("BGM", bgm_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("UI", sfx_volume)

func _set_bus_volume(bus_name: String, val: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db = -60.0 if val <= 0.0 else linear_to_db(val / 100.0)
		AudioServer.set_bus_volume_db(idx, db)

func apply_display() -> void:
	var win: Window = null
	var tree = get_tree()
	if tree and tree.root:
		win = tree.root.get_window()

	# Determine base content resolution based on aspect ratio
	var base_w = 800
	var base_h = 1200
	match aspect_ratio:
		0: # 2:3
			base_w = 800
			base_h = 1200
		1: # 3:4
			base_w = 900
			base_h = 1200
		2: # 9:16
			base_w = 675
			base_h = 1200

	# Ensure Godot 4 automatically scales all canvas items, fonts, and UI with the window size
	if win:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		win.content_scale_size = Vector2i(base_w, base_h)

	# Target physical window size
	var target_w = int(base_w * window_scale)
	var target_h = int(base_h * window_scale)
	var target_size = Vector2i(target_w, target_h)

	# Window mode settings
	match window_mode:
		0: # Windowed
			if win:
				win.mode = Window.MODE_WINDOWED
				win.borderless = false
				win.size = target_size
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(target_size)
		1: # Fullscreen
			if win:
				win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2: # Borderless Windowed
			if win:
				win.mode = Window.MODE_WINDOWED
				win.borderless = true
				win.size = target_size
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(target_size)
		
	# V-Sync
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

func auto_scale_display() -> void:
	# One-touch optimizer: scales to fit vertical aspect of screen y-resolution
	var screen_size = DisplayServer.screen_get_size()
	var monitor_height = screen_size.y
	
	# Keep a safety margin for windows title bar and OS taskbar
	var target_height = monitor_height - 120
	target_height = clamp(target_height, 600, 1200)
	
	var target_width = int(target_height * (2.0 / 3.0))
	var target_size = Vector2i(target_width, target_height)
	
	var win: Window = null
	var tree = get_tree()
	if tree and tree.root:
		win = tree.root.get_window()
		
	if win:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		win.content_scale_size = Vector2i(800, 1200)
		win.mode = Window.MODE_WINDOWED
		win.borderless = false
		win.size = target_size
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(target_size)
	
	# Recalculate and update current scale setting
	window_scale = snapped(float(target_height) / 1200.0, 0.05)
	window_mode = 0
	
	# Center the window
	var screen_pos = DisplayServer.screen_get_position()
	var window_pos = screen_pos + Vector2i((Vector2(screen_size - target_size) * 0.5).round())
	window_pos.y = max(window_pos.y, 40)
	if win:
		win.position = window_pos
	else:
		DisplayServer.window_set_position(window_pos)
	
	save_settings()


# ==========================================
# プロシージャル効果音生成・再生システム (Global Sound System)
# ==========================================

var _sfx_sounds: Dictionary = {}
var _sfx_player_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 14
var _sfx_pool_index: int = 0
var _sfx_last_play_times: Dictionary = {}

func init_sound_pool() -> void:
	# サウンドプールの作成
	for i in range(_sfx_pool_size):
		var asp = AudioStreamPlayer.new()
		asp.bus = "SFX"
		add_child(asp)
		_sfx_player_pool.append(asp)
		
	# プロシージャルサウンドの生成・キャッシュ (8-bit PCM波形)
	_sfx_sounds["hit"] = _create_hit_sound(0.045, 950.0, 0.4, 0.5)
	_sfx_sounds["guard"] = _create_guard_sound(0.06, 1800.0)
	_sfx_sounds["parry"] = _create_parry_sound(0.18)
	_sfx_sounds["heavy_hit"] = _create_heavy_hit_sound(0.08, 420.0)
	_sfx_sounds["explosion"] = _create_explosion_sound(0.25)
	_sfx_sounds["turret_destroy"] = _create_explosion_sound(0.18)
	_sfx_sounds["laser"] = _create_laser_sound(0.12)


func play_sound(sound_name: String, pitch_scale: float = 1.0, min_interval: float = 0.03) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sound_name, pitch_scale, min_interval)
		return
		
	if _sfx_sounds.is_empty():
		init_sound_pool()
		
	var now = Time.get_ticks_msec() / 1000.0
	if _sfx_last_play_times.has(sound_name):
		if now - _sfx_last_play_times[sound_name] < min_interval:
			return
	_sfx_last_play_times[sound_name] = now
	
	if not _sfx_sounds.has(sound_name):
		return
		
	if _sfx_player_pool.is_empty():
		return
		
	var asp = _sfx_player_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_player_pool.size()
	
	asp.stream = _sfx_sounds[sound_name]
	asp.pitch_scale = pitch_scale * randf_range(0.95, 1.05)
	asp.play()


func play_hit(pitch: float = 1.0) -> void:
	play_sound("hit", pitch, 0.035)


func play_guard(pitch: float = 1.0) -> void:
	play_sound("guard", pitch, 0.04)


func play_parry(pitch: float = 1.0) -> void:
	play_sound("parry", pitch, 0.03)


func play_heavy_hit(pitch: float = 1.0) -> void:
	play_sound("heavy_hit", pitch, 0.04)


func play_explosion(pitch: float = 1.0) -> void:
	play_sound("explosion", pitch, 0.08)


func play_laser(pitch: float = 1.0) -> void:
	play_sound("laser", pitch, 0.04)


func play_upgrade_success(pitch: float = 1.0) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_upgrade_success"):
		audio_mgr.play_upgrade_success()
	else:
		play_sound("upgrade", pitch, 0.05)


func play_ui_select() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_ui_select"):
		audio_mgr.play_ui_select()


func play_ui_cancel() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_ui_cancel"):
		audio_mgr.play_ui_cancel()


func _exit_tree() -> void:
	for asp in _sfx_player_pool:
		if is_instance_valid(asp):
			asp.stop()


# --- プロシージャル波形生成ヘルパー (44.1kHz 標準サンプリングレート) ---

func _create_parry_sound(duration: float = 0.18) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 13.0)
		# 鋭い金属共鳴ベル倍音 (2800Hz, 4200Hz, 5600Hz, 8400Hz)
		var f1 = sin(TAU * 2800.0 * t) * 0.45
		var f2 = sin(TAU * 4200.0 * t) * 0.30
		var f3 = sin(TAU * 5600.0 * t) * 0.20
		var f4 = sin(TAU * 8400.0 * t) * 0.12
		var ping = (f1 + f2 + f3 + f4)
		var click = (randf() * 2.0 - 1.0) * exp(-progress * 90.0) * 0.9
		var sample = (ping * 0.82 + click * 0.38) * env
		var byte_val = int(clamp((sample + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _create_hit_sound(duration: float, start_freq: float, noise_mix: float, tone_mix: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 14.0)
		var freq = start_freq * (1.0 - progress * 0.7)
		var tone = sin(TAU * freq * t)
		var noise = randf() * 2.0 - 1.0
		var sample = (tone * tone_mix + noise * noise_mix) * env
		var byte_val = int(clamp((sample * 0.85 + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _create_guard_sound(duration: float, freq: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 18.0)
		var tone1 = sin(TAU * freq * t)
		var tone2 = sin(TAU * (freq * 1.48) * t) * 0.5
		var noise = (randf() * 2.0 - 1.0) * 0.2
		var sample = (tone1 + tone2 + noise) * env * 0.8
		var byte_val = int(clamp((sample + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _create_heavy_hit_sound(duration: float, start_freq: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 9.0)
		var freq = start_freq * (1.0 - progress * 0.6)
		var tone = sin(TAU * freq * t) + sin(TAU * (freq * 0.5) * t) * 0.5
		var noise = (randf() * 2.0 - 1.0) * 0.5
		var sample = (tone * 0.6 + noise * 0.4) * env * 0.9
		var byte_val = int(clamp((sample + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _create_explosion_sound(duration: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 6.0)
		var low_rumble = sin(TAU * (120.0 * (1.0 - progress * 0.8)) * t) * 0.5
		var noise = (randf() * 2.0 - 1.0) * 0.8
		var sample = (low_rumble + noise) * env * 0.85
		var byte_val = int(clamp((sample + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _create_laser_sound(duration: float = 0.12) -> AudioStreamWAV:
	var sample_rate = 44100
	var sample_count = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count)
	
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 8.0)
		var freq = 2200.0 * (1.0 - progress * 0.75) + 300.0
		var tone = sin(TAU * freq * t)
		var sample = tone * env * 0.85
		var byte_val = int(clamp((sample + 1.0) * 127.5, 0, 255))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav
