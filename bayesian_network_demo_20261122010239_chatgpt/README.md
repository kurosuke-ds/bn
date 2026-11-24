# R/bnlearn 妥当性検証

bayesian_network_demo_20261122010239_chatgpt.ipynb をR (bn)カーネルで全実行してください。Notebook内に定義、良い方向、妥当性判断の根拠、出典、繰り返しの必要性を記載しています。

主な反復：5-fold CV×10回、HC/Tabu各1,000bootstrap×3seed、評価行2,000回。実分析にPython/pgmpyは使用しません。元データ：bayesian_network_demo_20261121151120_chatgpt/dataのdevelop.csvとvalidation.csv（過去使用済み）。analysis.Rは同じRコード、resultsは数値、RESULT.mdは要約。
