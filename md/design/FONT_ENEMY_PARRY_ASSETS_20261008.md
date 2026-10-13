# 字体・敵3役・二段階パリィ表示の接続資料

作成: 2026-10-08

## 体裁方針

ドットテイストを基調として維持する。大きく短い見出し、成功表示、警告は既存`DotGothic16`を使い、M PLUS 1 Codeは小さい本文、HUD数値、キー名の判読性を補う役割に限定する。敵画像は高精細生成物をそのまま使わず、64色・2px単位へ再標本化したドット調候補を納品する。

共有UI、本番シーン、戦闘判定、保存、`project.godot`は変更していない。Godotのインポート・戦闘テスト・保存試験も実行していない。

## 1. M PLUS 1 Code

### 完成ファイル

| ファイル | 状態 | 容量・確認 |
| --- | --- | --- |
| `game/assets/design/fonts/MPLUS1Code-Variable.ttf` | 公式配布版をファイル名だけ変更。内部改変なし | 3,933,000 bytes / SHA-256 `FF68678C5BD7E9D9D6AB6D57E4355AABE30F6B8F8BFF9BD59BAF6A7807DCFD36` |
| `game/assets/design/fonts/OFL-MPLUS1Code.txt` | 公式OFLと著作権表示 | 4,387 bytes / SHA-256 `04971E3FCEE60B247395150D93B3616F6A0B092572332C96187B472976553ABC` |
| `game/ui/design/font_preview_9x16_60.png` | 独立比較画像 | 405×720 / 82,159 bytes |
| `game/ui/design/generate_font_preview.py` | 比較画像の再生成用 | ゲームへ接続しない |

### 出典と利用条件

- 配布元: [Google Fonts / M PLUS 1 Code](https://github.com/google/fonts/tree/main/ofl/mplus1code)
- 公式説明: [DESCRIPTION.en_us.html](https://raw.githubusercontent.com/google/fonts/main/ofl/mplus1code/DESCRIPTION.en_us.html)
- 著作権: Copyright 2021 The M+ FONTS Project Authors
- ライセンス: SIL Open Font License 1.1。同梱時は`OFL-MPLUS1Code.txt`を保持する。
- BIZ UDGothicは比較候補のまま。今回は字体数と容量を増やさず、M PLUS 1 Codeを先に完成させた。Rajdhaniは追加していない。

### 推奨適用

| 対象 | 字体 | 内部解像度での開始値 | 備考 |
| --- | --- | ---: | --- |
| HUD数値・短い状態 | M PLUS 1 Code | 22～24px、Medium～SemiBold相当 | 60%表示で約13～14px。暗色パネルと2px前後の縁取り |
| 設定・説明本文 | M PLUS 1 Code | 22px以上、行間1.2程度 | 長文は縁取りを太くしすぎず、背景面を置く |
| 小さい補助文 | M PLUS 1 Code | 18px以上 | 明暗差のあるパネル上に限定。戦闘背景へ直接置かない |
| 大きな短い見出し・警告・成功 | 既存DotGothic16 | 26～32px | ドット調の体裁を維持。長文本文には使わない |

405×720の比較では「捕獲 12/12」「修復まであと2回」「シールド再展開 2.4s」「クリア済みボス」「0123456789」「COUNTER READY [Left Shift]」を暗色背景・1～2px縁取りで確認した。M PLUS 1 Codeは日本語の字間、数字の桁、英数字キー名が安定した。

`[Left Shift]`は全幅パネルでは収まるが、前回HUD案の220px内部幅では長い。戦闘HUDでは`[Shift]`または`[LShift]`へ短縮し、設定画面では正式名を使う。最終的なキー表示幅は開発が3画面比率で確認する。

字体本体だけで約3.93MBある。これは元素材容量であり、エクスポート後の増分ではない。開発は接続後に実配布容量を測定し、未使用のまま全リソース出力へ含めないことを確認する。サブセット化や字体内部改変は今回行わない。

## 2. 敵3役の完成候補

### 共通仕様

- 形式: PNG、RGBA透明背景、128×96px。
- 機首方向: 右。現行`enemy_drone.tscn`の`rotation=90°`を使うと画面下方向を向く。
- 中心: テクスチャ座標`(64,48)`。3体とも不透明部の中心をほぼ同一点へ揃えた。
- 画風: 64色、2px単位のドット調。錆びた暗色金属装甲、真鍮色、シアン発光コア、控えめな橙色塗装を共通化。
- 生成方法: OpenAI組み込みImageGenで高精細透明候補を3体別々に生成し、Pillowで透明余白を切り出し、半解像度で輪郭強調・64色量子化後、Nearest Neighborで2倍化した。
- 本番置換は未実施。

| 役割 | 完成ファイル | 不透明部の目安 | 容量 | 読み分け |
| --- | --- | ---: | ---: | --- |
| straight / 射撃機 | `game/assets/design/enemies/enemy_straight_candidate.png` | 約104×52px | 2,396 bytes | 細長い機首、単砲口、細い矢じり型 |
| wave / 掃射機 | `game/assets/design/enemies/enemy_wave_candidate.png` | 約102×74px | 3,773 bytes | 横長装甲、扇状に分かれた5砲口 |
| charge / 溜め撃ち機 | `game/assets/design/enemies/enemy_charge_candidate.png` | 約106×70px | 4,142 bytes | 厚い装甲、大口径中央砲、露出コア |

比較画像は`game/ui/design/enemy_roles_preview.png`。2倍表示と色を除いた実寸輪郭を並べ、straightの針状、waveの扇状、chargeの円筒砲が色に頼らず区別できることを静的確認した。

### 推奨表示倍率と当たり判定

現行素材は105×69px、Sprite倍率0.65、円形当たり判定半径22。新候補はキャンバスを大きくしたが、不透明部は現行に近い。

- wave、charge: Sprite倍率0.65を開始値にできる。見かけは約66×48px、69×46pxで現行約68×45pxに近い。
- straight: 同倍率では細い方向が約34pxとなり、直径44pxの当たり判定が輪郭から出る。まず倍率0.75～0.80、または当たり判定半径20のどちらかを開発が比較する。戦闘ルール維持を優先するなら、倍率調整から試す。
- 翼端や砲身の全域を当たり判定にしない。既存の円形判定を胴体・コアへ合わせ、見た目の突起は役割識別用として扱う。
- 3体とも中心`(64,48)`なので、Spriteの`centered=true`のまま接続可能。タイプ別画像を切り替えても位置補正を追加しない想定。

### chargeの0.4秒溜め発光

ガード不可弾の赤警告と混同しないよう、動く発光は**シアン→白金**に限定する。機体の錆色・橙色装甲は静止色のまま強く光らせない。

| 時刻 | 指示 |
| ---: | --- |
| 0.00s | 露出コアを通常シアン。大砲口は暗いまま |
| 0.20s | コアを白寄りのシアンへ1段階明るくし、コア周囲を1回だけ短く脈動 |
| 0.32s | 大砲口の内周だけ白金へ点灯。赤・マゼンタの全身点滅は使わない |
| 0.40s | 発射時に砲口から短い白金フラッシュ。直後に通常シアンへ戻す |

敵全体の赤点滅、上部の赤い警告帯、赤い弾色はガード不可の意味として予約する。chargeは捕獲可能な強い弾であり、溜め演出だけで「回避専用」と誤認させない。

### 出典・利用条件と未確認

- 生成時の材質参照: 既存`game/assets/boss/stage1/stage1_enemy_drone.png`。`game/assets/boss/stage1/README.md`には元名`2.png`と用途はあるが、作者・配布元・ライセンスの記載は見つからなかった。
- 新候補: OpenAI組み込みImageGenで2026-10-08に生成し、上記のドット化処理を行った。ロゴ、文字、透かしは含めていない。
- 公開前に、材質参照に使った既存Stage 1素材の取得元と利用条件を統括または開発が確認する。現状のREADMEだけで第三者素材の利用条件が確定したとは扱わない。

### ImageGenの最終プロンプトセット

共通指定:

> 既存Stage 1ドローンを材質・陣営感の参照にした、右向きの1体だけの2Dゲーム敵スプライト。錆びた暗色鋼、真鍮縁、機械パネル、控えめな橙色、シアンコア。3:2中央配置、透明背景、全身、切れなし。105×69程度へ縮小しても輪郭が読める。文字、ロゴ、透かし、背景、影、弾、排気なし。

役割差分:

- straight: 長く細い機首、中央の単砲口、コンパクトな左右装甲、速い矢じり型。多砲口・巨大砲を避ける。
- wave: 横長の上下装甲、右前方へ扇状に並ぶ5本の小砲口。長い単砲身・巨大中央砲を避ける。
- charge: 厚い多層正面装甲、1つの大口径中央砲、砲尾付近の露出シアンコア、短く重い安定翼。多砲口・細長い輪郭を避ける。

### PIXEL V2: 生成段階から低解像度にした改善候補

ユーザー方針を受け、上記の旧候補を削除・上書きせず、生成段階から低解像度ドット絵として設計した別案を追加した。旧候補は高精細生成後のドット化だったため、役割の輪郭は明確でも内部の細線と単独ハイライトが多かった。V2では、生成プロンプトの冒頭から64×48の作業グリッド、24～32色、1～2px輪郭、最大3段階の陰影、アンチエイリアス・グラデーション・微細パネルなしを指定した。

完成ファイル:

| 役割 | ファイル | 不透明部 | 色数 | 容量 | 接続済み倍率での目安 |
| --- | --- | ---: | ---: | ---: | ---: |
| straight | `game/assets/design/enemies/enemy_straight_pixel_v2.png` | 96×60px | 27色 | 2,482 bytes | 約82×51px（0.85） |
| wave | `game/assets/design/enemies/enemy_wave_pixel_v2.png` | 94×76px | 27色 | 3,249 bytes | 約61×49px（0.65） |
| charge | `game/assets/design/enemies/enemy_charge_pixel_v2.png` | 104×76px | 27色 | 3,346 bytes | 約68×49px（0.65） |

3点とも128×96 RGBA、右向き、中心`(64,48)`、2×2pxを最小描画単位として保存した。生成元を透明輪郭で切り出し、64×48相当の作業グリッドへ解決し、28色上限・二値透明へ固定した後、Nearest Neighborで2倍化している。この処理は高精細絵へ後からドット模様を加えるものではなく、低解像度ドット絵として生成した形と色面をゲーム用テクスチャへ整える仕上げである。再生成用処理は`game/ui/design/prepare_enemy_pixel_v2.py`。

比較画像は`game/ui/design/enemy_roles_pixel_v2_review.png`。現行自機を1.5倍、現行Stage 1ドローンを0.65倍、Stage 1ボスの中央128×96pxを2倍で並べ、旧候補とV2を本番接続済み倍率で比較した。V2は旧候補より装甲内の細線・単独ハイライトが減り、straightの矢じり、waveの複数砲口、chargeの大口径砲が色を除いた輪郭でも分かれる。waveは現行ドローンより横幅が約7px小さいため、接続後に背景上で弱く見える場合だけ0.70倍を比較し、先に画像を描き直さない。

既存本番コードは旧`enemy_*_candidate.png`を参照中であり、V2への差し替えは行っていない。採用判断、シーン接続、Godotインポート、当たり判定、ゲーム内背景での視認性確認は開発担当とする。

#### PIXEL V2の最終ImageGenプロンプト

3体はOpenAI組み込みImageGenで、透明背景の独立画像として1体ずつ生成した。共通プロンプトは次のとおり。

> TRUE LOW-RESOLUTION PIXEL ART FROM THE START, designed as if hand-pixeled on a 64x48 working grid, not a high-resolution painting converted later. Create one right-facing 2D enemy spacecraft sprite for COUNTER CORE. Match the material family and pixel density of the provided references: the existing Stage 1 drone, player ship, and Stage 1 boss. Use 24–32 colors total, chunky coherent color clusters, a crisp 1–2 target-pixel dark outline, and no more than 3 shading steps per material. No isolated pixel noise, micro-panel clutter, anti-aliasing, gradients, or painterly texture. Use rusted dark steel, muted brass, restrained orange armor, and a cyan energy core. Center the complete body in a 4:3 frame with a transparent background. No text, logo, watermark, projectile, exhaust trail, or red warning glow.

役割差分:

- straight: one obvious forward muzzle, a narrow arrowhead silhouette, compact side armor, and a fast interceptor posture; avoid multiple barrels and oversized cannon shapes.
- wave: exactly five small forward muzzles arranged as a readable fan, a broad sweeping silhouette, and separated muzzle tips; avoid a single long barrel or one dominant central cannon.
- charge: one dominant round heavy cannon, thick layered front armor, a visible cyan core behind the cannon, and a short heavy silhouette; avoid multiple small muzzles and a thin interceptor body.

既存Stage 1素材の作者・配布元・ライセンスがREADMEだけでは確定できない点は旧候補と同じである。公開前確認が必要であり、V2追加によって解決済みとは扱わない。

## 3. 通常／精密パリィの表示

完成プレビュー:

- `game/ui/design/parry_double_ring_preview.png`: 816×460、22,602 bytes。
- `game/ui/design/generate_parry_ring_preview.py`: 再生成用。ゲームへ接続しない。

表示ルール:

- 外周: 通常捕獲範囲。シアン`#2BD8F1`、分節線、低めの明度。
- 内周: 最終外周半径の2/3。待機中は淡いシアン`#B1F8FF`。
- 精密成功: 内周だけ白金`#FFDC70`へ0.35秒変化し、4方向へ短いドット線を出す。
- 成功文言: `精密捕獲!`を既存DotGothic16で0.35秒、自機の直上へ表示。長い説明や全画面文字を出さない。
- 通常成功も外周の既存捕獲発光を残し、精密だけが成功に見えないようにする。
- 赤色を使わず、ガード不可警告の意味と分離する。
- 二重リングの内部は透明。敵弾、自機、ボスの予告線を覆う面塗りは追加しない。

動的描画、判定半径、成功倍率、音、実時間の接続は開発担当。COUNTERのHARD限定化は未採用であり、この資料や前回HUD案のNORMAL非表示差分を確定仕様として接続しない。

## 静的確認と開発への順序

1. フォント本体とOFLを先に接続し、675×1200の60%表示、800×1200、900×1200で本文・数字・キー名を確認する。
2. enemy候補をタイプ別Textureへ割り当て、向き、中心、倍率、円形当たり判定との見た目を確認する。特にstraightの細い胴体を確認する。
3. 二重リングを動的描画し、外周捕獲、内周精密、混在捕獲、ガード不可予告が同時に読めるか確認する。
4. chargeの0.4秒発光が赤警告と混同しないことを確認する。

本資料では画像の寸法・透明度・中心・容量、字体の静的描画だけを確認した。Godotでのインポート結果、実戦での縮小、フィルタ設定、当たり判定、FPS、色覚差、音との同期は未確認。
