# COUNTER CORE (仮) - 詳細移行設計書 ＆ ステージ1実装仕様

本ドキュメントは、プロトタイプ（`shooting-v1`）から本番試作環境（`shooting-v2`）への移行プロセス、および企画書（`企画書.pdf`/`企画書.pptx`）に基づいた**ステージ1の試作開発**のための、詳細な実装仕様・システム設計図です。

---

## 1. プロトタイプ（`shooting-v1`）のシステム解析

プロトタイプで実装された各スクリプトの役割、メンバ変数、およびAPI仕様の詳細です。

### 1-1. Player.gd (プレイヤー機体)
- **役割**: 移動制御、画面内クランプ、自動通常弾発射、および敵弾に対するジャストガード（パリィ）の判定。
- **メンバ変数**:
  - `speed: float = 300.0` - 移動速度。
  - `parry_window_radius: float = 30.0` - パリィ判定用の判定半径（px）。
  - `fire_cooldown: float = 0.1` - 通常自動射撃の間隔秒。
  - `hp: int = 100` - プレイヤーの最大HP。
  - `parry_charge: float = 0.0` - 反撃用エネルギーゲージ（0〜100）。
- **主要メソッド**:
  - `_physics_process(delta)`: WASD/矢印キーから入力ベクトルを算出し、`velocity` を設定して `move_and_slide()` を実行。プレイヤー座標を画面サイズ（デフォルト: 800x1200）内に `clamp` する。
  - `check_parry()`: 画面内の「敵所有」の弾リストを巡回し、自身との距離が `parry_window_radius` 以下の弾があるか判定。存在する場合、その弾の `convert_to_friendly()` を呼び出す。
  - `fire()`: 前方に向けてプレイヤー弾（`PlayerBullet`）をインスタンス化して発射。

### 1-2. Boss.gd (巨大ボス)
- **役割**: 画面上部に固定配置され、HPに連動して複数のフェーズパターンで敵弾を発射する。
- **メンバ変数**:
  - `max_hp: int = 900` (各フェーズ 300HP × 3フェーズ)。
  - `current_hp: int = 900`
  - `current_phase: int = 1`
  - `fire_timer: float = 0.0`
- **主要メソッド**:
  - `_process(delta)`: フェーズに応じた周期で弾幕発射関数を呼び出す。
  - `take_damage(amount)`: ダメージを受け、閾値（HP 600以下でフェーズ2、300以下でフェーズ3）に達した際に `change_phase()` を実行。
  - `fire_phase1()`: 扇状5方向への放射射撃。
  - `fire_phase2()`: 全方位15方向への円形射撃。
  - `fire_phase3()`: 画面全体を覆う50発の螺旋・ランダム弾幕。

### 1-3. EnemyBullet.gd (敵弾)
- **役割**: 速度移動、画面外でのプールへの返却、およびプレイヤーによるパリィ成功時の「味方弾化」処理。
- **メンバ変数**:
  - `speed: float = 200.0`
  - `direction: Vector2 = Vector2.DOWN`
  - `is_friendly: bool = false` - プレイヤーのものに変換されたかのフラグ。
- **主要メソッド**:
  - `_process(delta)`: `direction * speed * delta` で移動。画面外に出た場合は `BulletPool.return_bullet(self)` でプールに回収。
  - `convert_to_friendly()`: `is_friendly = true` に変更。`direction` ベクトルを反転（$-direction$、あるいはボス方向へロックオン）、スプライト色を白から青/シアンへ変更し、パリィパーティクルを生成。

### 1-4. BulletPool.gd (弾オブジェクトプール)
- **役割**: ガベージコレクション（GC）による処理落ちを防ぐため、頻繁に生成・破棄される敵弾ノードを事前生成して管理する。
- **主要メソッド**:
  - `get_bullet() -> EnemyBullet`: プール内に未使用の弾があればそれをアクティブ化して返し、なければ新規にインスタンス化（`enemy_bullet.tscn`）する。
  - `return_bullet(bullet: EnemyBullet)`: 弾を非表示・非アクティブ（`set_process(false)`）にし、プールにストックする。

### 1-5. GameManager.gd ＆ UI.gd
- **GameManager**: ゲーム全体の進行（勝利・敗北判定、シーンリスタート、スコアとパリィ回数の記録）を管理。
- **UI**: プレイヤーおよびボスのHPバー、現在のパリィ数、反撃ゲージ（変異進行度）の描画更新。

---

## 2. Godot 4.6 プロジェクト基本構成（v2）

`shooting-v2` では、以下のプロジェクト設定が適用されています。

- **解像度**: 縦スクロールSTGに最適化された **幅 800px × 高さ 1200px**。
- **物理エンジン**: `Jolt Physics 3D`（本プロジェクトは2Dベースですが、3D物理ライブラリとしてJoltが指定されています。2D物理は標準のGodot 2D Physicsを使用）。
- **描画ドライバ**: Windows環境では `d3d12` (Direct3D 12) を優先、レンダラーは `Forward Plus`。
- **ゲームルート**: 全ての動的リソースは `res://game/` 配下に格納し、ルートディレクトリはアセット配置から分離。

---

## 3. 企画書（`企画書.pdf` / `企画書.pptx`）の要件分析

企画書スライドから抽出された、ステージ1で満たすべきシステム仕様です。

### 3-1. リスク ＆ リターン設計
- **ガードのクールダウン（CD）**: ガード（パリィ判定）は常時展開できず、クールダウンが存在する。タイミングよく発動する（ジャストガード）ことで、初めて**「ノーダメージ ＋ 反射強化弾」**の恩恵が得られる。
- **敵弾密度の増大**: ボスの形態移行によって敵弾が激化するほど、パリィによって回収・反射できる弾数が増え、プレイヤーの火力が飛躍的に高まる設計にする。

### 3-2. 初期装備とローグライク強化（雑魚戦）
- **初期装備（武器選択）**:
  - **バーストライフル**: 3点バースト射撃。ダメージが高く、リズミカルに攻撃可能。
  - **チャージライフル**: 5秒間チャージすることで極太のビームを発射。一撃が非常に強力。
- **雑魚戦（1〜2分）でのランダム強化**:
  - 敵がドロップする強化パーツを拾うことで、与ダメージUP、弾の追尾（ホーミング）、連射力UP、範囲攻撃（炸裂弾）がそのプレイ中のみ適用される。

### 3-3. ボス戦：部位破壊 ＆ COUNTER CORE 状態
- **部位破壊**:
  - ボスは単一の衝突判定ではなく、複数の部位（例：左右のシールド、武装砲台、メインコア）に判定が分かれている。
  - 各部位を破壊するごとに、ボス本体の最大HPに大きな割合ダメージがフィードバックされる。
- **COUNTER CORE状態**:
  - ボス戦のクライマックス等で発動する超必殺モード。数秒間、プレイヤーのガードが自動で超高速連打状態（または常時パリィ判定展開状態）になり、ボスの全画面弾幕をすべて吸収して一斉にボスに撃ち返す。

---

## 4. 移行（Migration）ルールとパス置換マップ

ファイルを `shooting-v1` から `shooting-v2/game` 配下へとコピーする際、内部参照パス（`res://`）を以下のように置換します。

### 4-1. 置換対象マッピング

```
[旧パス] res://scenes/             -> [新パス] res://game/scenes/
[旧パス] res://scripts/(*.gd)      -> [新パス] res://game/scripts/\1
[旧パス] res://scripts/(*.png)     -> [新パス] res://game/assets/\1
```

### 4-2. 具体的なファイル別変換例

| 対象ファイル | 変換内容 |
|:---|:---|
| `scenes/boss.tscn` | `res://scripts/Boss.gd` $\rightarrow$ `res://game/scripts/Boss.gd`<br>`res://scripts/enemy.png` $\rightarrow$ `res://game/assets/enemy.png` |
| `scenes/main.tscn` | `res://scenes/boss.tscn` $\rightarrow$ `res://game/scenes/boss.tscn`<br>`res://scripts/GameManager.gd` $\rightarrow$ `res://game/scripts/GameManager.gd` 等 |
| `scripts/BulletPool.gd` | `preload("res://scenes/enemy_bullet.tscn")` $\rightarrow$ `preload("res://game/scenes/enemy_bullet.tscn")` |
| `scripts/EnemyBullet.gd` | `preload("res://scenes/parry_particle.tscn")` $\rightarrow$ `preload("res://game/scenes/parry_particle.tscn")` |
| `scripts/player.png.import` | `source_file="res://scripts/player.png"` $\rightarrow$ `source_file="res://game/assets/player.png"` |

---

## 5. ステージ1試作の新規実装設計図 (実装ロードマップ)

移行完了後、`shooting-v2` でステージ1を試作するためのノード構成およびスクリプト実装の具体的な設計です。

### 5-1. 雑魚敵（EnemyCommon）の実装
画面上部から編隊で出現し、プレイヤーに向けて弾を発射する一般的な敵キャラ。

- **ノード構成**:
  ```
  EnemyCommon (Area2D)
  ├─ Sprite2D (アセット画像)
  ├─ CollisionShape2D (衝突判定)
  └─ VisibleOnScreenNotifier2D (画面外通知)
  ```
- **スクリプト設計 (`EnemyCommon.gd`)**:
  - `speed`: 150.0 px/s。
  - `hp`: 30 (プレイヤー通常弾 3発分)。
  - 下方へ直進移動、またはサイン波を描きながら横移動。
  - 1.5秒周期でプレイヤーのいる方向（`global_position.direction_to(player.global_position)`）に向けて `EnemyBullet` を発射。
  - 撃破時、一定確率で `UpgradeItem` ノードをドロップ。

### 5-2. ローグライクアップグレードシステムの実装
プレイヤーのパラメータを辞書（Dictionary）形式で管理し、強化アイテム取得時にこれを加算します。

- **プレイヤーのステータス管理 (`Player.gd` 内に追加)**:
  ```gdscript
  var stats = {
      "damage_multiplier": 1.0,
      "fire_rate_multiplier": 1.0,
      "bullet_count": 1,
      "is_homing": false,
      "is_explosive": false
  }
  ```
- **アップグレード選択UI**:
  - 雑魚ウェーブ終了時（GameManagerがトリガー）、ゲームを一時停止（`get_tree().paused = true`）し、3つの異なる強化カードを表示するUIをポップアップ。
  - プレイヤーが選択したカードに応じて `stats` 辞書を書き換え、ゲームを再開。

### 5-3. ボスの部位破壊システム
ボス本体に複数の被弾判定用の子 `Area2D` を接続し、部位ごとに破壊処理を行います。

- **ノード構成**:
  ```
  Boss (Node2D, Boss.gd)
  ├─ Sprite2D (ボス本体)
  ├─ CoreArea (Area2D, 本体コア)
  ├─ LeftShieldArea (Area2D, 部位: 左盾)
  └─ RightShieldArea (Area2D, 部位: 右盾)
  ```
- **スクリプト設計**:
  - 左右のシールド（ShieldArea）がアクティブな間は、中央コア（CoreArea）への攻撃は無効化（またはダメージ激減）される。
  - 左右シールドはそれぞれ `hp = 150` を持ち、HPが0になると `queue_free()` され、同時にボス本体のHP（`current_hp`）を直接 150 減算する。

### 5-4. サポートAI無線ダイアログシステム
プレイ中に画面下部または上部にサポートAIの顔グラフィックとメッセージ字幕を表示する機構。

- **UI構成**:
  ```
  UI (Control)
  └─ DialoguePanel (Panel, 非表示スタート)
      ├─ FaceSprite (TextureRect)
      └─ SubtitleLabel (Label)
  ```
- **スクリプト設計**:
  - ダイアログ表示用のAPI `show_dialogue(text: String, face_texture: Texture2D, duration: float)` を `UI.gd` に定義。
  - タイマーを使い、指定秒数（`duration`）経過後にパネルをフェードアウト。
  - 雑魚戦中、およびボス登場・フェーズ遷移時に、GameManager経由で解説ダイアログを呼び出す。

### 5-5. COUNTER CORE 状態 (自動パリィ無双モード)
ボスの最大弾幕形態に対抗するための、ジャストガード自動化システム。

- **スクリプト設計**:
  - `Player.gd` に `activate_counter_core(duration: float)` を定義。
  - 発動中、`is_counter_core_active = true` フラグを立て、プレイヤーの周囲に巨大なシールドエフェクト（青色の輪）を表示。
  - 判定ループにおいて、`parry_window_radius` を一時的に **150.0px** などの広範囲に拡張。
  - 範囲内に入った敵弾は、本来のガード発動操作を必要とせず、毎フレーム自動で `convert_to_friendly()` が呼び出され、超高速で反射される。

---

## 6. 移行実施結果（Migration Result Summary）

`migrate_to_v2.py` による移行処理を実行し、`shooting-v1` プロトタイプから `shooting-v2` 本番試作環境への移行が完了しました。

### 6-1. 移行結果のステータス
- **アセット・スクリプトの再配置**: 
  - シーンファイルを `res://game/scenes/`、スクリプトファイルを `res://game/scripts/`、テクスチャ等のアセットを `res://game/assets/` に整理して配置しました。
- **内部パス参照の修正**:
  - 各 `.tscn` シーンおよび `.gd` スクリプト内のファイルパス参照（`res://scenes/` および `res://scripts/`）を、新しいフォルダ構造に合わせて置換し、依存関係のエラーを解消しました。
- **プロジェクト設定の更新 (`project.godot`)**:
  - 解像度を `800 x 1200` に設定し、縦スクロールシューティングに最適な描画範囲を確保しました。
  - メイン起動シーンを `res://game/scenes/main.tscn` に設定しました。
- **ドキュメントの移行**:
  - `IMPLEMENTATION_TASKS.md`、`PROTOTYPE_DESIGN.md`、`README.md` などのドキュメントをプロジェクトルートに移行し、開発状況を把握しやすくしました。

### 6-2. 今後のロードマップ
移行されたソースコードをベースに、**ステージ1の試作開発**（セクション5に記載された新規仕様の実装）を開始します。
1. 雑魚敵（EnemyCommon）の出現パターンと撃破時アップグレードアイテムのドロップ実装
2. ローグライクアップグレードのカード選択UIとプレイヤー強化システムの実装
3. ボス（Boss）の部位破壊（シールド等）および本体へのダメージ連動システムの実装
4. サポートAI無線ダイアログ表示用UIおよび演出の実装
5. COUNTER CORE 状態の自動パリィ機能および視覚エフェクトの実装

