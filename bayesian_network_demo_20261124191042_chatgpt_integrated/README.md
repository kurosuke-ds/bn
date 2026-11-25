# Python / pgmpy：高中低の業務向けベイジアンネットワーク検証（1 Notebook統合版）

`bayesian_network_demo_20261124191042_chatgpt_integrated.ipynb` だけで分析・図表・結果出力・実装検証まで実行できます。
元フォルダ `bayesian_network_demo_20261124191042_chatgpt` のPythonファイルを統合したもので、計算内容は変えていません。

## 実行方法
1. このフォルダを作業ディレクトリにして、Notebookを **Python (bn)** カーネル（pgmpy 1.1.2）で開く
2. 「Run All」で上から全セルを実行
3. `results/` に表・図・`RESULT.md`・`manifest.json` が作られ、最後の18章で実装検証（`PASS`）が表示される

既存の `df` があればコピーして使い、なければ1,200行×5列の人工データを生成します。
`df` の全列は低・中・高の文字列とし、ID・日付などは除いて渡してください。

## 元ファイルとの対応
| 元のファイル | 統合後の場所 |
|---|---|
| `bn_functions.py` | 0.1〜0.7章（ライブラリ・統計処理の関数定義） |
| `reporting.py` | 0.8章（図表とRESULT.mdの出力） |
| `run_analysis.py` | 1〜17章のコードセル（元Notebookと同じ順序） |
| `validation_checks.py` | 0.9章で定義、18章で実行 |
| `execute_notebook.py` | 廃止（Run Allで代替。保存時スナップショットのセルも廃止） |
| `PRESENTATION_PLAN.md` | 廃止（16章と同じ内容） |

変更点：`manifest.json` には補助.pyのハッシュの代わりにNotebookファイルのSHA-256を記録します。
版チェックから不要になった nbformat / nbclient を外しました（依存版は `requirements-versions.txt`）。

## 解釈上の範囲
人工データでの実演です。スコアやp値に普遍的な業務合格点はありません。
分析は関連と条件付き分布を説明し、施策の因果効果を推定しません。
