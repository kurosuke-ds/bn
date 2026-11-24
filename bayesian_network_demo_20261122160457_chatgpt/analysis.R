library(bnlearn)
stopifnot(grepl('/envs/bn/',R.home(),fixed=TRUE))
options(repr.plot.width=14,repr.plot.height=5)
CONFIG<-list(cv_runs=10,cv_folds=5,bootstrap_R=1000,bootstrap_seeds=c(101,202,303),candidate_thresholds=c(.70,.85,.95),probability_width=.20,mc_halfwidth=.02,split_seed=42)
set.seed(CONFIG$split_seed)
read_data<-function(p){d<-read.csv(p);stopifnot(!anyNA(d),all(vapply(d,function(x)all(x %in% c(0,1)),logical(1))));d[]<-lapply(d,factor,levels=c(0,1));d}
dev<-read_data('data/develop.csv');evaluation<-read_data('data/validation.csv');target<-'Slippery'
md_table<-function(d){x<-d;for(k in names(x))if(is.numeric(x[[k]])){if(grepl('(^p$|^p_|_p$)',k))x[[k]]<-ifelse(x[[k]]==0,'0*',formatC(x[[k]],digits=3,format='g'))else x[[k]]<-formatC(x[[k]],digits=4,format='f')};paste(c(paste0('| ',paste(names(x),collapse=' | '),' |'),paste0('| ',paste(rep('---',ncol(x)),collapse=' | '),' |'),apply(x,1,function(r)paste0('| ',paste(r,collapse=' | '),' |'))),collapse='\n')}
show<-function(title,d,note=''){write.csv(d,paste0('results/',title,'.csv'),row.names=FALSE);IRdisplay::display_markdown(paste0('### ',title,'\n\n',md_table(d),'\n\n',note))}
quality<-data.frame(variable=names(dev),n=nrow(dev),missing=sapply(dev,function(x)sum(is.na(x))),state1=sapply(dev,function(x)sum(x=='1')),state0=sapply(dev,function(x)sum(x=='0')))
show('data_quality',quality);print(CONFIG);print(R.version.string);print(packageVersion('bnlearn'))

joint<-function(f){g<-expand.grid(setNames(rep(list(c('0','1')),length(f)),names(f)),stringsAsFactors=FALSE);p<-rep(1,nrow(g));for(v in names(f)){tab<-f[[v]]$prob;vs<-names(dimnames(tab));if(is.null(vs))vs<-v;p<-p*vapply(seq_len(nrow(g)),function(i)do.call('[',c(list(tab),as.list(g[i,vs,drop=FALSE]),list(drop=TRUE))),numeric(1))};stopifnot(all(is.finite(p)),abs(sum(p)-1)<1e-8);g$prob<-p;g}
query<-function(j,evidence=list()){ix<-rep(TRUE,nrow(j));for(v in names(evidence))ix<-ix & j[[v]]==as.character(evidence[[v]]);sum(j$prob[ix & j[[target]]=='1'])/sum(j$prob[ix])}
pred<-function(f,d){j<-joint(f);fs<-setdiff(names(f),target);keys<-apply(d[,fs,drop=FALSE],1,paste,collapse='|');u<-which(!duplicated(keys));values<-vapply(u,function(i)query(j,as.list(d[i,fs,drop=FALSE])),numeric(1));unname(setNames(values,keys[u])[keys])}
binary_loss<-function(y,p){out<-numeric(length(y));out[y==1]<- -log(p[y==1]);out[y==0]<- -log1p(-p[y==0]);out}
learn<-function(d,a)switch(a,HC_BIC=hc(d,score='bic',maxp=3),HC_BDeu=hc(d,score='bde',iss=10,maxp=3),Tabu=tabu(d,score='bic',maxp=3),MMHC=mmhc(d,restrict.args=list(test='mi',alpha=.01),maximize.args=list(score='bic',maxp=3)),Independent=empty.graph(names(d)))
fit_model<-function(g,d,method){if(method=='MLE')bn.fit(g,d,method='mle')else bn.fit(g,d,method='bayes',iss=as.numeric(sub('Bayes','',method)))}
valid_fit<-function(f)all(vapply(f,function(node){p<-node$prob;all(is.finite(p))&&all(p>=0)&&all(p<=1)&&all(abs(colSums(matrix(p,nrow=dim(p)[1]))-1)<1e-8)},logical(1)))
assess<-function(f,d){if(!valid_fit(f))return(c(joint_NLL=NA,target_NLL=NA,Brier=NA));p<-pred(f,d);y<-as.numeric(d[[target]]=='1');c(joint_NLL=-as.numeric(logLik(f,data=d))/nrow(d),target_NLL=mean(binary_loss(y,p)),Brier=mean((y-p)^2))}

algorithms<-c('HC_BIC','HC_BDeu','Tabu','MMHC','Independent')
nets<-setNames(lapply(algorithms,function(a)learn(dev,a)),algorithms)
scores<-do.call(rbind,lapply(algorithms,function(a){g<-nets[[a]];data.frame(algorithm=a,edges=nrow(arcs(g)),parameters=nparams(g,dev),BIC_bnlearn=score(g,dev,type='bic'),BDeu=score(g,dev,type='bde',iss=10))}))
scores$gap_from_best_BIC<-max(scores$BIC_bnlearn)-scores$BIC_bnlearn
scores$conventional_delta_BIC<-2*scores$gap_from_best_BIC
show('structure_scores',scores,'同じデータ・変数で比較。gap=0が候補中の最高。差が0でも唯一の構造とは限りません。常用BICの差はbnlearnの差の2倍です。')

specs<-rbind(data.frame(algorithm=algorithms,method='Bayes10'),data.frame(algorithm='HC_BIC',method=c('MLE','Bayes1','Bayes100')))
cv<-list();runs<-CONFIG$cv_runs;k<-CONFIG$cv_folds
for(run in seq_len(runs)){
 set.seed(500+run);fold<-integer(nrow(dev));for(z in levels(dev[[target]])){ix<-which(dev[[target]]==z);fold[ix]<-sample(rep(seq_len(k),length.out=length(ix)))}
 for(b in seq_len(k)){
  tr<-dev[fold!=b,];te<-dev[fold==b,];gg<-setNames(lapply(algorithms,function(a)learn(tr,a)),algorithms)
  for(i in seq_len(nrow(specs))){a<-specs$algorithm[i];m<-specs$method[i];f<-fit_model(gg[[a]],tr,m);sc<-assess(f,te);cv[[length(cv)+1]]<-data.frame(run=run,fold=b,n=nrow(te),algorithm=a,method=m,t(sc),valid_CPT=valid_fit(f))}
 }
 cat('CV run',run,'of',runs,'\n')
}
cv<-do.call(rbind,cv);write.csv(cv,'results/cv_all_folds.csv',row.names=FALSE)
run_scores<-aggregate(cbind(joint_NLL,target_NLL,Brier)~run+algorithm+method,data=cv,FUN=mean,na.action=na.pass)
cv_summary<-do.call(rbind,lapply(split(run_scores,interaction(run_scores$algorithm,run_scores$method,drop=TRUE)),function(x)data.frame(algorithm=x$algorithm[1],method=x$method[1],runs=nrow(x),joint_NLL_mean=mean(x$joint_NLL),joint_NLL_min=min(x$joint_NLL),joint_NLL_max=max(x$joint_NLL),target_NLL=mean(x$target_NLL),Brier=mean(x$Brier))))
show('repeated_CV',cv_summary,'低いほど良好。min/maxは分割を変えた10回の観測範囲で、95%信頼区間ではありません。各foldで構造から学習しています。MLEの無限大損失やNAは除外せず保存します。')
base<-run_scores[run_scores$algorithm=='Independent',c('run','joint_NLL')];names(base)[2]<-'baseline'
gain<-merge(run_scores,base,by='run');gain$improvement<-gain$baseline-gain$joint_NLL
stability_cv<-do.call(rbind,lapply(split(gain,interaction(gain$algorithm,gain$method,drop=TRUE)),function(x)data.frame(algorithm=x$algorithm[1],method=x$method[1],mean_improvement=mean(x$improvement),positive_run_fraction=mean(x$improvement>0))))
show('CV_improvement',stability_cv,'改善幅>0なら独立モデルより良好。10/10で改善しても確率100%の保証ではありません。繰り返しは同じ標本を共有するため独立試験ではありません。')

chosen<-nets$HC_BIC;fitted<-fit_model(chosen,dev,'Bayes10');iss<-10
cpt<-list()
for(v in names(fitted)){
 pa<-parents(chosen,v);contexts<-if(length(pa))expand.grid(setNames(lapply(pa,function(p)levels(dev[[p]])),pa),stringsAsFactors=FALSE)else data.frame(dummy=1)
 q<-nrow(contexts)
 for(i in seq_len(q)){
  ix<-rep(TRUE,nrow(dev));if(length(pa))for(p in pa)ix<-ix & dev[[p]]==contexts[[p]][i]
  n<-sum(ix);yes<-sum(dev[[v]][ix]=='1');alpha<-iss/(2*q);post<-(yes+alpha)/(n+2*alpha)
  tab<-fitted[[v]]$prob;vs<-names(dimnames(tab));if(is.null(vs))vs<-v
  vals<-setNames(list('1'),v);for(p in pa)vals[[p]]<-contexts[[p]][i]
  actual<-do.call('[',c(list(tab),vals[vs],list(drop=TRUE)));stopifnot(abs(actual-post)<1e-10)
  lo<-qbeta(.025,yes+alpha,n-yes+alpha);hi<-qbeta(.975,yes+alpha,n-yes+alpha)
  cpt[[length(cpt)+1]]<-data.frame(variable=v,parents=if(length(pa))paste(paste(pa,contexts[i,pa],sep='='),collapse=',')else '(none)',n_context=n,events=yes,MLE=if(n)yes/n else NA,Bayes10=post,low=lo,high=hi,width=hi-lo,precision_check=if(hi-lo<=CONFIG$probability_width)'within_demo_tolerance'else 'needs_more_data')
 }
}
cpt<-do.call(rbind,cpt);show('CPT_precision',cpt,'low/highは構造とISSを固定したBeta事後95%信用区間。構造選択の不確実性は含みません。幅0.20は今回の仮の許容値であり公式合格基準ではありません。n_context=0ならデータ根拠がありません。')
checks<-do.call(rbind,lapply(c('MLE','Bayes1','Bayes10','Bayes100'),function(m){f<-fit_model(chosen,dev,m);data.frame(method=m,valid_CPT=valid_fit(f),zero_probabilities=sum(vapply(f,function(x)sum(x$prob==0,na.rm=TRUE),integer(1))),t(assess(f,evaluation)))}))
show('parameter_checks',checks,'確率は0〜1、親状態ごとの和=1が必須。計算誤差の許容1e-8は数値検査です。MLEで0になる場合、評価でその事象が出ると損失は無限大。ベイズ推定の非ゼロは十分なデータの証拠ではありません。')
prior_detail<-do.call(rbind,lapply(c(1,10,100),function(s){ff<-bn.fit(chosen,dev,method='bayes',iss=s);diff<-unlist(lapply(names(ff),function(v)as.numeric(ff[[v]]$prob)-as.numeric(fitted[[v]]$prob)));data.frame(ISS=s,max_CPT_change_from_ISS10=max(abs(diff)),mean_CPT_change=mean(abs(diff)),t(assess(ff,evaluation)))}))
show('prior_sensitivity',prior_detail,'構造を固定してISSだけを変えた検査。確率の変化は0〜1単位（0.01=1ポイント）。変化が小さければこの範囲の事前設定には頑健ですが、構造変更への頑健性を証明するものではありません。')


boots<-list();bootstrap_long<-list();thresholds<-list()
for(a in c('hc','tabu'))for(seed in CONFIG$bootstrap_seeds){
 set.seed(seed);b<-boot.strength(dev,R=CONFIG$bootstrap_R,algorithm=a,algorithm.args=list(score='bic',maxp=3),cpdag=TRUE)
 key<-paste(a,seed,sep='_');boots[[key]]<-b;z<-as.data.frame(b[b$from<b$to,]);z$algorithm<-a;z$seed<-seed;bootstrap_long[[key]]<-z
 thresholds[[key]]<-data.frame(algorithm=a,seed=seed,automatic_threshold=inclusion.threshold(b));cat('Bootstrap',key,'done\n')
}
bootstrap_long<-do.call(rbind,bootstrap_long);write.csv(bootstrap_long,'results/bootstrap_by_seed.csv',row.names=FALSE)
show('automatic_thresholds',do.call(rbind,thresholds),'inclusion.thresholdはデータから算出される境界で、FDR5%の保証や真の関係の確率ではありません。境界と同じ強度の辺は採用条件strength > thresholdを満たしません。')
edges<-do.call(rbind,lapply(split(bootstrap_long,interaction(bootstrap_long$algorithm,bootstrap_long$from,bootstrap_long$to,drop=TRUE)),function(z){p<-mean(z$strength);N<-CONFIG$bootstrap_R*nrow(z);zz<-1.96;center<-(p+zz^2/(2*N))/(1+zz^2/N);half<-zz*sqrt(p*(1-p)/N+zz^2/(4*N*N))/(1+zz^2/N);data.frame(algorithm=z$algorithm[1],from=z$from[1],to=z$to[1],strength=p,seed_range=diff(range(z$strength)),MC_low=center-half,MC_high=center+half,direction=if(sum(z$strength)>0)weighted.mean(z$direction,z$strength)else NA,MC_halfwidth=half)}))
show('edge_stability',edges,'MC区間は固定された入力標本からの反復回数の有限性だけを表します。母集団の真の辺への信頼区間ではありません。directionはこの表のfrom→toを支持する度合いで、0.5付近は方向不確定。')
threshold_sensitivity<-do.call(rbind,lapply(CONFIG$candidate_thresholds,function(t){x<-edges;x$threshold<-t;x$selected<-x$strength>t;x$robust_to_MC<-x$MC_low>t;x[,c('algorithm','from','to','threshold','strength','selected','robust_to_MC')]}))
show('threshold_sensitivity',threshold_sensitivity,'0.70/0.85/0.95は感度を見るための例示的境界です。0.85を普遍的な妥当性基準にはしません。MC下限が閾値を超える場合でも実務的重要性を意味しません。')

repeat_plan<-data.frame(bootstrap_R=c(200,500,1000,3000,10000),worst_MC_SE=sqrt(.25/c(200,500,1000,3000,10000)),approx_95_halfwidth=1.96*sqrt(.25/c(200,500,1000,3000,10000)))
show('repeat_precision',repeat_plan,'p=0.5の最悪条件による近似。例えば半幅±0.02を目標とするなら約2401回が目安です。これは再標本化の計算誤差で、データ不足を繰り返し回数で補えるわけではありません。')
need<-ceiling(.25*(1.96/CONFIG$mc_halfwidth)^2);print(need)
show('repeat_status',data.frame(total_per_algorithm=CONFIG$bootstrap_R*length(CONFIG$bootstrap_seeds),max_MC_halfwidth=max(edges$MC_halfwidth),target_halfwidth=CONFIG$mc_halfwidth,need_more_for_MC=max(edges$MC_halfwidth)>CONFIG$mc_halfwidth),'境界に近い辺は回数追加を検討。乱数間・手法間で判断が変わる辺は保留。繰り返すたびに都合のよい結果を選ぶことはしません。')

pairs<-combn(names(dev),2,simplify=FALSE)
association<-do.call(rbind,lapply(pairs,function(pair){tab<-table(dev[[pair[1]]],dev[[pair[2]]]);p<-tab/sum(tab);expected<-outer(rowSums(p),colSums(p));MI<-sum(p[p>0]*log2(p[p>0]/expected[p>0]));chi<-sum((tab-sum(tab)*expected)^2/(sum(tab)*expected));test<-ci.test(pair[1],pair[2],data=dev,test='mi');data.frame(x=pair[1],y=pair[2],MI_bits=MI,Cramers_V=sqrt(chi/(sum(tab)*min(nrow(tab)-1,ncol(tab)-1))),p_value=test$p.value)}))
association$p_Holm<-p.adjust(association$p_value,method='holm');association$screen_p05<-association$p_Holm<.05
show('pairwise_association',association,'全10組を検定してHolm補正。p<0.05は慣用的なスクリーニング水準で、効果が大きい・辺が直接存在する・実務的に有用の意味ではありません。MIとVは無条件の関連であり第三変数の影響を除いていません。')
removal<-as.data.frame(arc.strength(chosen,dev,criterion='bic'));names(removal)[3]<-'BIC_after_minus_before';show('edge_removal',removal,'負なら辺を除くとBICが悪化。より大きな負値は残りの構造を固定したときのスコア寄与が大きいことを示し、確率差や因果効果の単位ではありません。')

fit<-fit_model(chosen,dev,'Bayes10');p<-pred(fit,evaluation);y<-as.numeric(evaluation[[target]]=='1');baseline<-rep(mean(dev[[target]]=='1'),length(y))
# この5変数を用いた評価は過去使用済み。探索的な再計算として表示。
cal<-do.call(rbind,lapply(0:9,function(b){ix<-p>=b/10 & p<(b+1)/10;N<-sum(ix);if(!N)return(NULL);q<-mean(y[ix]);z<-1.96;mid<-(q+z*z/(2*N))/(1+z*z/N);half<-z*sqrt(q*(1-q)/N+z*z/(4*N*N))/(1+z*z/N);data.frame(bin=paste0(b/10,'-',(b+1)/10),n=N,predicted=mean(p[ix]),observed=q,absolute_gap=abs(q-mean(p[ix])),Wilson_low=mid-half,Wilson_high=mid+half)}))
show('calibration',cal,'gapは小さいほど良好ですが、小標本ビンの見かけの差には注意。±0.05などの許容幅は、意思決定の影響から別途合意が必要です。Wilson区間に予測が入ることだけで校正合格とは判定しません。')
set.seed(900);dif<-binary_loss(y,baseline)-binary_loss(y,p);bs<-replicate(2000,mean(sample(dif,replace=TRUE)));improvement<-data.frame(mean=mean(dif),low=quantile(bs,.025),high=quantile(bs,.975),Brier_BN=mean((y-p)^2),Brier_baseline=mean((y-baseline)^2),Brier_skill=1-mean((y-p)^2)/mean((y-baseline)^2))
show('baseline_comparison',improvement,'対数損失改善>0、Brier skill>0なら基準より良好。Brier skill=0は同じ、1は完全予測、負は悪化。区間は固定モデルと独立行を仮定し、評価標本のばらつきだけを表します。実務採用には最小改善幅が必要です。')
par(bg='white',mfrow=c(1,2),mar=c(4,10,3,1));boxplot(joint_NLL~interaction(algorithm,method,drop=TRUE),data=run_scores,horizontal=TRUE,las=1,cex.axis=.65,ylab='',xlab='Joint NLL (lower is better)',main='Repeated 5-fold CV');par(mar=c(4,4,3,1));plot(cal$predicted,cal$observed,xlim=c(0,1),ylim=c(0,1),xlab='Predicted',ylab='Observed',pch=19,main='Calibration');abline(0,1,lty=2);arrows(cal$predicted,cal$Wilson_low,cal$predicted,cal$Wilson_high,angle=90,code=3,length=.05)

judgement<-data.frame(check=c('Probability validity','Repeated CV vs independent','CPT precision example','Finite bootstrap precision','Business acceptability'),result=c(if(valid_fit(fit))'passed numerical check'else'failed',paste(sum(stability_cv$positive_run_fraction==1 & stability_cv$algorithm!='Independent'),'configurations improved in every split'),paste(sum(cpt$width>CONFIG$probability_width),'contexts exceed demo width 0.20'),if(max(edges$MC_halfwidth)<=CONFIG$mc_halfwidth)'within configured MC target'else'increase repetitions','not determined: minimum improvement/cost not specified'))
show('validation_decisions',judgement,'統計上の支持・数値的整合・業務上の妥当性は別の判定です。実務採用の自動合格は出しません。')
report<-paste0('# RESULT：R/bnlearnの妥当性検証\n\n',md_table(judgement),'\n\n## 構造比較\n\n',md_table(scores),'\n\n## 反復交差検証\n\n',md_table(cv_summary),'\n\n## パラメータ精度\n\n',md_table(cpt),'\n\n## 関係の安定性\n\n',md_table(edges),'\n\n## 判断上の制約\n\n人工データ・既存評価標本の再利用。構造に正解ラベルを使わない。絶対BIC、出現率0.85、CPT幅0.20などを普遍的合格基準としない。出力の意味と根拠はNotebookのMarkdownセルを参照。')
writeLines(report,'RESULT.md');IRdisplay::display_markdown(report)
saveRDS(list(config=CONFIG,networks=nets,fitted=fit,bootstrap=boots),'results/models_and_settings.rds');capture.output(sessionInfo(),file='results/sessionInfo.txt')
stopifnot(nrow(cv)==CONFIG$cv_runs*CONFIG$cv_folds*nrow(specs),all(cv$valid_CPT),nrow(edges)==20,valid_fit(fit))
cat('All numerical checks passed.\n')
# 今回の数値に基づく読み取りを再実行時に更新する。
hc_edges<-edges[edges$algorithm=='hc',];tabu_edges<-edges[edges$algorithm=='tabu',]
comparison<-merge(hc_edges[,c('from','to','strength')],tabu_edges[,c('from','to','strength')],by=c('from','to'),suffixes=c('_hc','_tabu'))
comparison$algorithm_gap<-abs(comparison$strength_hc-comparison$strength_tabu)
comparison<-comparison[order(-comparison$algorithm_gap),]
show('algorithm_dependence',comparison,'大きな差がある辺はアルゴリズム依存です。反復回数を増やして計算誤差を減らしても、探索法の違いは解消しない場合があります。')
row<-comparison[1,];stable_count<-sum(comparison$strength_hc>.95 & comparison$strength_tabu>.95)
summary_text<-paste0('## 今回の出力をどう読むか\n\n',
'- 両手法で出現率0.95を超える辺は **',stable_count,'本**。この境界は本例の確認値です。\n',
'- 手法差が最も大きい **',row$from,'―',row$to,'** はHC=',round(row$strength_hc*100,1),'%、Tabu=',round(row$strength_tabu*100,1),'%。単一手法だけで安定した関係と断定せず保留します。\n',
'- CPTの95%信用区間幅の最大値は **',round(max(cpt$width)*100,2),'ポイント**。全セルで今回の暫定幅20ポイント以内ですが、構造を固定した推定精度の確認です。\n',
'- 再学習の出現率のMonte Carlo半幅最大は **',round(max(edges$MC_halfwidth)*100,2),'ポイント**。今回の計算精度目標±2ポイントを確認し、都合のよい結論を得るための追加反復はしません。\n',
'- 反復CVの差が小さい候補同士を順位だけで優劣断定しません。実務の必要精度、費用、対象範囲が未定なので採用の総合判定は保留です。')
IRdisplay::display_markdown(summary_text)
cat(paste0('\n\n',summary_text),file='RESULT.md',append=TRUE)


# 目的は全項目の説明。内側の主選択指標はjoint NLLで固定する。
make_folds<-function(d,k,seed){set.seed(seed);f<-integer(nrow(d));for(z in levels(d[[target]])){ix<-which(d[[target]]==z);f[ix]<-sample(rep(seq_len(k),length.out=length(ix)))};f}
selection_specs<-expand.grid(algorithm=c('HC_BIC','Tabu'),method=c('Bayes1','Bayes10','Bayes100'),stringsAsFactors=FALSE)
selection_specs<-rbind(selection_specs,data.frame(algorithm='Independent',method='Bayes10'))
outer<-make_folds(dev,5,871);nested_rows<-list();selection_rows<-list()
for(o in 1:5){
 train_o<-dev[outer!=o,];test_o<-dev[outer==o,];inner<-make_folds(train_o,3,900+o);inner_rows<-list()
 for(fold in 1:3){tr<-train_o[inner!=fold,];te<-train_o[inner==fold,];gs<-setNames(lapply(c('HC_BIC','Tabu','Independent'),function(a)learn(tr,a)),c('HC_BIC','Tabu','Independent'))
  for(i in seq_len(nrow(selection_specs))){sp<-selection_specs[i,];fm<-fit_model(gs[[sp$algorithm]],tr,sp$method);inner_rows[[length(inner_rows)+1]]<-data.frame(candidate=i,n=nrow(te),NLL=assess(fm,te)['joint_NLL'])}}
 inner_rows<-do.call(rbind,inner_rows);cv_inner<-vapply(seq_len(nrow(selection_specs)),function(i){z<-inner_rows[inner_rows$candidate==i,];weighted.mean(z$NLL,z$n)},numeric(1));winner<-which.min(cv_inner);sp<-selection_specs[winner,]
 for(i in seq_len(nrow(selection_specs)))selection_rows[[length(selection_rows)+1]]<-data.frame(outer=o,selection_specs[i,],inner_NLL=cv_inner[i],selected=i==winner)
 g<-learn(train_o,sp$algorithm);fm<-fit_model(g,train_o,sp$method)
 nested_rows[[o]]<-data.frame(outer=o,algorithm=sp$algorithm,method=sp$method,n=nrow(test_o),t(assess(fm,test_o)),baseline_joint_NLL=assess(fit_model(learn(train_o,'Independent'),train_o,'Bayes10'),test_o)['joint_NLL'])
}
nested<-do.call(rbind,nested_rows);nested$improvement<-nested$baseline_joint_NLL-nested$joint_NLL
write.csv(do.call(rbind,selection_rows),'results/nested_selection_log.csv',row.names=FALSE)
show('nested_CV',nested,'外側の5foldは候補選択に使っていません。評価しているのは7候補から選ぶ手続きで、最終的に学習した特定のネットワークそのものではありません。同じ母集団内の内部検証です。')

# 検定族を事前に固定する代わりに、ここでは開発標本だけから決定。既存評価標本で探索的に照合。
conditional_info<-function(d,x,y,z=character()){
 groups<-if(length(z))interaction(d[,z,drop=FALSE],drop=TRUE)else factor(rep('all',nrow(d)))
 mi<-0;minimum<-Inf
 for(ix in split(seq_len(nrow(d)),groups)){
  tab<-table(d[[x]][ix],d[[y]][ix]);n<-sum(tab);pp<-tab/n;expected<-outer(rowSums(tab),colSums(tab))/n
  nz<-tab>0;mi<-mi+n/nrow(d)*sum(pp[nz]*log2(tab[nz]/expected[nz]));positive<-expected[expected>0];if(length(positive))minimum<-min(minimum,positive)
 }
 c(CMI_bits=mi,min_expected=minimum)
}
statements<-list();a<-arcs(chosen)
for(i in seq_len(nrow(a)))statements[[length(statements)+1]]<-list(kind='edge',x=a[i,1],y=a[i,2],z=setdiff(parents(chosen,a[i,2]),a[i,1]))
# 全ての二変数・残り変数の部分集合から、DAGがd-separationを主張するものを列挙。
for(pair in combn(names(dev),2,simplify=FALSE)){
 remain<-setdiff(names(dev),pair);sets<-list(character());for(k in seq_along(remain))sets<-c(sets,combn(remain,k,simplify=FALSE))
 for(z in sets)if(dsep(chosen,pair[1],pair[2],z))statements[[length(statements)+1]]<-list(kind='implied_independence',x=pair[1],y=pair[2],z=z)
}
set.seed(1300);Bperm<-4999
ci_rows<-lapply(statements,function(s){st<-conditional_info(evaluation,s$x,s$y,s$z);tt<-if(length(s$z))ci.test(s$x,s$y,z=s$z,data=evaluation,test='mc-mi',B=Bperm)else ci.test(s$x,s$y,data=evaluation,test='mc-mi',B=Bperm);data.frame(kind=s$kind,x=s$x,y=s$y,given=if(length(s$z))paste(s$z,collapse=',')else '(none)',CMI_bits=st['CMI_bits'],min_expected=st['min_expected'],permutation_p_raw=tt$p.value,permutation_p=(round(tt$p.value*Bperm)+1)/(Bperm+1))})
conditional_tests<-do.call(rbind,ci_rows);conditional_tests$p_Holm<-p.adjust(conditional_tests$permutation_p,method='holm');conditional_tests$reject_independence<-conditional_tests$p_Holm<.05
show('conditional_tests',conditional_tests,'全行を一つの検定族としてHolm補正。edge行で小さいpは条件付き関連の証拠。implied_independence行で小さいpは構造の説明と食い違う証拠です。大きいpは独立性の証明ではありません。rawはbnlearnの原値。報告用は(超過回数+1)/(B+1)に補正し、最小値は0.0002です。小さい値の細かな順位は主張しません。')

jp<-joint(fitted);key<-function(d)apply(d[,names(dev),drop=FALSE],1,paste,collapse='|')
counts<-tabulate(match(key(evaluation),key(jp)),nbins=nrow(jp));expected<-nrow(evaluation)*jp$prob
Tobs<-sum((counts-expected)^2/expected)
set.seed(1400);simulated<-rmultinom(2000,nrow(evaluation),jp$prob);Tsim<-colSums((simulated-expected)^2/expected)
p_global<-(1+sum(Tsim>=Tobs))/(ncol(simulated)+1)
patterns<-cbind(jp[,names(dev)],observed=counts,expected=expected,standardized_residual=(counts-expected)/sqrt(expected));patterns<-patterns[order(-abs(patterns$standardized_residual)),]
show('pattern_discrepancy',head(patterns,10),'観測数−予測数を予測数の平方根で割った残差。正は過少予測、負は過大予測。絶対値が大きい状態を点検します。32状態を探した後の上位表なので、±2だけで個別の有意性を判定しません。')
show('global_fit_simulation',data.frame(statistic=Tobs,simulation_p=p_global,replicates=ncol(simulated),minimum_expected=min(expected)),'固定した学習済み分布から評価標本と同じ2,000行を2,000回模擬生成。小さいpはこの分布と観測頻度の不一致を示します。大きいpはモデルの正しさを保証しません。学習パラメータの不確実性は含めません。')

set.seed(1500);learning_rows<-list()
for(size in c(150,300,600,1200,nrow(dev)))for(rep in 1:5){ix<-sample.int(nrow(dev),size);dd<-dev[ix,];ff<-fit_model(learn(dd,'HC_BIC'),dd,'Bayes10');learning_rows[[length(learning_rows)+1]]<-data.frame(n_train=size,replicate=rep,t(assess(ff,evaluation)))}
learning_curve<-do.call(rbind,learning_rows);show('learning_curve',learning_curve,'少ないデータで損失や変動が大きいかを点検します。開発標本全件の場合は同じデータなので、順序だけ変えても独立反復ではありません。評価標本は共通・使用済みのため標本数を選ぶ確証的試験ではありません。')
set.seed(1600);scenario_samples<-replicate(200,{dd<-dev[sample.int(nrow(dev),replace=TRUE),];ff<-fit_model(learn(dd,'HC_BIC'),dd,'Bayes10');jj<-joint(ff);c(dry=query(jj,list(WetGrass='0')),wet=query(jj,list(WetGrass='1')))})
scenario_intervals<-data.frame(condition=c('WetGrass=0','WetGrass=1'),estimate=c(query(joint(fitted),list(WetGrass='0')),query(joint(fitted),list(WetGrass='1'))),low=apply(scenario_samples,1,quantile,.025),high=apply(scenario_samples,1,quantile,.975))
show('refitted_scenario_intervals',scenario_intervals,'構造と確率を毎回学習し直した200回のパーセンタイル範囲。固定構造のCPT信用区間とは対象が異なり、構造選択を含むため探索的な安定性範囲として示します。端の分位点は粗く、重要判断では1,000回以上等で安定を確認します。')

p_eval<-pred(fitted,evaluation);y_eval<-as.numeric(evaluation[[target]]=='1');group_rows<-list()
for(v in c('Cloudy','Rain'))for(state in c('0','1')){ix<-evaluation[[v]]==state;group_rows[[length(group_rows)+1]]<-data.frame(group=paste(v,state,sep='='),n=sum(ix),events=sum(y_eval[ix]),mean_predicted=mean(p_eval[ix]),observed=mean(y_eval[ix]),target_NLL=mean(binary_loss(y_eval[ix],p_eval[ix])),Brier=mean((y_eval[ix]-p_eval[ix])^2))}
show('subgroups',do.call(rbind,group_rows),'例示的な条件別診断です。期間・施設・顧客層の検証や公平性監査ではありません。群の発生率が違うため損失だけで扱いの不公平を判断しません。')
drift<-do.call(rbind,lapply(names(dev),function(v){p1<-mean(dev[[v]]=='1');p2<-mean(evaluation[[v]]=='1');t<-prop.test(c(sum(dev[[v]]=='1'),sum(evaluation[[v]]=='1')),c(nrow(dev),nrow(evaluation)));data.frame(variable=v,development=p1,evaluation=p2,difference_pp=100*(p2-p1),p=t$p.value)}));drift$p_Holm<-p.adjust(drift$p,'holm')
show('marginal_distribution_shift',drift,'各状態の割合差を点検する例。多重補正後pが大きくても同分布とは証明できず、周辺分布が似ていても項目間の関係は変化し得ます。時間情報がないためドリフト監視の実証ではありません。')

edge_bridge<-merge(comparison,association,by.x=c('from','to'),by.y=c('x','y'),all.x=TRUE)
# 不一致の並びも含め全10組に対応する
for(i in seq_len(nrow(edge_bridge)))if(is.na(edge_bridge$MI_bits[i])){z<-association[association$x==edge_bridge$to[i]&association$y==edge_bridge$from[i],];if(nrow(z)){edge_bridge$MI_bits[i]<-z$MI_bits;edge_bridge$Cramers_V[i]<-z$Cramers_V;edge_bridge$p_Holm[i]<-z$p_Holm}}
edge_bridge$presentation_label<-ifelse(pmin(edge_bridge$strength_hc,edge_bridge$strength_tabu)>.95,'stable_candidate',ifelse(edge_bridge$algorithm_gap>.20,'method_sensitive','insufficient_stability'))
show('business_edge_evidence',edge_bridge[,c('from','to','strength_hc','strength_tabu','algorithm_gap','MI_bits','Cramers_V','presentation_label')],'stable_candidate:両手法で0.95超という厳しい例示基準。method_sensitive:差0.20超という例示基準。正式な採否や真偽ラベルではありません。p値は別表で全件提示し、都合のよい項目だけを抜き出しません。')
# 矢印を省いた関係図。向きより存在の安定性を伝える。
plot_network<-function(){
 pos<-rbind(Cloudy=c(0,2),Rain=c(-1,1),Sprinkler=c(1,1),WetGrass=c(0,0),Slippery=c(0,-1))
 par(bg='white',mar=c(1,1,3,1));plot(0,0,type='n',xlim=c(-1.7,1.7),ylim=c(-1.4,2.4),axes=FALSE,xlab='',ylab='',main='Stable associations across HC and Tabu')
 for(i in seq_len(nrow(edge_bridge))){r<-edge_bridge[i,];keep<-r$presentation_label=='stable_candidate';if(keep || r$presentation_label=='method_sensitive'){a<-pos[r$from,];b<-pos[r$to,];segments(a[1],a[2],b[1],b[2],col=if(keep)'#1976D2'else'#888888',lwd=if(keep)3 else 1.5,lty=if(keep)1 else 2)}}
 points(pos,pch=21,bg='#EAF3FC',cex=8);text(pos,labels=rownames(pos),cex=.9)
 legend('bottomleft',legend=c('Both strengths > 0.95','Algorithm gap > 0.20'),col=c('#1976D2','#888888'),lty=c(1,2),lwd=c(3,1.5),bty='n',cex=.8)
}
plot_network();png('results/business_network.png',width=1200,height=850,res=140);plot_network();dev.off()
plot_precision<-function(){par(bg='white',mar=c(5,11,3,1));ix<-seq_len(nrow(cpt));plot(cpt$Bayes10,ix,xlim=c(0,1),yaxt='n',ylab='',xlab='P(variable = 1 | parent state)',pch=19,col='#1976D2',main='Conditional probabilities and 95% credible intervals');segments(cpt$low,ix,cpt$high,ix,col='#1976D2');axis(2,at=ix,labels=paste(cpt$variable,cpt$parents,sep=' | '),las=1,cex.axis=.7)}
plot_precision();png('results/business_CPT.png',width=1400,height=900,res=130);plot_precision();dev.off()

n_constraints<-sum(conditional_tests$kind=='implied_independence');n_rejected<-sum(conditional_tests$kind=='implied_independence'&conditional_tests$reject_independence)
coverage<-data.frame(area=c('Input validity','Repeated CV','Nested selection validation','CPT precision and prior sensitivity','Edge stability and conditional evidence','Distribution fit','Learning curve and subgroup diagnosis','Population/time/customer independence','Missingness and measurement reliability','External replication','Practical effect threshold and cost','Expert review and presentation approval'),status=c('executed','executed','executed','executed','executed_exploratory','executed_fixed_model','executed_example','not_available','not_available_in_complete_synthetic_data','not_executed','not_agreed','not_executed'))
show('coverage_matrix',coverage,'未検証を合格扱いにしません。業界共通で必須の一組の検定があるわけではなく、用途とデータ設計によって必要な確認が変わります。')
brief<-paste0('# ビジネス報告用：今回の解釈\n\n',
'## 1. 構造の説明\n\n両手法で出現率95%を超える関係は',sum(edge_bridge$presentation_label=='stable_candidate'),'本。矢印の真偽ではなく、同じデータを取り直したときに残る関係として提示します。\n\n',md_table(edge_bridge[,c('from','to','strength_hc','strength_tabu','MI_bits','presentation_label')]),
'\n\n## 2. パラメータの説明\n\n',md_table(scenario_intervals),
'\n\nP(Slippery=1 | WetGrass=0/1)の観測条件付き確率で、介入効果ではありません。全CPTの最大固定構造信用区間幅は',round(max(cpt$width)*100,2),'ポイント。業務許容幅を合意するまで精度の総合合格とはしません。\n\n',
'## 3. 予測を支える検証\n\n',md_table(nested),
'\n\n候補選択を外側評価から分離したネストCVでも比較しています。独立な実施設での検証ではありません。\n\n',
'## 4. 構造の説明と実績の食い違い\n\nモデルが示す条件付き独立性',n_constraints,'件のうち、探索的Holm補正後0.05で矛盾が検出されたのは',n_rejected,'件。0件であっても正しい構造の証明ではありません。固定モデルの全状態頻度のシミュレーションp値は',format(p_global,digits=3),'。検出力や標本再利用の限界があります。\n\n',
'## 5. 未解決の判断\n\n実母集団の代表性、期間・施設での独立検証、実務上の最小差、測定精度、判断コスト、担当者レビューは未確認です。実データの採用承認を求める資料ではなく、根拠の読み方を共有する教材として提示します。\n\n',md_table(coverage))
writeLines(brief,'BUSINESS_BRIEF.md');IRdisplay::display_markdown(brief)
cat(paste0('\n\n',brief),file='RESULT.md',append=TRUE)
write.csv(data.frame(metric=c('nested_weighted_joint_NLL','nested_baseline_NLL','global_fit_p','independence_statements','independence_rejections','stable_edges'),value=c(weighted.mean(nested$joint_NLL,nested$n),weighted.mean(nested$baseline_joint_NLL,nested$n),p_global,n_constraints,n_rejected,sum(edge_bridge$presentation_label=='stable_candidate'))),'results/business_metrics.csv',row.names=FALSE)
capture.output(sessionInfo(),file='results/sessionInfo.txt')
stopifnot(nrow(nested)==5,all(is.finite(nested$joint_NLL)),all(is.finite(conditional_tests$p_Holm)),all(conditional_tests$p_Holm>=0 & conditional_tests$p_Holm<=1),nrow(learning_curve)==25,ncol(scenario_samples)==200,!anyNA(edge_bridge$MI_bits))
maxgap<-edge_bridge[which.max(edge_bridge$algorithm_gap),]
speaker_examples<-paste0('## 実際の数値を使うプレゼン説明例\n\n',
'### 構造のページ：5本は安定候補、追加の関係は保留\n',
'「本データでは両手法で出現率95%を超える関係が',sum(edge_bridge$presentation_label=='stable_candidate'),'本あります。一方、',maxgap$from,'と',maxgap$to,'はHCで',round(maxgap$strength_hc*100,1),'%、Tabuで',round(maxgap$strength_tabu*100,1),'%です。この関係は単一手法の結果だけでは採用しません。95%は説明用の表示基準であり、真実の確率ではありません。」\n\n',
'### パラメータのページ：条件付き確率は件数と区間を伴って示す\n',
'「芝生が乾いている条件では滑りやすさの推定確率は',round(scenario_intervals$estimate[1]*100,1),'%、濡れている条件では',round(scenario_intervals$estimate[2]*100,1),'%です。構造から再学習した範囲は、それぞれ',round(scenario_intervals$low[1]*100,1),'〜',round(scenario_intervals$high[1]*100,1),'%、',round(scenario_intervals$low[2]*100,1),'〜',round(scenario_intervals$high[2]*100,1),'%でした。これは観測条件別の説明であり、乾かす施策の効果を保証しません。」\n\n',
'### 検証のページ：単純な比較相手を上回るが、実施設への外挿は別問題\n',
'「候補選択を分離した外側評価の平均joint NLLは',round(weighted.mean(nested$joint_NLL,nested$n),3),'、独立モデルは',round(weighted.mean(nested$baseline_joint_NLL,nested$n),3),'でした。小さい方が良い指標で、この標本内では項目間の関係を使う説明が有用でした。ただし利益率や正解率ではなく、実施設での確認はまだです。」\n')
writeLines(speaker_examples,'SPEAKER_EXAMPLES.md');IRdisplay::display_markdown(speaker_examples)
