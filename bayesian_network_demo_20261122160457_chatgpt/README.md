# ビジネス提示のためのR/bnlearn検証

bayesian_network_demo_20261122160457_chatgpt.ipynb をR (bn)で全実行。目的は構造・確率・エッジの説明の妥当性を点検することです。全計算はR。pgmpyは使用しません。

前版の反復CV・6,000回の構造再学習に、ネストCV、条件付き独立性、全32状態の分布適合、学習曲線、再学習区間、条件別診断を追加。詳細な判断根拠・出典・プレゼン構成はNotebookのMarkdownセルに記載。

入力は前版の人工データをコピー。既存評価データの再利用なので確証的外部検証ではありません。resultsは数値と図、BUSINESS_BRIEF.mdは説明用要約、RESULT.mdは全体、PRESENTATION_PLAN.mdはスライド構成です。PowerPointファイル自体は生成していません。
