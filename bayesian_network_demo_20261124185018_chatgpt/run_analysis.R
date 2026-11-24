library(bnlearn)
source('bn_functions.R', encoding='UTF-8')

config <- list(
  states = c('低', '中', '高'),
  algorithms = c('HC', 'Tabu', 'Independent'),
  max_parents = 2L,
  cv_runs = 5L,
  cv_folds = 5L,
  bootstrap_R = 500L,
  bootstrap_seeds = c(101L, 202L, 303L),
  seed = 42L,
  report_algorithm = 'HC',
  report_iss = 10,
  output_dir = 'results'
)

parameter_grid <- data.frame(
  label = c('MLE', 'Bayes1', 'Bayes10', 'Bayes100'),
  method = c('mle', 'bayes', 'bayes', 'bayes'),
  iss = c(NA_real_, 1, 10, 100)
)
stopifnot(config$cv_runs >= 1, config$cv_folds >= 2,
          config$bootstrap_R >= 2, config$max_parents >= 1,
          config$report_algorithm %in% config$algorithms,
          config$report_iss > 0)
dir.create(config$output_dir, showWarnings=FALSE, recursive=TRUE)
print(R.version.string)
print(packageVersion('bnlearn'))
print(parameter_grid)

make_sample_df <- function(n=1200L, seed=42L) {
  set.seed(seed)
  states <- c('低', '中', '高')
  quality <- sample(1:3, n, replace=TRUE, prob=c(.25,.45,.30))
  value <- sample(1:3, n, replace=TRUE, prob=c(.30,.40,.30))
  speed <- ifelse(runif(n)<.65, quality, sample(1:3,n,replace=TRUE))
  satisfaction_score <- .50*quality + .35*value + .15*speed + rnorm(n,0,.45)
  satisfaction <- as.integer(cut(satisfaction_score,c(-Inf,1.6,2.4,Inf)))
  renewal <- as.integer(cut(satisfaction+rnorm(n,0,.6),c(-Inf,1.6,2.4,Inf)))
  data.frame(
    サービス品質=states[quality], 価格納得感=states[value],
    対応速度=states[speed], 満足度=states[satisfaction],
    継続意向=states[renewal], check.names=FALSE
  )
}

sample_generated <- !exists('df', inherits=FALSE)
if (sample_generated) {
  df <- make_sample_df()
  message('動作例として3値サンプルdfを生成しました。')
} else {
  message('既存のdfを使用します。サンプルへの置換はしません。')
}

original_df <- df
head(df)

data_bn <- prepare_df(df, config$states)
stopifnot(identical(df, original_df), config$cv_folds <= nrow(data_bn))
counts <- state_counts(data_bn)
if (any(counts$n==0)) warning('未観測の水準があります。推定は事前分布に依存する可能性があります。')
if (any(counts$n < config$cv_folds)) warning('一部の状態が少なく、CVで学習不能になる可能性があります。')
IRdisplay::display_markdown(markdown_table(counts))
write.csv(counts,file.path(config$output_dir,'state_counts.csv'),row.names=FALSE)

networks <- setNames(
  lapply(config$algorithms, function(algorithm) {
    learn_structure(data_bn, algorithm, config$max_parents)
  }),
  config$algorithms
)

structure_scores <- do.call(rbind, lapply(names(networks), function(name) {
  network <- networks[[name]]
  data.frame(
    algorithm=name, edges=nrow(arcs(network)),
    parameters=nparams(network,data_bn),
    BIC=score(network,data_bn,type='bic')
  )
}))
IRdisplay::display_markdown(markdown_table(structure_scores))

cv_detail <- run_cv(data_bn, config, parameter_grid)
cv_result <- summarize_cv(cv_detail)

IRdisplay::display_markdown(markdown_table(cv_result$summary))
write.csv(cv_detail, file.path(config$output_dir,'cv_detail.csv'), row.names=FALSE)
write.csv(cv_result$per_run, file.path(config$output_dir,'cv_per_run.csv'), row.names=FALSE)
write.csv(cv_result$summary, file.path(config$output_dir,'cv_summary.csv'), row.names=FALSE)

# 失敗・警告も確認する（空なら該当なし）。
subset(cv_detail, status!='ok' | warnings!='')

report_network <- networks[[config$report_algorithm]]
report_fit <- fit_parameters(report_network, data_bn, 'bayes', config$report_iss)
stopifnot(check_cpt(report_fit))

cpt <- cpt_details(report_network, report_fit, data_bn, config$report_iss)
cpt$needs_precision_review <- cpt$width > .20 | cpt$n_context == 0

IRdisplay::display_markdown(markdown_table(cpt))
write.csv(cpt, file.path(config$output_dir,'CPT_all_three_states.csv'), row.names=FALSE)

bootstrap <- run_bootstrap(data_bn, config)
edge_summary <- bootstrap$summary
edge_summary$stable_candidate <- with(
  edge_summary,
  successful_seeds == planned_seeds & MC_lower > .95
)

IRdisplay::display_markdown(markdown_table(edge_summary))
IRdisplay::display_markdown(markdown_table(bootstrap$thresholds))
write.csv(bootstrap$raw,file.path(config$output_dir,'bootstrap_detail.csv'),row.names=FALSE)
write.csv(edge_summary,file.path(config$output_dir,'edge_summary.csv'),row.names=FALSE)
write.csv(bootstrap$errors,file.path(config$output_dir,'bootstrap_errors.csv'),row.names=FALSE)
bootstrap$errors

write.csv(structure_scores,file.path(config$output_dir,'structure_scores.csv'),row.names=FALSE)
saveRDS(list(config=config,networks=networks,report_fit=report_fit),
        file.path(config$output_dir,'models_and_config.rds'))
capture.output(sessionInfo(),file=file.path(config$output_dir,'sessionInfo.txt'))
if (sample_generated) write.csv(df,file.path(config$output_dir,'generated_sample.csv'),row.names=FALSE)

result_md <- paste0(
  '# 三段階離散データの分析結果\n\n',
  if(sample_generated) '人工データの実験結果です。実顧客についての結論ではありません。' else '既存dfを用いた探索的な分析です。',
  '\n\n## 構造比較（BICは高い方が良い）\n\n',markdown_table(structure_scores),
  '\n\n## 反復CV（NLLは低い方が良い）\n\n',markdown_table(cv_result$summary),
  '\n\n## エッジ安定性\n\n',markdown_table(edge_summary),
  '\n\n## 留意点\n\n低・中・高は順序制約を置かない離散カテゴリ。確率表は全3状態を出力。',
  '固定構造の信用区間とBootstrapのMC区間は対象が異なります。実務の最小差は未設定です。'
)
writeLines(result_md, file.path(config$output_dir,'RESULT.md'))
IRdisplay::display_markdown(result_md)
stopifnot(identical(df,original_df))
# データや設定を変えた場合にも、説明文を実際の結果から更新する。
failures <- sum(cv_detail$status!='ok')
zero_cases <- sum(cv_detail$status=='zero_probability')
hc10 <- subset(cv_result$summary,algorithm=='HC' & parameter=='Bayes10')
base10 <- subset(cv_result$summary,algorithm=='Independent' & parameter=='Bayes10')
interpretation <- paste0(
  '## 今回の結果の読み取り\n\n',
  '- 観測数は',nrow(data_bn),'行、項目数は',ncol(data_bn),'列。各列を低・中・高の離散カテゴリとして分析しました。\n',
  '- CVは合計',nrow(cv_detail),'条件を実行。ok以外は',failures,'件、そのうち0確率による無限大損失は',zero_cases,'件です。失敗を除外した平均は出していません。\n',
  '- HC/Bayes10の平均NLLは',round(hc10$mean_NLL,4),'、独立モデル/Bayes10は',round(base10$mean_NLL,4),'。小さいほど良い指標で、同じ列・分割で比較します。\n',
  '- MLEが未観測・稀少状態に弱い場合、平滑化とデータ件数の点検が必要です。ベイズ推定が有限値を返すだけで十分なデータがあるとは判断しません。\n',
  '- 確率表は3状態すべてについて出力し、件数・区間・事前依存を併記しました。業務での採用基準は未設定です。'
)
IRdisplay::display_markdown(interpretation)
cat(paste0('\n\n',interpretation),file=file.path(config$output_dir,'RESULT.md'),append=TRUE)
writeLines(interpretation,file.path(config$output_dir,'INTERPRETATION.md'))
