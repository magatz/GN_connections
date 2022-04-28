options casdatalimit=ALL;
cas mysession sessopts=(caslib=casuser timeout=1800);
caslib _all_ assign;

*cas mysession terminate;

libname COST '/home/magatz/My Data';

libname mycas cas caslib="CASUSER";

data mycas.allac;
	set cost.db_allac(drop=societa descrizione_societa macro_progetto);

	if codice_metanodotto in ('#' 'N/A') then
		call missing(codice_metanodotto);

	/* extreme value */
	if index(descrizione_commessa, 'Storage') ne 0 then
		delete;

	if index(descrizione_commessa, 'All.to Bioman - Maniago (PN) - Linea') ne 0 
		then
			delete;
run;



data mycas.input_ds_1 (rename=(Costruzione_0002=costo_costruzione Data_E_E__Commessa=data_commessa Totale_Lunghezza__m_=lunghezza_condotte Diametro_n__turbo_Pr=diametro));
	set cost.db_allac;
	keep Data_E_E__Commessa Tipologia Definizione_progetto Descrizione_progetto Regione_Prevalente Costo_totale Diametro_n__turbo_Pr
		 Costo_costruzione_tubazione Costo_tubazione Costruzione_0002 Totale_Lunghezza__m_ flag_condotte ;

	if index( descrizione_commessa, 'Storage') ne 0 then
		delete;

	if index( descrizione_commessa, 'All.to Bioman - Maniago (PN) - Linea') ne 0 then
		delete;
	select ;
		when ( Totale_Lunghezza__m_ le 500) flag_condotte=1;
		when ( Totale_Lunghezza__m_ gt 500 and Totale_Lunghezza__m_ le 1000) flag_condotte=2;
		when ( Totale_Lunghezza__m_ gt 1000) flag_condotte=3;
		otherwise;
	end;
/*
	select ;
		when ( index(upcase(TIPOLOGIA),'BIOMETANO') ne 0) cod_tipologia=1;
		when ( index(upcase(TIPOLOGIA),'CNG') ne 0) cod_tipologia=2;
		when (  index(upcase(TIPOLOGIA),'INDUSTRIALE') ne 0) cod_tipologia=3;
		otherwise;
	end;
*/
run;

proc hpbin data=mycas.input_ds_1 numbin=10 bucket output=mycas.input_ds_1_bin;
id definizione_progetto;
 input lunghezza_condotte;
ods output Mapping = mycas.bin_mapping; 
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
	output out=mycas.reg_costi(drop= _TYPE_ rename=(_FREQ_=frequenza)) mean=;
run;

/* aggiungo la frequenza regionale */
proc fedsql sessref=mysession;
 create table casuser.input_ds_3 as
  select a.*, b.frequenza from casuser.input_ds_2 as a inner join casuser.reg_costi as B on A.regione_prevalente = b.regione_prevalente;
quit; 

/* calcolo clusters  */
proc kclus data=MYCAS.input_ds_3 distance=euclidean distancenom=binary noc=abc(minclusters=2) maxclusters=6;
	input Costo_totale lunghezza_condotte costo_costruzione Costo_tubazione diametro Costo_costruzione_tubazione diametro frequenza / level=interval;
	input tipologia  bin_lunghezza_condotte    / level=nominal;
	score out=mycas.ds_cluster copyvars=(definizione_progetto);
run;

/* adding clusters to inputds  */
data mycas.input_ds_4;
 merge mycas.input_ds_3 mycas.ds_cluster(keep=_CLUSTER_ID_ _DISTANCE_ definizione_progetto);
by definizione_progetto;
run;

/* verifica cluster naturali  */
proc tsne data=mycas.input_ds_4 nDimensions=2;
	autotune maxtime=3000 popsize=20 nparallel=18 EVALHISTORY=log ;
	input costo_: lunghezza_condotte frequenza diametro ;
	output out=mycas.tsne_out copyvars=(Definizione_progetto );
run;

/* adding tsne_dim to inputds  */
data mycas.input_ds_5;
 merge mycas.input_ds_4 mycas.tsne_out(keep= definizione_progetto _DIM_1_ _DIM_2_);
by definizione_progetto;
run;


/* plot natural clusters  */
proc sgplot data=mycas.input_ds_5;
 scatter x=_dim_1_ y= _dim_2_ / group=_CLUSTER_ID_;
run;

proc partition data=mycas.input_ds_5 partind samppct=30 seed=17112003;
	by  tipologia ;
	output out=mycas.input_ds_6;
run;


proc regselect data=mycas.input_ds_6;
	partition role=_PartInd_(train='0'  validate='1'); 
	class _CLUSTER_ID_ flag_condotte BIN_lunghezza_condotte diametro;
	model Costo_totale=_CLUSTER_ID_ | flag_condotte | BIN_lunghezza_condotte | lunghezza_condotte | diametro @3 /;
	selection method=FORWARD;
	output out=mycas.regselect_out p=predicted /*lcl=lcl ucl=ucl lclm=lclm uclm=uclm*/ r=residual copyvars=(definizione_progetto costo_totale);
	ods output FitStatistics =cost.regselect_fit;
run;

ods graphics on / width=1200 height=800;
proc glmselect data=mycas.input_ds_6 plots(stepAxis=number)=(criterionPanel ASEPlot);
	partition role=_PartInd_(train='0'  validate='1'); 
	class _CLUSTER_ID_  BIN_lunghezza_condotte diametro;
	model Costo_totale=_CLUSTER_ID_ |  BIN_lunghezza_condotte | lunghezza_condotte | diametro @2 /
			 selection=elasticnet(choose = validate);
	
	output out=mycas.regselect_out p=predicted /*lcl=lcl ucl=ucl lclm=lclm uclm=uclm*/ r=residual ;
	ods output FitStatistics =cost.regselect_fit;
run;



data mycas.mape (keep=definizione_progetto costo_totale  predicted  ape _partind_);
	set mycas.regselect_out;
	ape=abs(costo_totale - predicted) / costo_totale;
	format ape percent7.2;
run;

proc means data=mycas.mape nway mean;
/*  by _partind_; */
 var ape;
run;
 


data cost.regselect_out;
set mycas.regselect_out;
run;
proc sgplot data=mycas.regselect_out;
/*  by _cluster_id_; */
 scatter x=lunghezza_condotte y= predicted;
scatter x=lunghezza_condotte y= costo_totale;
run;



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
proc sgplot data=MYCAS.ALLAC;
/* where  descrizione_progetto ne "All.to Bioman S.p.a Maniago (PN)"; */
 scatter x=Totale_Lunghezza__m_ y=costo_totale;
 ellipse x=Totale_Lunghezza__m_ y=costo_totale;
run;



  






proc univariate data=MYCAS.BIOMETANO   ;
	/* extreme value */
    where  descrizione_progetto ne "All.to Bioman S.p.a Maniago (PN)";
	id descrizione_progetto;
    var Costo_totale Costo_tubazione;
	histogram Costo_totale  /  exp(theta=25)  ;
    qqplot Costo_totale  / exp(theta=25);
 	
	histogram Costo_tubazione / sb(theta=10 sigma=1350)     ;
/*     qqplot Costo_tubazione  / gumbel; */
run;

proc univariate data=MYCAS.BIOMETANO   ;
	/* extreme value */
    where  descrizione_progetto ne "All.to Bioman S.p.a Maniago (PN)";
	id descrizione_progetto;
    var Costruzione_0002;
	histogram Costruzione_0002  /  exp(theta=25)  ;
    qqplot Costruzione_0002  / exp(theta=25);
 
run;


proc univariate data=MYCAS.CNG   ;
	/* extreme value */
    where  costo_totale lt 1300;
	id descrizione_progetto;
    var Costo_totale Costo_tubazione;
	histogram Costo_totale  / gumbel  weibull(theta=20)  ;
    qqplot Costo_totale  / gumbel ;
 	qqplot Costo_totale  / weibull (theta=20 C=1.698782);
	histogram Costo_tubazione / gumbel  weibull(theta=10)        ;
    qqplot Costo_tubazione  / gumbel;
    
run;



proc univariate data=MYCAS.INDUSTRIALE   ;
	/* extreme value */
/*     where  costo_totale lt 1300; */
	id descrizione_progetto;
    var Costo_totale Costo_tubazione;
	histogram Costo_totale  / exp  ;
/*     qqplot Costo_totale  / gumbel ; */
 	qqplot Costo_totale  / weibull (theta=20 C=1.698782);
	histogram Costo_tubazione / exp ;
/*     qqplot Costo_tubazione  / gumbel; */
    
run;



proc univariate data=MYCAS.INDUSTRIALE   ;
	/* extreme value */
/*     where  costo_totale lt 1300; */
	id descrizione_progetto;
    var Costo_totale Costo_tubazione;
	histogram Costo_totale  / exp  ;
/*     qqplot Costo_totale  / gumbel ; */
 	qqplot Costo_totale  / weibull (theta=20 C=1.698782);
	histogram Costo_tubazione / exp ;
/*     qqplot Costo_tubazione  / gumbel; */
    
run;