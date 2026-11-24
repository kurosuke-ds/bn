# RESULT：R/bnlearnの妥当性検証

| check | result |
| --- | --- |
| Probability validity | passed numerical check |
| Repeated CV vs independent | 7 configurations improved in every split |
| CPT precision example | 0 contexts exceed demo width 0.20 |
| Finite bootstrap precision | within configured MC target |
| Business acceptability | not determined: minimum improvement/cost not specified |

## 構造比較

| algorithm | edges | parameters | BIC_bnlearn | BDeu | gap_from_best_BIC | conventional_delta_BIC |
| --- | --- | --- | --- | --- | --- | --- |
| HC_BIC | 5.0000 | 11.0000 | -5731.4617 | -5730.7337 | 0.0000 | 0.0000 |
| HC_BDeu | 5.0000 | 11.0000 | -5731.4617 | -5730.7337 | 0.0000 | 0.0000 |
| Tabu | 5.0000 | 11.0000 | -5731.4617 | -5730.7337 | 0.0000 | 0.0000 |
| MMHC | 5.0000 | 11.0000 | -5731.4617 | -5730.7337 | 0.0000 | 0.0000 |
| Independent | 0.0000 | 5.0000 | -8017.8055 | -8013.4292 | 2286.3437 | 4572.6875 |

## 反復交差検証

| algorithm | method | runs | joint_NLL_mean | joint_NLL_min | joint_NLL_max | target_NLL | Brier |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HC_BIC | Bayes1 | 10.0000 | 2.3754 | 2.3732 | 2.3767 | 0.3830 | 0.1120 |
| HC_BDeu | Bayes10 | 10.0000 | 2.3753 | 2.3733 | 2.3767 | 0.3830 | 0.1120 |
| HC_BIC | Bayes10 | 10.0000 | 2.3753 | 2.3733 | 2.3767 | 0.3830 | 0.1120 |
| Independent | Bayes10 | 10.0000 | 3.3339 | 3.3331 | 3.3347 | 0.6792 | 0.2431 |
| MMHC | Bayes10 | 10.0000 | 2.3774 | 2.3733 | 2.3974 | 0.3830 | 0.1120 |
| Tabu | Bayes10 | 10.0000 | 2.3752 | 2.3733 | 2.3767 | 0.3830 | 0.1120 |
| HC_BIC | Bayes100 | 10.0000 | 2.3821 | 2.3804 | 2.3834 | 0.3845 | 0.1123 |
| HC_BIC | MLE | 10.0000 | 2.3754 | 2.3733 | 2.3768 | 0.3830 | 0.1120 |

## パラメータ精度

| variable | parents | n_context | events | MLE | Bayes10 | low | high | width | precision_check |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cloudy | (none) | 2400.0000 | 1215.0000 | 0.5062 | 0.5062 | 0.4863 | 0.5262 | 0.0399 | within_demo_tolerance |
| Rain | Cloudy=0 | 1185.0000 | 209.0000 | 0.1764 | 0.1777 | 0.1565 | 0.1999 | 0.0434 | within_demo_tolerance |
| Rain | Cloudy=1 | 1215.0000 | 973.0000 | 0.8008 | 0.7996 | 0.7767 | 0.8216 | 0.0449 | within_demo_tolerance |
| Sprinkler | Cloudy=0 | 1185.0000 | 612.0000 | 0.5165 | 0.5164 | 0.4880 | 0.5447 | 0.0568 | within_demo_tolerance |
| Sprinkler | Cloudy=1 | 1215.0000 | 112.0000 | 0.0922 | 0.0939 | 0.0781 | 0.1108 | 0.0327 | within_demo_tolerance |
| WetGrass | Rain=0,Sprinkler=0 | 695.0000 | 36.0000 | 0.0518 | 0.0534 | 0.0380 | 0.0713 | 0.0333 | within_demo_tolerance |
| WetGrass | Rain=1,Sprinkler=0 | 981.0000 | 879.0000 | 0.8960 | 0.8950 | 0.8751 | 0.9134 | 0.0383 | within_demo_tolerance |
| WetGrass | Rain=0,Sprinkler=1 | 523.0000 | 418.0000 | 0.7992 | 0.7978 | 0.7625 | 0.8310 | 0.0686 | within_demo_tolerance |
| WetGrass | Rain=1,Sprinkler=1 | 201.0000 | 196.0000 | 0.9751 | 0.9693 | 0.9416 | 0.9883 | 0.0467 | within_demo_tolerance |
| Slippery | WetGrass=0 | 871.0000 | 90.0000 | 0.1033 | 0.1056 | 0.0861 | 0.1268 | 0.0406 | within_demo_tolerance |
| Slippery | WetGrass=1 | 1529.0000 | 1310.0000 | 0.8568 | 0.8556 | 0.8376 | 0.8727 | 0.0352 | within_demo_tolerance |

## 関係の安定性

| algorithm | from | to | strength | seed_range | MC_low | MC_high | direction | MC_halfwidth |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| hc | Cloudy | Rain | 1.0000 | 0.0000 | 0.9987 | 1.0000 | 0.4995 | 0.0006 |
| tabu | Cloudy | Rain | 1.0000 | 0.0000 | 0.9987 | 1.0000 | 0.4997 | 0.0006 |
| hc | Cloudy | Slippery | 0.0010 | 0.0020 | 0.0003 | 0.0029 | 0.8333 | 0.0013 |
| tabu | Cloudy | Slippery | 0.0017 | 0.0030 | 0.0007 | 0.0039 | 0.9000 | 0.0016 |
| hc | Rain | Slippery | 0.0030 | 0.0020 | 0.0016 | 0.0057 | 0.5556 | 0.0021 |
| tabu | Rain | Slippery | 0.0050 | 0.0030 | 0.0030 | 0.0082 | 0.9000 | 0.0026 |
| hc | Cloudy | Sprinkler | 1.0000 | 0.0000 | 0.9987 | 1.0000 | 0.4995 | 0.0006 |
| tabu | Cloudy | Sprinkler | 1.0000 | 0.0000 | 0.9987 | 1.0000 | 0.4997 | 0.0006 |
| hc | Rain | Sprinkler | 0.6457 | 0.0160 | 0.6284 | 0.6626 | 0.4987 | 0.0171 |
| tabu | Rain | Sprinkler | 0.1270 | 0.0060 | 0.1156 | 0.1394 | 0.5000 | 0.0119 |
| hc | Slippery | Sprinkler | 0.0047 | 0.0040 | 0.0028 | 0.0078 | 0.3929 | 0.0025 |
| tabu | Slippery | Sprinkler | 0.0067 | 0.0040 | 0.0043 | 0.0103 | 0.1250 | 0.0030 |
| hc | Cloudy | WetGrass | 0.2727 | 0.0270 | 0.2570 | 0.2889 | 0.5000 | 0.0159 |
| tabu | Cloudy | WetGrass | 0.0003 | 0.0010 | 0.0001 | 0.0019 | 0.5000 | 0.0009 |
| hc | Rain | WetGrass | 1.0000 | 0.0000 | 0.9987 | 1.0000 | 0.6763 | 0.0006 |
| tabu | Rain | WetGrass | 1.0000 | 0.0000 | 0.9987 | 1.0000 | 0.9363 | 0.0006 |
| hc | Slippery | WetGrass | 1.0000 | 0.0000 | 0.9987 | 1.0000 | 0.3228 | 0.0006 |
| tabu | Slippery | WetGrass | 1.0000 | 0.0000 | 0.9987 | 1.0000 | 0.0635 | 0.0006 |
| hc | Sprinkler | WetGrass | 1.0000 | 0.0000 | 0.9987 | 1.0000 | 0.6770 | 0.0006 |
| tabu | Sprinkler | WetGrass | 1.0000 | 0.0000 | 0.9987 | 1.0000 | 0.9363 | 0.0006 |

## 判断上の制約

人工データ・既存評価標本の再利用。構造に正解ラベルを使わない。絶対BIC、出現率0.85、CPT幅0.20などを普遍的合格基準としない。出力の意味と根拠はNotebookのMarkdownセルを参照。


## 今回の出力をどう読むか

- 両手法で出現率0.95を超える辺は **5本**。この境界は本例の確認値です。
- 手法差が最も大きい **Rain―Sprinkler** はHC=64.6%、Tabu=12.7%。単一手法だけで安定した関係と断定せず保留します。
- CPTの95%信用区間幅の最大値は **6.86ポイント**。全セルで今回の暫定幅20ポイント以内ですが、構造を固定した推定精度の確認です。
- 再学習の出現率のMonte Carlo半幅最大は **1.71ポイント**。今回の計算精度目標±2ポイントを確認し、都合のよい結論を得るための追加反復はしません。
- 反復CVの差が小さい候補同士を順位だけで優劣断定しません。実務の必要精度、費用、対象範囲が未定なので採用の総合判定は保留です。