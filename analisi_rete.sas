/* cas studio_session terminate; */
options casdatalimit=ALL;
cas studio_session sessopts=(caslib=casuser timeout=1800);
caslib _all_ assign;
libname mycas cas caslib="CASUSER";
ods graphics on / width=1500 height=1000;
libname mydata2 "/mnt/storage/sasdata/Allacciamenti";

proc tsne data=mydata.db_clean_linea(where=(commessa ne "NQ/R20231/L01")) ndimensions=2 perplexity=6.5030994 
		learningrate=1895.48865 maxiters=5000;

		/* 	autotune nparallel=40; */
		input costo:  Totale_lunghezza diametro P_:;
	output out=mydata.tsne_out copyvar=commessa;
run;

proc fedsql sessref=mysession;
	create table mydata.db_rete_tsne {options replace=True} as select A.*, 
		B._DIM_1_, B._DIM_2_ from mydata.db_clean_linea as A inner join mydata.tsne_out as 
		B on a.Commessa=B.Commessa;
	quit;

/*
proc hpbin data=mydata.db_rete_tsne numbin=5 bucket;
	id commessa;
	input Totale_lunghezza;
    code file="/home/magatz/My SAS/hpbin_code.sas";
run;
*/
data mydata.db_rete_tsne;
	set mydata.db_rete_tsne;
	length id_diametro $2;
	select;
		when (diametro le 100) id_diametro='A';
		when (diametro ge 150 and diametro le 300) id_diametro='B';
		when (diametro ge 350 and diametro le 650) id_diametro='C';
		when (diametro ge 700 and diametro le 1050) id_diametro='D';
		when (diametro ge 1100 ) id_diametro='E';
		otherwise id_diametro='X' ;
	end;
/* 	%include "/home/magatz/My SAS/hpbin_code.sas" */
	if totale_lunghezza le 2.5 them id_lunghezza = '0';
	else if totale_lunghezza gt 2.5 and totale_lunghezza le 7.5 then id_lunghezza = '1';
	else if totale_lunghezza gt 7.5 then id_lunghezza = '2';
   if totale_lunghezza in (384 389 ) then totale_lunghezza=400;
run;


proc means data=mydata.db_rete_tsne nway missing N MEAN;
 class id_diametro;
 var diametro;
run;

proc means data=mydata.db_rete_tsne nway missing N MEAN min max range;
 class id_lunghezza;
 var totale_lunghezza;
run;

	/* calcolo clusters  */
proc kclus data=mydata.db_clean_linea (where=(commessa ne "NQ/R20231/L01")) distance=euclidean 
		distancenom=relativefreq standardize=std stopcriterion=cluster_change 
		seed=220870 distancenom=relativefreq noc=abc(minclusters=2 criterion=ALL) 
		maxclusters=6 outstat(outiter)=mydata.cluster_stats;
	input Costo: Totale_lunghezza / level=interval;
	input diametro /*P_:*/ / level=nominal;
	score out=mydata.db_rete_cluster copyvars=(commessa);
run;

proc fedsql sessref=mysession;
	create table mydata.db_rete_cluster_tsne {options replace=True} as select A.*, 
		B._CLUSTER_ID_ from mydata.db_rete_tsne as A inner join 
		mydata.db_rete_cluster as B on a.Commessa=B.Commessa;
	quit;

proc means data=mydata.db_rete_cluster_tsne nway missing ;
 class _CLUSTER_ID_;
 var totale_lunghezza;
run;

proc means data=mydata.db_rete_cluster_tsne nway mean min max range;
	class _CLUSTER_ID_;
	var Totale_lunghezza;
run;

proc sgplot data=mydata.db_rete_cluster_tsne;
	scatter x=_dim_1_ y=_dim_2_ /group=_CLUSTER_ID_;
run;

proc partition data=mydata.db_rete_cluster_tsne partind samppct=40 
		seed=17112003;
	by _CLUSTER_ID_;
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
/* 		by id_diametro; */
		partition role=_PartInd_(train='0' validate='1');
		class /*_CLUSTER_ID_*/ diametro P_:;
		model Costo_pulito=/*_CLUSTER_ID_ |*/  totale_lunghezza | diametro | P_ambiente | P_collina | P_Montagna |P_Non_ambiente | P_Non_roccia | P_Pianura | P_Roccia   @2 
			/ selection=&method(choose=validate /*ADJRSQ*/ ) stop=validate /* ADJRSQ*/;

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
/*  		by id_diametro; */
		styleattrs datacolors=(green purple orangered);
		scatter x=totale_lunghezza y=predicted ;
		scatter x=totale_lunghezza y=costo_pulito;

		reg x=totale_lunghezza y=predicted / lineattrs=(color=red) ; 
	run;

%MEND;
/*
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

data mydata.pippo;
 set mydata9.pippo;
run;
*/
proc adaptivereg data=mydata.db_rete_input_1 seed=22011970 plots=all nloptions(technique=NEWRAP) details=(bases  BWDSUMMARY) outdesign=mydata.design ;
	class _CLUSTER_ID_ diametro P_:  ;
	partition role=_PartInd_(train='0' validate='1');
	model Costo_pulito =
		 	_CLUSTER_ID_ | 
			totale_lunghezza | 
			diametro |
			P_Montagna | 
			P_Roccia | 
			P_Collina | 
			P_Ambiente / fast /*cvmethod=index(_CLUSTER_ID_)*/   varpenalty=0.05 maxbasis=100   ;
	output out=mycas.adaptivereg_out  	p=predicted r=residual;
  	ods output
		bases=mydata.bases 
		BWDParams=mydata.parms 
		classinfo=mydata.class
		FitStatistics=mydata.fit_stat;
	 score data=mydata.score_SIM out=mydata.scored;
run;


proc sgplot data=mycas.adaptivereg_out;
	by _Partind_;
	where totale_lunghezza le 15;
	scatter x=totale_lunghezza y=Costo_pulito;
	scatter x=totale_lunghezza y=predicted;

	/*  ellipse x=totale_lunghezza y=predicted; */
run;

proc sgplot data=mydata.scored(where=(pred gt 0));
  by diametro;	
  scatter x=P_Montagna y=pred;
run;

data mydata.scored_2;
 set mydata.scored;
  c_medio  = pred / totale_lunghezza;
run;

proc means data=  mydata.scored_2(where=(pred gt 0)) nway mean;
 class diametro P_:;
var c_medio;
run;




