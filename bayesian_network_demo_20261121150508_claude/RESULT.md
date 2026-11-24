# RESULT：これまでの分析を R（bnlearn）カーネルで再実行した結果

対象: `bayesian_network_demo_20261119002349`（Part 1）と `bayesian_network_demo_20261119002858`（Part 2）。
実行: conda 環境 bn の R カーネル（R version 4.5.3 (2026-03-11) / bnlearn 5.2.1）。データは元フォルダの CSV を使用。

## Part 1：ネットワークの説明力・エッジ安定性・条件付きリスク

| model | train_BIC | edges | test_mean_loglik |
|---|---|---|---|
| HC_BIC | -5731.4617 | 5.0000 | -2.4340 |
| Independent | -8017.8055 | 0.0000 | -3.3575 |

| from | to | strength | direction |
|---|---|---|---|
| Cloudy | Rain | 1.000 | 0.500 |
| Cloudy | Sprinkler | 1.000 | 0.500 |
| Rain | WetGrass | 1.000 | 0.675 |
| Sprinkler | WetGrass | 1.000 | 0.675 |
| Slippery | WetGrass | 1.000 | 0.325 |
| Rain | Sprinkler | 0.650 | 0.500 |
| Cloudy | WetGrass | 0.295 | 0.500 |
| Rain | Slippery | 0.010 | 0.750 |
| Slippery | Sprinkler | 0.005 | 0.000 |
| Cloudy | Slippery | 0.000 | 0.000 |

| variable | probability_0 | probability_1 | difference_pp |
|---|---|---|---|
| Rain | 0.3868 | 0.7863 | 39.9498 |
| Sprinkler | 0.5160 | 0.7394 | 22.3401 |
| WetGrass | 0.1056 | 0.8556 | 75.0013 |

### Python（ChatGPT）との照合

| 項目 | R_bnlearn | Python_ChatGPT | 差 | 一致 |
|---|---|---|---|---|
| HC_BIC 学習BIC | -5731.4617 | -5731.4617 | 0.0000 | ✓ |
| 独立モデル 学習BIC | -8017.8055 | -8017.8055 | 0.0000 | ✓ |
| HC_BIC 評価平均対数尤度 | -2.4340 | -2.4340 | 0.0000 | ✓ |
| 独立モデル 評価平均対数尤度 | -3.3575 | -3.3575 | 0.0000 | ✓ |
| P(滑り|Rain=1) | 0.7863 | 0.7863 | 0.0000 | ✓ |
| P(滑り|Sprinkler=1) | 0.7394 | 0.7394 | 0.0000 | ✓ |
| P(滑り|WetGrass=1) | 0.8556 | 0.8556 | -0.0000 | ✓ |
| 差(pt) Rain | 39.9498 | 39.9498 | -0.0000 | ✓ |
| 差(pt) Sprinkler | 22.3401 | 22.3401 | 0.0000 | ✓ |
| 差(pt) WetGrass | 75.0013 | 75.0013 | -0.0000 | ✓ |
| HC strength 最大差（全辺） | 0.0000 | 0.0000 | 0.0000 | ✓ |
| Tabu strength 最大差（全辺） | 0.0000 | 0.0000 | 0.0000 | ✓ |

## Part 2：交差検証・ペアブートストラップ・置換検定・校正・再学習安定性

| dataset | model | log_loss | brier | auc |
|---|---|---|---|---|
| development_OOF | BN_full | 0.3825 | 0.1118 | 0.8537 |
| development_OOF | BN_no_WetGrass | 0.5105 | 0.1651 | 0.7726 |
| development_OOF | Logistic | 0.3834 | 0.1120 | 0.8514 |
| development_OOF | Prevalence | 0.6792 | 0.2431 | 0.5000 |
| new_synthetic_validation | BN_full | 0.3998 | 0.1186 | 0.8475 |
| new_synthetic_validation | BN_no_WetGrass | 0.5010 | 0.1614 | 0.7887 |
| new_synthetic_validation | Logistic | 0.4005 | 0.1188 | 0.8455 |
| new_synthetic_validation | Prevalence | 0.6785 | 0.2427 | 0.5000 |

| comparator | log_loss_improvement | ci_low | ci_high |
|---|---|---|---|
| BN_no_WetGrass | 0.10118 | 0.08086 | 0.12183 |
| Logistic | 0.00067 | -0.00030 | 0.00173 |
| Prevalence | 0.27863 | 0.25013 | 0.30683 |

置換検定（999回）の片側 p = 0.001、観測された改善 = 0.2786。

| bin | n | predicted | observed | low | high |
|---|---|---|---|---|---|
| 0.1-0.2 | 711.000 | 0.106 | 0.111 | 0.090 | 0.136 |
| 0.8-0.9 | 1289.000 | 0.856 | 0.847 | 0.826 | 0.866 |

| variable | median | low | high |
|---|---|---|---|
| Rain | 39.87 | 37.63 | 42.55 |
| WetGrass | 74.80 | 72.24 | 77.14 |

### 矢印の向きの支持と探索法（追加検証）

| edge | hc_shuffle_strength | hc_shuffle_direction | hc_fixed_strength | hc_fixed_direction | tabu_strength | tabu_direction |
|---|---|---|---|---|---|---|
| Cloudy → Rain | 1.000 | 0.500 | 1.000 | 0.500 | 1.000 | 0.500 |
| Cloudy → Sprinkler | 1.000 | 0.500 | 1.000 | 0.500 | 1.000 | 0.500 |
| Rain → WetGrass | 1.000 | 0.675 | 1.000 | 0.948 | 1.000 | 0.948 |
| Sprinkler → WetGrass | 1.000 | 0.675 | 1.000 | 0.948 | 1.000 | 0.948 |
| WetGrass → Slippery | 1.000 | 0.675 | 1.000 | 0.948 | 1.000 | 0.948 |
| Rain → Sprinkler | 0.650 | 0.500 | 0.105 | 0.500 | 0.105 | 0.500 |

### 感度分析：ロジスティック回帰の仕様

| spec | log_loss | brier | auc | improvement_of_BN | ci_low | ci_high |
|---|---|---|---|---|---|---|
| L2正則化 C=1（元の仕様） | 0.40050 | 0.11878 | 0.84554 | 0.00067 | -0.00030 | 0.00173 |
| 正則化なし glm | 0.40140 | 0.11899 | 0.84215 | 0.00157 | 0.00013 | 0.00311 |

### Python（ChatGPT）との照合

| 項目 | R_bnlearn | Python_ChatGPT | 差 | 一致 |
|---|---|---|---|---|
| CV BN_full log_loss | 0.3825 | 0.3829 | -0.0004 | ✓ |
| CV BN_full auc | 0.8537 | 0.8497 | 0.0040 | 差あり |
| CV BN_no_WetGrass log_loss | 0.5105 | 0.5103 | 0.0002 | ✓ |
| CV BN_no_WetGrass auc | 0.7726 | 0.7730 | -0.0003 | ✓ |
| CV Logistic log_loss | 0.3834 | 0.3834 | -0.0000 | ✓ |
| CV Logistic auc | 0.8514 | 0.8527 | -0.0014 | 差あり |
| CV Prevalence log_loss | 0.6792 | 0.6792 | 0.0000 | ✓ |
| CV Prevalence auc | 0.5000 | 0.5000 | 0.0000 | ✓ |
| 検証 BN_full log_loss | 0.3998 | 0.3998 | 0.0000 | ✓ |
| 検証 BN_full auc | 0.8475 | 0.8475 | 0.0000 | ✓ |
| 検証 BN_no_WetGrass log_loss | 0.5010 | 0.5010 | -0.0000 | ✓ |
| 検証 BN_no_WetGrass auc | 0.7887 | 0.7887 | 0.0000 | ✓ |
| 検証 Logistic log_loss | 0.4005 | 0.4005 | 0.0000 | ✓ |
| 検証 Logistic auc | 0.8455 | 0.8455 | 0.0000 | ✓ |
| 検証 Prevalence log_loss | 0.6785 | 0.6785 | 0.0000 | ✓ |
| 検証 Prevalence auc | 0.5000 | 0.5000 | 0.0000 | ✓ |
| 改善幅 vs BN_no_WetGrass | 0.1012 | 0.1012 | -0.0000 | ✓ |
| 改善幅 vs Logistic | 0.0007 | 0.0007 | 0.0000 | ✓ |
| 改善幅 vs Prevalence | 0.2786 | 0.2786 | -0.0000 | ✓ |
| 再学習 確率差 中央値 Rain | 39.8742 | 40.0847 | -0.2110 | 差あり |
| 再学習 確率差 中央値 WetGrass | 74.7959 | 75.1882 | -0.3920 | 差あり |
| HC strength 最大差（全辺） | 0.0000 | 0.0000 | 0.0000 | ✓ |
| Tabu strength 最大差（全辺） | 0.0000 | 0.0000 | 0.0000 | ✓ |

差が出る項目は、CV の fold 割り当て・ブートストラップの乱数（Python と R で異なる）と、ロジスティック回帰の正則化の有無（scikit-learn は L2・C=1、R glm はなし）による。

## 結論

- 2つの分析は R でも同じ結論になった。点推定と R 由来のエッジ安定性は完全一致、その他は乱数・実装差による小差のみ。
- BN は発生率のみの基準を明確に上回り、濡れ情報は予測に有用。ロジスティック回帰に対する優越は確認できない。
- 向き：Cloudy→Rain/Sprinkler はデータでは決まらない。合流点と WetGrass→Slippery は Tabu で強く支持されるが、HC は列順依存の局所解で支持が下がる。
- 人工データの単一標本による教材。矢印は因果の証明ではなく、条件付き確率差は介入効果ではない。
