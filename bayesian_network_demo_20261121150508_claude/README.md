# これまでの分析を R（bnlearn）カーネルで再実行（claude版）

`/Users/user01/agent_dir` の `bayesian_network_demo_YYYYMMDDHHmmss` 形式の2フォルダ（ChatGPT が Python で実行した分析）を、
conda 環境 `bn` の **R カーネル（R (bn) / `ir-bn`）** で **bnlearn** を使って作り直し、実行結果をまとめたものです。
**分析・推論・検定はすべて R（bnlearn と base R）で行い、Python の pgmpy は使用していません。**

## 主成果物
- **`bayesian_network_demo_20261121150508_claude.ipynb`** … 実行済みノートブック（カーネル **R (bn)**）。
  冒頭の「📌 結果サマリー」、各節直後の「📊 結果」、最後の「3. まとめ」に、実行で得た数値をマークダウンでまとめています。
- `RESULT.md` … 主要な表のまとめ
- `results/` … 各節の CSV（`part1_*`, `part2_*`）、`results/figures/` … 図

| 元フォルダ | 本ノートの節 |
|---|---|
| `bayesian_network_demo_20261119002349`（business_analysis.ipynb, edge_analysis.R） | Part 1 |
| `bayesian_network_demo_20261119002858`（analysis.py, edge_stability.R） | Part 2 |

`data/` は元フォルダからコピーした入力データ、`reference/` は ChatGPT の Python 結果（照合用に読み込むだけ）です。元フォルダは変更していません。

## 開き方
`start_jupyter.command` で Jupyter を起動し、このノートブックを開いてカーネル **R (bn)** で「Run All」（数分）。

## 再生成（ノートブックの作り直し）
```bash
source /opt/anaconda3/etc/profile.d/conda.sh && conda activate bn
cd bayesian_network_demo_20261121150508_claude
python src/build_r_notebook.py   # 1回目：数値なしで生成
jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ir-bn --ExecutePreprocessor.timeout=1200 bayesian_network_demo_20261121150508_claude.ipynb
python src/build_r_notebook.py   # 2回目：results/ の数値をマークダウンに埋め込む
jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.kernel_name=ir-bn --ExecutePreprocessor.timeout=1200 bayesian_network_demo_20261121150508_claude.ipynb
```
`src/build_r_notebook.py` はノートブック（JSON）を組み立てるだけで、分析は行いません。乱数 seed は固定で、2回の実行結果は同一です。
