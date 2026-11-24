# 三段階カテゴリ用の分析関数。分析の実行順序はNotebookで管理します。
# 既存のdfは変更せず、検査済みコピーだけを返します。
prepare_df <- function(df, states = c('低', '中', '高')) {
  if (!is.data.frame(df) || ncol(df) < 2L || nrow(df) < 10L)
    stop('dfは2列以上・10行以上のデータフレームにしてください。')
  if (anyDuplicated(names(df)) || anyNA(names(df)) || any(names(df) == ''))
    stop('列名は重複・欠損・空文字のない名前にしてください。')
  result <- df
  for (name in names(df)) {
    values <- as.character(df[[name]])
    if (anyNA(values)) stop(paste(name, ': 欠損があります。処理方針を決めてください。'))
    invalid <- setdiff(unique(values), states)
    if (length(invalid)) stop(paste(name, ': 高・中・低以外の値:', paste(invalid, collapse=', ')))
    if (length(unique(values)) < 2L) stop(paste(name, ': 1種類しか観測されていません。'))
    # ordered factorにはしない。これは大小の単調性を仮定しない離散BN。
    result[[name]] <- factor(values, levels = states, ordered = FALSE)
  }
  result
}

state_counts <- function(data) {
  do.call(rbind, lapply(names(data), function(name) {
    count <- table(data[[name]])
    data.frame(variable=name, state=names(count), n=as.integer(count),
               fraction=as.numeric(count)/nrow(data), row.names=NULL)
  }))
}

learn_structure <- function(data, algorithm, max_parents) {
  switch(algorithm,
    HC = bnlearn::hc(data, score='bic', maxp=max_parents),
    Tabu = bnlearn::tabu(data, score='bic', maxp=max_parents),
    Independent = bnlearn::empty.graph(names(data)),
    stop('未対応のアルゴリズムです。')
  )
}

fit_parameters <- function(network, data, method, iss) {
  if (method == 'mle') {
    bnlearn::bn.fit(network, data, method='mle', replace.unidentifiable=FALSE)
  } else {
    bnlearn::bn.fit(network, data, method='bayes', iss=iss)
  }
}

check_cpt <- function(fitted) {
  all(vapply(fitted, function(node) {
    p <- node$prob
    all(is.finite(p)) && all(p >= 0 & p <= 1) &&
      all(abs(colSums(matrix(p, nrow=dim(p)[1])) - 1) < 1e-8)
  }, logical(1)))
}

# スカラー指標は全列の同時負の対数尤度。3^列数の全状態列挙はしません。
evaluate_fit <- function(fitted, test) {
  if (!check_cpt(fitted)) return(list(loss=NA_real_, status='unidentifiable_CPT'))
  nll <- -as.numeric(logLik(fitted, data=test))/nrow(test)
  list(loss=nll, status=if(is.finite(nll)) 'ok' else 'zero_probability')
}

# 進捗が追える4階層: 反復 -> fold -> 構造手法 -> パラメータ設定。
# 同じfold・手法内では構造を一度だけ学習し、パラメータ比較に再利用します。
run_cv <- function(data, config, parameter_grid) {
  rows <- list()
  for (run in seq_len(config$cv_runs)) {
    set.seed(config$seed + run)
    fold_id <- sample(rep(seq_len(config$cv_folds), length.out=nrow(data)))
    for (fold in seq_len(config$cv_folds)) {
      train <- data[fold_id != fold, , drop=FALSE]
      test  <- data[fold_id == fold, , drop=FALSE]
      for (algorithm in config$algorithms) {
        network <- tryCatch(
          learn_structure(train, algorithm, config$max_parents),
          error=function(e) e
        )
        for (i in seq_len(nrow(parameter_grid))) {
          setting <- parameter_grid[i, ]
          warnings <- character()
          evaluation <- tryCatch(withCallingHandlers({
            if (inherits(network, 'error')) stop(conditionMessage(network))
            fitted <- fit_parameters(network, train, setting$method, setting$iss)
            evaluate_fit(fitted, test)
          }, warning=function(w) {
            warnings <<- c(warnings, conditionMessage(w))
            invokeRestart('muffleWarning')
          }), error=function(e) list(loss=NA_real_, status=paste('error:', conditionMessage(e))))
          rows[[length(rows)+1L]] <- data.frame(
            run=run, fold=fold, n_test=nrow(test), algorithm=algorithm,
            parameter=setting$label, joint_NLL=evaluation$loss,
            status=evaluation$status, warnings=paste(unique(warnings), collapse='; ')
          )
        }
      }
    }
    message('CV: ', run, '/', config$cv_runs, ' 完了')
  }
  do.call(rbind, rows)
}

summarize_cv <- function(cv) {
  per_run <- lapply(split(cv, interaction(cv$run,cv$algorithm,cv$parameter,drop=TRUE)), function(x) {
    complete <- all(x$status == 'ok')
    data.frame(run=x$run[1],algorithm=x$algorithm[1],parameter=x$parameter[1],
               joint_NLL=if(complete) weighted.mean(x$joint_NLL,x$n_test) else NA_real_,
               failed_folds=sum(x$status!='ok'))
  })
  per_run <- do.call(rbind, per_run)
  summary <- lapply(split(per_run,interaction(per_run$algorithm,per_run$parameter,drop=TRUE)), function(x) {
    complete <- all(is.finite(x$joint_NLL))
    data.frame(algorithm=x$algorithm[1],parameter=x$parameter[1],
      runs=nrow(x),failed_folds=sum(x$failed_folds),
      mean_NLL=if(complete)mean(x$joint_NLL)else NA_real_,
      min_NLL=if(complete)min(x$joint_NLL)else NA_real_,
      max_NLL=if(complete)max(x$joint_NLL)else NA_real_)
  })
  list(per_run=per_run, summary=do.call(rbind,summary))
}

# 多項Dirichletの各状態に対する周辺Beta信用区間を計算します。
cpt_details <- function(network, fitted, data, iss, max_rows=100000L) {
  rows <- list()
  for (variable in names(data)) {
    pa <- bnlearn::parents(network, variable)
    states <- levels(data[[variable]])
    r <- length(states)
    q <- if(length(pa))prod(vapply(data[pa], nlevels, integer(1)))else 1L
    if (q*r > max_rows) stop('CPTが大きすぎます。max_parentsを減らしてください。')
    contexts <- if(length(pa))expand.grid(lapply(data[pa],levels),stringsAsFactors=FALSE)else data.frame(dummy=1)
    for (j in seq_len(q)) {
      selected <- rep(TRUE,nrow(data))
      for (parent in pa) selected <- selected & data[[parent]]==contexts[[parent]][j]
      n_context <- sum(selected)
      alpha <- iss/(r*q)
      for (state in states) {
        count <- sum(data[[variable]][selected]==state)
        prob <- (count+alpha)/(n_context+r*alpha)
        interval <- qbeta(c(.025,.975),count+alpha,n_context-count+(r-1)*alpha)
        indices <- c(setNames(list(state),variable),as.list(contexts[j,pa,drop=FALSE]))
        p <- fitted[[variable]]$prob
        dimensions <- names(dimnames(p))
        if(is.null(dimensions)) dimensions <- variable
        actual <- do.call('[',c(list(p),indices[dimensions],list(drop=TRUE)))
        stopifnot(abs(actual-prob)<1e-10)
        rows[[length(rows)+1L]] <- data.frame(
          variable=variable,
          parent_state=if(length(pa))paste(paste(pa,as.character(contexts[j,pa]),sep='='),collapse=', ')else '(なし)',
          state=state,n_context=n_context,n_state=count,probability=prob,
          lower=interval[1],upper=interval[2],width=diff(interval),
          prior_fraction=(iss/q)/(n_context+iss/q)
        )
      }
    }
  }
  do.call(rbind,rows)
}

run_bootstrap <- function(data,config) {
  rows <- list(); thresholds <- list(); errors <- list()
  for(algorithm in setdiff(config$algorithms,'Independent')) {
    for(seed in config$bootstrap_seeds) {
      set.seed(seed)
      method <- switch(algorithm,HC='hc',Tabu='tabu')
      b <- tryCatch(bnlearn::boot.strength(
        data,R=config$bootstrap_R,algorithm=method,
        algorithm.args=list(score='bic',maxp=config$max_parents),cpdag=TRUE
      ),error=function(e)e)
      if(inherits(b,'error')) {
        errors[[length(errors)+1L]] <- data.frame(algorithm=algorithm,seed=seed,error=conditionMessage(b))
        next
      }
      # 列順で各ペアを一度だけ取得。日本語の文字照合順に依存しません。
      b1 <- as.data.frame(b[match(b$from,names(data))<match(b$to,names(data)),])
      b1$algorithm <- algorithm; b1$seed <- seed
      rows[[length(rows)+1L]] <- b1
      thresholds[[length(thresholds)+1L]] <- data.frame(algorithm=algorithm,seed=seed,threshold=bnlearn::inclusion.threshold(b))
      message('Bootstrap: ',algorithm,' / seed=',seed,' 完了')
    }
  }
  if(!length(rows)) stop('すべてのBootstrapが失敗しました。希少状態・入力を確認してください。')
  raw <- do.call(rbind,rows)
  grouped <- split(raw,interaction(raw$algorithm,raw$from,raw$to,drop=TRUE))
  summary <- do.call(rbind,lapply(grouped,function(x){
    p <- mean(x$strength); N <- config$bootstrap_R*nrow(x); z <- 1.96
    center <- (p+z*z/(2*N))/(1+z*z/N)
    half <- z*sqrt(p*(1-p)/N+z*z/(4*N*N))/(1+z*z/N)
    data.frame(algorithm=x$algorithm[1],from=x$from[1],to=x$to[1],
      successful_seeds=nrow(x),planned_seeds=length(config$bootstrap_seeds),
      strength=p,seed_range=diff(range(x$strength)),MC_lower=center-half,MC_upper=center+half,
      direction=if(sum(x$strength)>0)weighted.mean(x$direction,x$strength)else NA_real_)
  }))
  list(raw=raw,summary=summary,thresholds=do.call(rbind,thresholds),
       errors=if(length(errors))do.call(rbind,errors)else data.frame(algorithm=character(),seed=integer(),error=character()))
}

markdown_table <- function(data,digits=4) {
  x <- data
  for(name in names(x)) if(is.numeric(x[[name]])) x[[name]] <- formatC(x[[name]],format='f',digits=digits)
  paste(c(paste0('| ',paste(names(x),collapse=' | '),' |'),
          paste0('| ',paste(rep('---',ncol(x)),collapse=' | '),' |'),
          apply(x,1,function(row)paste0('| ',paste(row,collapse=' | '),' |'))),collapse='\n')
}
