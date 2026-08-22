# アセット管理・配置ガイド (Assets Guide)

プロジェクト内のアセット（画像・音声・文書）は `game/assets/` 配下にカテゴリ別に整理されています。素材の追加や更新時は以下のフォルダ構成に従ってください。

---

## ディレクトリ構成

```text
game/assets/
├── player/         # 自機スプライト画像
│   ├── spaceship_small_blue.png    # 【デフォルト】コバルトブルー
│   ├── spaceship_small_red.png     # クリムゾンレッド
│   ├── spaceship_small_green.png   # エメラルドグリーン
│   ├── spaceship_small_yellow.png  # トパーズイエロー
│   ├── spaceship_small_purple.png  # アメジストパープル
│   ├── spaceship_small_orange.png  # ソーラーオレンジ
│   └── player_legacy.png           # 旧自機画像
│
├── enemies/        # 敵機・ボス用スプライト画像
│   └── enemy.png
│
├── bullets/        # 弾丸用スプライト画像
│   ├── player_bullet.png           # プレイヤー弾
│   └── enemy_bullet.png            # 敵弾
│
├── sounds/         # 効果音 (SE) フォルダ (.wav, .ogg)
├── music/          # BGM フォルダ (.ogg)
└── docs/           # ライセンス・素材情報
    ├── Lunar_Lander_License.txt
    └── Lunar_Lander_README.txt
```

---

## 自機機体カラー変更システム

*   **デフォルト機体**: `spaceship_small_blue.png`
*   **色変更方法**: タイトル画面の「設定 (SETTINGS)」>「自機機体カラー設定」からドロップダウンで選択可能。
*   **設定の保存**: 選択した機体カラーは `user://settings.cfg` に保存され、ゲームプレイおよび次回起動時にも維持されます。
*   **拡張方法**: `Global.available_player_colors` に定義を追加し、`game/assets/player/` に新しいテクスチャを配置することで新しいカラーや機体バリエーションを簡単に追加できます。

---

## 素材追加時のルール

1.  **画像 (スプライト)**: 背景透過 `.png` 形式。
2.  **効果音 (SE)**: `.wav` または `.ogg` 形式。
3.  **BGM**: ループ再生可能な `.ogg` 形式。
