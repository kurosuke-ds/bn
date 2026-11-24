# ビジネス報告用：今回の解釈

## 1. 構造の説明

両手法で出現率95%を超える関係は5本。矢印の真偽ではなく、同じデータを取り直したときに残る関係として提示します。

| from | to | strength_hc | strength_tabu | MI_bits | presentation_label |
| --- | --- | --- | --- | --- | --- |
| Cloudy | Rain | 1.0000 | 1.0000 | 0.3034 | stable_candidate |
| Cloudy | Slippery | 0.0010 | 0.0017 | 0.0196 | insufficient_stability |
| Cloudy | Sprinkler | 1.0000 | 1.0000 | 0.1653 | stable_candidate |
| Cloudy | WetGrass | 0.2727 | 0.0003 | 0.0387 | method_sensitive |
| Rain | Slippery | 0.0030 | 0.0050 | 0.1213 | insufficient_stability |
| Rain | Sprinkler | 0.6457 | 0.1270 | 0.0592 | method_sensitive |
| Rain | WetGrass | 1.0000 | 1.0000 | 0.2457 | stable_candidate |
| Slippery | Sprinkler | 0.0047 | 0.0067 | 0.0299 | insufficient_stability |
| Slippery | WetGrass | 1.0000 | 1.0000 | 0.4283 | stable_candidate |
| Sprinkler | WetGrass | 1.0000 | 1.0000 | 0.0656 | stable_candidate |

## 2. パラメータの説明

| condition | estimate | low | high |
| --- | --- | --- | --- |
| WetGrass=0 | 0.1056 | 0.0881 | 0.1256 |
| WetGrass=1 | 0.8556 | 0.8418 | 0.8746 |

P(Slippery=1 | WetGrass=0/1)の観測条件付き確率で、介入効果ではありません。全CPTの最大固定構造信用区間幅は6.86ポイント。業務許容幅を合意するまで精度の総合合格とはしません。

## 3. 予測を支える検証

| outer | algorithm | method | n | joint_NLL | target_NLL | Brier | baseline_joint_NLL | improvement |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1.0000 | HC_BIC | Bayes1 | 480.0000 | 2.2971 | 0.3503 | 0.0989 | 3.3418 | 1.0447 |
| 2.0000 | HC_BIC | Bayes10 | 480.0000 | 2.4086 | 0.3768 | 0.1101 | 3.3700 | 0.9615 |
| 3.0000 | HC_BIC | Bayes1 | 480.0000 | 2.4150 | 0.3920 | 0.1154 | 3.3077 | 0.8928 |
| 4.0000 | Tabu | Bayes10 | 480.0000 | 2.4251 | 0.4094 | 0.1226 | 3.3184 | 0.8933 |
| 5.0000 | HC_BIC | Bayes1 | 480.0000 | 2.3440 | 0.3877 | 0.1131 | 3.3433 | 0.9993 |

候補選択を外側評価から分離したネストCVでも比較しています。独立な実施設での検証ではありません。

## 4. 構造の説明と実績の食い違い

モデルが示す条件付き独立性16件のうち、探索的Holm補正後0.05で矛盾が検出されたのは0件。0件であっても正しい構造の証明ではありません。固定モデルの全状態頻度のシミュレーションp値は0.462。検出力や標本再利用の限界があります。

## 5. 未解決の判断

実母集団の代表性、期間・施設での独立検証、実務上の最小差、測定精度、判断コスト、担当者レビューは未確認です。実データの採用承認を求める資料ではなく、根拠の読み方を共有する教材として提示します。

| area | status |
| --- | --- |
| Input validity | executed |
| Repeated CV | executed |
| Nested selection validation | executed |
| CPT precision and prior sensitivity | executed |
| Edge stability and conditional evidence | executed_exploratory |
| Distribution fit | executed_fixed_model |
| Learning curve and subgroup diagnosis | executed_example |
| Population/time/customer independence | not_available |
| Missingness and measurement reliability | not_available_in_complete_synthetic_data |
| External replication | not_executed |
| Practical effect threshold and cost | not_agreed |
| Expert review and presentation approval | not_executed |
