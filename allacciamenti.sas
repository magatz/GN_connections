options casdatalimit=ALL;
cas mysession sessopts=(caslib=casuser timeout=1800);
caslib _all_ assign;
*cas mysession terminate;
libname COST '/home/magatz/My Data';
libname mycas cas caslib="CASUSER";

ods graphics on /height=1000 width=2000 imagemap=on;

data mycas.allac;
	set cost.db_allac(drop=societa descrizione_societa macro_progetto);

	if codice_metanodotto in ('#' 'N/A') then
		call missing(codice_metanodotto);
	
	if Definizione_progetto  in ("NR/15411" "NR/14187"  "NR/17467" ) then delete;

run;

proc sgplot data=mycas.allac;
	scatter x=Totale_Lunghezza__m_ y=costo_totale /  tip=(Descrizione_progetto Definizione_progetto);
	ellipse x=Totale_Lunghezza__m_ y=costo_totale /type=predicted;
run;

data mycas.input_ds_1 (rename=(Costruzione_0002=costo_costruzione 
		Data_E_E__Commessa=data_commessa Totale_Lunghezza__m_=lunghezza_condotte 
		Diametro_n__turbo_Pr=diametro));
	set mycas.allac;
/*
	 where definizione_progetto not in ("NR/12243" "NR/05386" "NR/18317" "NR/18373" 
		"NR/18272" "NR/14199" "NR/17309" "NR/05397" "NR/14342" "NR/18432" "NR/16255" 
		"NR/05402" "NR/05399"  );
*/
	keep Data_E_E__Commessa Tipologia Definizione_progetto Descrizione_progetto 
		Regione_Prevalente Costo_totale Diametro_n__turbo_Pr 
		Costo_costruzione_tubazione Costo_tubazione Costruzione_0002 
		Totale_Lunghezza__m_ flag_condotte;

	select;
		when (Totale_Lunghezza__m_ le 500) flag_condotte=1;
		when (Totale_Lunghezza__m_ gt 500 and Totale_Lunghezza__m_ le 1000) 
			flag_condotte=2;
		when (Totale_Lunghezza__m_ gt 1000) flag_condotte=3;
		otherwise ;
	end;
run;

proc sgplot data=mycas.input_ds_1;
	scatter x=lunghezza_condotte y=costo_totale /  tip=(Descrizione_progetto Definizione_progetto);
	ellipse x=lunghezza_condotte y=costo_totale / ;
run;


proc hpbin data=mycas.input_ds_1 numbin=10 bucket output=mycas.input_ds_1_bin;
	id definizione_progetto;
	input lunghezza_condotte;
	ods output Mapping=mycas.bin_mapping;
run;

/* adding bins to inputds  */
data mycas.input_ds_2;
	merge mycas.input_ds_1 mycas.input_ds_1_bin;
	by definizione_progetto;
run;

/* calcolo frequenza regionale  */
proc means data=mycas.input_ds_2 nway missing noprint;
	class Regione_Prevalente;
	var Costo_: lunghezza_condotte;
	output out=mycas.reg_costi(drop=_TYPE_ rename=(_FREQ_=frequenza)) mean=;
run;

/* aggiungo la frequenza regionale */
proc fedsql sessref=mysession;
	create table casuser.input_ds_3{options replace=True} as select a.*, b.frequenza from 
		casuser.input_ds_2 as a inner join casuser.reg_costi as B on 
		A.regione_prevalente=b.regione_prevalente;
	quit;

	/* calcolo clusters  */
proc kclus data=MYCAS.input_ds_3 distance=euclidean distancenom=binary 
		noc=abc(minclusters=2) maxclusters=6;
	input Costo_totale lunghezza_condotte costo_costruzione Costo_tubazione 
		diametro Costo_costruzione_tubazione diametro frequenza / level=interval;
	input tipologia bin_lunghezza_condotte / level=nominal;
	score out=mycas.ds_cluster copyvars=(definizione_progetto);
run;

/* adding clusters to inputds  */
data mycas.input_ds_4;
	merge mycas.input_ds_3 mycas.ds_cluster(keep=_CLUSTER_ID_ _DISTANCE_ 
		definizione_progetto);
	by definizione_progetto;
run;

/* show cluster by lunghezza  */
ods graphics on / width=1200 height=800;
proc sgplot data=mycas.input_ds_4;
by _cluster_id_;
 scatter x=lunghezza_condotte y=costo_totale;
run;

/* show cluster data  */
proc means data=mycas.input_ds_4 nway;
 class _cluster_id_;
var lunghezza_condotte diametro ;
output out=cost.rules;
run; 


/* verifica cluster naturali  */
proc tsne data=mycas.input_ds_4 nDimensions=2;
	autotune maxtime=3000 popsize=20 nparallel=18 EVALHISTORY=log;
	input costo_: lunghezza_condotte frequenza diametro;
	output out=mycas.tsne_out copyvars=(Definizione_progetto);
run;

/* adding tsne_dim to inputds  */
data mycas.input_ds_5;
	merge mycas.input_ds_4 mycas.tsne_out(keep=definizione_progetto _DIM_1_ 
		_DIM_2_);
	by definizione_progetto;
run;

data cost.input_ds_5;
 set mycas.input_ds_5;
run;

/* plot natural clusters  */
proc sgplot data=mycas.input_ds_5;
	scatter x=_dim_1_ y=_dim_2_ / group=_CLUSTER_ID_;
run;

/* create partition fo GCV */
proc partition data=mycas.input_ds_5 partind samppct=30 seed=220870;
	by _cluster_id_;
	output out=mycas.input_ds_6;
run;

/*
proc regselect data=mycas.input_ds_6;

class _CLUSTER_ID_ flag_condotte BIN_lunghezza_condotte diametro;
model Costo_totale=_CLUSTER_ID_ | flag_condotte | BIN_lunghezza_condotte | lunghezza_condotte | diametro @3 /;
selection method=stepwise;
output out=mycas.regselect_out p=predicted  r=residual copyvars=(definizione_progetto costo_totale);
ods output FitStatistics =cost.regselect_fit;
run;
*/
%MACRO RUN_MODEL(method);
	

	proc glmselect data=mycas.input_ds_6 plots(stepAxis=number)=(criterionPanel 
			ASEPlot) outdesign=mycas.design;
/* 		where _cluster_id_ ne 3; */
		partition role=_PartInd_(train='0' validate='1');
		class _CLUSTER_ID_ BIN_lunghezza_condotte diametro;
		model Costo_totale =_CLUSTER_ID_ |  BIN_lunghezza_condotte | lunghezza_condotte | diametro @2 
			/ selection=&method(choose=validate);
/* 		modelaverage details; */
		output out=mycas.regselect_out 
			p=predicted /*lcl=lcl ucl=ucl lclm=lclm uclm=uclm*/
			r=residual;
		ods output FitStatistics=cost.regselect_fit;
        ods output ParameterEstimates=cost.parms;
	run;

	data mycas.output_&method;
		length method $15;
		set mycas.regselect_out;
		method="&method";
	run;

	data mycas.fit_&method;
		length method $15;
		set cost.regselect_fit;
		method="&method";
	run;

	title "Selection method: " "&method";
	proc sgplot data=mycas.regselect_out;
		
		scatter x=lunghezza_condotte y=predicted;
		scatter x=lunghezza_condotte y=costo_totale;
	run;

%MEND;

%RUN_MODEL(forward);
%RUN_MODEL(backward);
%RUN_MODEL(stepwise);
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

proc sort data=mycas.sintesi(drop=cValue1) out=cost.sintesi;
	by label1 nvalue1;
run;

proc print data=cost.sintesi;
run;

/*
data mycas.mape (keep=definizione_progetto costo_totale predicted ape 
		_partind_ _cluster_id_);
	set mycas.regselect_out;
	ape=abs(costo_totale - predicted) / costo_totale;
	format ape percent7.2;
run;

proc means data=mycas.mape nway mean;
	 by _cluster_id_ _partind_;
	var ape;
run;
data cost.regselect_out;
	set mycas.regselect_out;
run;
*/

/*
data mycas.biometano mycas.cng mycas.industriale;
	set mycas.allac;

	if Index(tipologia, 'Biometano') ne 0 then
		output mycas.biometano;
	else if Index(tipologia, 'CNG') ne 0 then
		output mycas.cng;
	else if Index(tipologia, 'Industriale') ne 0 then
		output mycas.industriale;
run;

ods graphics on / height=1000 width=1800;


proc univariate data=MYCAS.BIOMETANO;

	where descrizione_progetto ne "All.to Bioman S.p.a Maniago (PN)";
	id descrizione_progetto;
	var Costo_totale Costo_tubazione;
	histogram Costo_totale / exp(theta=25);
	qqplot Costo_totale / exp(theta=25);
	histogram Costo_tubazione / sb(theta=10 sigma=1350);
run;

proc univariate data=MYCAS.BIOMETANO;
	where descrizione_progetto ne "All.to Bioman S.p.a Maniago (PN)";
	id descrizione_progetto;
	var Costruzione_0002;
	histogram Costruzione_0002 / exp(theta=25);
	qqplot Costruzione_0002 / exp(theta=25);
run;

proc univariate data=MYCAS.CNG;
	where costo_totale lt 1300;
	id descrizione_progetto;
	var Costo_totale Costo_tubazione;
	histogram Costo_totale / gumbel weibull(theta=20);
	qqplot Costo_totale / gumbel;
	qqplot Costo_totale / weibull (theta=20 C=1.698782);
	histogram Costo_tubazione / gumbel weibull(theta=10);
	qqplot Costo_tubazione / gumbel;
run;

proc univariate data=MYCAS.INDUSTRIALE;
	id descrizione_progetto;
	var Costo_totale Costo_tubazione;
	histogram Costo_totale / exp;
	qqplot Costo_totale / weibull (theta=20 C=1.698782);
	histogram Costo_tubazione / exp;
run;

proc univariate data=MYCAS.INDUSTRIALE;
	id descrizione_progetto;
	var Costo_totale Costo_tubazione;
	histogram Costo_totale / exp;
	qqplot Costo_totale / weibull (theta=20 C=1.698782);
	histogram Costo_tubazione / exp;
run;

*/