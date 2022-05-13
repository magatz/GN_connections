/* cas mysession terminate; */
options casdatalimit=ALL;
cas mysession sessopts=(caslib=casuser timeout=1800);
caslib _all_ assign;
libname mycas cas caslib="CASUSER";

proc tsne data=mydata.db_clean_linea ndimensions=2 perplexity=6.5030994 
		learningrate=1895.48865 maxiters=5000;

		/* 	autotune nparallel=40; */
		input costo:  Totale_lunghezza diametro P_:;
	output out=mydata.tsne_out copyvar=commessa;
run;

proc fedsql sessref=mysession;
	create table mydata.db_rete_tsne {options replace=True} as select A.*, 
		B._DIM_1_, B._DIM_2_ from mydata.db_allac as A inner join mydata.tsne_out as 
		B on a.Commessa=B.Commessa;
	quit;
	ods graphics on / width=1000 height=1000;

	/* calcolo clusters  */
proc kclus data=mydata.db_clean_linea distance=euclidean 
		distancenom=relativefreq standardize=std stopcriterion=cluster_change 
		seed=220870 distancenom=relativefreq noc=abc(minclusters=2 criterion=ALL) 
		maxclusters=6 outstat(outiter)=mydata.cluster_stats;
	input Costo: Totale_lunghezza / level=interval;
	input diametro P_: / level=nominal;
	score out=mydata.db_rete_cluster copyvars=(commessa);
run;

proc fedsql sessref=mysession;
	create table mydata.db_rete_cluster_tsne {options replace=True} as select A.*, 
		B._CLUSTER_ID_ from mydata.db_rete_tsne as A inner join 
		mydata.db_rete_cluster as B on a.Commessa=B.Commessa;
	quit;

proc means data=mydata.db_rete_cluster_tsne nway mean min max range;
	class _CLUSTER_ID_;
	var Totale_lunghezza;
run;

proc sgplot data=mydata.db_rete_cluster_tsne;
	scatter x=_dim_1_ y=_dim_2_ /group=_CLUSTER_ID_;
run;

proc partition data=mydata.db_rete_cluster_tsne partind samppct=30 
		seed=17112003;
	by _cluster_id_;
	output out=mydata.db_rete_input_1;
run;

%MACRO RUN_MODEL(method);
	data tmp;
		name='/home/magatz/My SAS/score_code_rete_'|| "&method" ||'.sas';
		call symputx('namecode', name);
	run;

	proc glmselect data=mydata.db_rete_input_1 plots(stepAxis=number)=(ASEPlot) 
			outdesign=mycas.design;
		code file="&namecode";
		partition role=_PartInd_(train='0' validate='1');
		class _CLUSTER_ID_ diametro PE_:;
		model Costo_totale=_CLUSTER_ID_ |  totale_lunghezza | diametro | PE_ambiente | PE_collina | PE_Montagna |PE_Non_ambiente | PE_Non_roccia | PE_Pianura | PE_Roccia   @2 
			/ selection=&method(choose=validate) stop=validate;

		/* 		modelaverage refit   ; */
		output out=mycas.regselect_out 
			p=predicted /*lcl=lcl ucl=ucl lclm=lclm uclm=uclm*/
			r=residual;
		ods output FitStatistics=mycas.regselect_fit;
		ods output ParameterEstimates=mycas.parms;
	run;

	data mycas.output_&method;
		length method $15;
		set mycas.regselect_out;
		method="&method";
	run;

	data mycas.fit_&method;
		length method $15;
		set mycas.regselect_fit;
		method="&method";
	run;

	data mycas.parms_&method;
		length method $15;
		set mycas.parms;
		method="&method";
	run;

	title "Selection method: " "&method";

	proc sgplot data=mycas.regselect_out;
		styleattrs datacolors=(green purple orangered);
		scatter x=totale_lunghezza y=predicted;
		scatter x=totale_lunghezza y=costo_totale;

		/* 		reg x=lunghezza_condotte y=predicted / lineattrs=(color=red) group=_cluster_id_; */
	run;

%MEND;

%RUN_MODEL(stepwise);
%RUN_MODEL(forward);
%RUN_MODEL(backward);
%RUN_MODEL(lar);
%RUN_MODEL(lasso);
%RUN_MODEL(elasticnet);
%RUN_MODEL(grouplasso);

data mycas.sintesi;
	length method $15;
	set mycas.fit_forward mycas.fit_backward mycas.fit_stepwise mycas.fit_lar 
		mycas.fit_lasso mycas.fit_elasticnet mycas.fit_grouplasso;
	where label1 in ("R-Square" "ASE (Train)" "ASE (Validate)");
	format nvalue1 commax14.4;
run;

proc sort data=mycas.sintesi(drop=cValue1) out=mydata.sintesi;
	by label1 nvalue1;
run;

proc print data=mydata.sintesi;
run;

proc adaptivereg data=mydata.db_rete_input_1 seed=22011970 plots=all nloptions(tecnique=CONGRA) ;
	class _CLUSTER_ID_ diametro PE_Roccia;
	model Costo_totale=_CLUSTER_ID_ |  totale_lunghezza | diametro /*| PE_ambiente | PE_collina | PE_Montagna |PE_Non_ambiente | PE_Non_roccia | PE_Pianura */ | PE_Roccia  ;
	output out=mycas.adaptivereg_out 
		p=predicted /*lcl=lcl ucl=ucl lclm=lclm uclm=uclm*/
		r=residual;
run;