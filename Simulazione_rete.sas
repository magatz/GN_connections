libname mydata2 '/home/magatz/My Data';
ods graphics on / height=1500 width=1500;

proc corr data=mydata2.db_clean_linea plots(maxpoints=100000)=matrix(hist nvar=ALL);
var Totale_Lunghezza diametro P_Montagna P_Collina P_Pianura P_Roccia P_Ambiente;
run;

/*Some correlation between lunghezza and diametro 37% */
/*while lunghezza and diametro are not correlated with Orografic, litologic, on anthropic info*/
/* The simulation will be in two sections: */
/* One for lunghezza/diametro */
/* The second for Orografic, litologic, on anthropic */
/* then matched */

/*
proc iml;
	call randseed(1);
	N = 100;
	A = j(N,4);
	y = j(N,1);
	distrib = {"Normal" "Lognormal" "Expo" "Uniform"};

	do i = 1 to ncol(distrib);
		call randgen(y, distrib[i]);
		A[,i] = y;
	end;


	create Mydata from A;
	append from A;
	close Mydata;
run;
*/

/*Per la lunghezza*/
proc iml;
	call randseed(1);
	N = 1000;
	A = j(N,2);
	y = j(N,1);
	distrib = {"Gamma" };

	do i = 1 to ncol(distrib);
		call randgen(y, distrib[i], 0.408954, 4.394479);
		A[,i] = round(y,.01);
	end;

	myvars= "totale_lunghezza";
	create lunghezza from A[colname=myvars];
	append from A;
	close lunghezza;
quit;

ods graphics on / height=1000 width=1000;
/* controllo distribuzione */
proc univariate data=lunghezza;
 var totale_lunghezza;
 hist totale_lunghezza / gamma (theta=-0.1);
 run;


data diametro2;
	set mydata2.diametro(where=(not missing(diametro)));
	class_name = put(diametro, 4.);
	percent_new= percent /100;
run;

proc sql;
 select percent_new into:P_d separated by " " from diametro2;
 quit;

/*Per il diametro*/
data diametri(keep=diam_mapped);
	call streaminit(220870);
	array p[20] _temporary_ 
		(&P_d
		);

	do i =1 to 100000;
		diam_mapped = rand("Table", of p[*]);
		output;
	end;
run;

proc sort data=diametri;
	by diam_mapped;
run;

proc freq data=work.diametri;
	table diam_mapped / nocum out=freq_diam;
run;

data diam_reali;
	input diam_real diam_mapped;
	datalines;
80 1
100 2
150 3
200 4
250 5
300 6 
384 7
389 8
400 9
450 10
500 11
550 12
600 13
650 14
750 15
850 16
900 17
1050 18
1200 19
1400 20 
;
run;

data diametri_remap(keep=diam_real);
	merge diam_reali (in=uno) diametri(in=due);
	by diam_mapped;
run;

proc surveyselect data=diametri_remap samprate=.01 out=diametri_sampled seed=220870;
 strata diam_real;
run;


proc freq data=work.diametri_sampled;
	table diam_real / nocum out=freq_diam;
run;

/* Fine diametro*/
/*###########################################################################################################################*/


/*COPULA Simulation for Lunghezza and diametro in joint distribution*/
Title "Original corelation";
proc corr data=mydata2.db_clean_linea_p spearman plots=(matrix(histogram)) nosimple noprob;
	var Totale_Lunghezza diametro;
run;

Title "Copula";
proc copula data=mydata2.db_clean_linea_p;
	var Totale_Lunghezza diametro;
	fit normal;
	simulate / seed=1234 ndraws=10000 marginals=empirical outuniform=UnifData out=outdata;
run;

Title "Simulated corelation before discretization";
proc corr data=outdata spearman plots=(matrix(histogram))  nosimple noprob;
	var Totale_Lunghezza diametro;
run;

data outdata_redux;
	set outdata;
	select;
		when (diametro le 80) class_diametro=80;
		when (diametro gt 80 and diametro le 100)  class_diametro=100;
		when (diametro gt 100 and diametro le 150)  class_diametro=150;
		when (diametro gt 150 and diametro le 200)  class_diametro=200;
		when (diametro gt 200 and diametro le 250)  class_diametro=250;
		when (diametro gt 250 and diametro le 300)  class_diametro=300;
		when (diametro gt 300 and diametro le 400)  class_diametro=400;
		when (diametro gt 400 and diametro le 450)  class_diametro=450;
		when (diametro gt 450 and diametro le 500)  class_diametro=500;
		when (diametro gt 500 and diametro le 600)  class_diametro=600;
		when (diametro gt 600 and diametro le 650)  class_diametro=650;
		when (diametro gt 650 and diametro le 750)  class_diametro=750;
		when (diametro gt 750 and diametro le 850)  class_diametro=850;
		when (diametro gt 850 and diametro le 900)  class_diametro=900;
		when (diametro gt 900 and diametro le 1050)  class_diametro=1050;
		when (diametro gt 1050 and diametro le 1200)  class_diametro=1200;
		when (diametro gt 1200)  class_diametro=1400;
		otherwise;
	end;
run;

Title "Simulated corelation after discretization";
proc corr data=outdata_redux spearman plots=(matrix(histogram))  nosimple noprob;
	var Totale_Lunghezza class_diametro;
run;

proc univariate data=outdata_redux;
	var Totale_Lunghezza class_diametro;
	histogram Totale_Lunghezza class_diametro;
run;

proc surveyselect data=outdata_redux n=515 method=srs out=outdata_redux_sample;
run;

data mydata2.COPULA_DATA (drop=diametro rename=(class_diametro=diametro));
 set outdata_redux_sample;
 run;

/*NOT GOOOD AT ALL.. TOO MANY DISCRETE VARS ... MESSEDD UP correlation matrix*/
/*COPULA Simulation for collina, montagna, pianura, roccia e ambiente in joint distribution*/
Title "Original corelation";
proc corr data=mydata2.db_clean_linea_p spearman plots=(matrix(histogram)) nosimple noprob;
	var P_Pianura P_Collina P_Montagna P_Roccia P_Ambiente;
run;

Title "Copula";
proc copula data=mydata2.db_clean_linea_p;
	var P_Pianura P_Collina P_Montagna P_Roccia P_Ambiente;
	fit GUMBEL;
	simulate / seed=1234 ndraws=10000 marginals=empirical outuniform=UnifData out=outdata2;
run;

Title "Simulated corelation";
proc corr data=outdata2 spearman plots=(matrix(histogram)) nosimple noprob;
	var P_Pianura P_Collina P_Montagna P_Roccia P_Ambiente ;
run;

/*alternate way to simulate ordinals (no copula) Mean Mapping Method*/

/* Probability Mass function for ordinals*/
%MACRO PMF(var);

	proc freq data=mydata2.db_clean_linea;
		tables &var / outpct out=FREQ_&var(rename=(&var=level Percent=PCT_&var) drop=count);
	run;

%MEND;

%PMF(P_collina);
%PMF(P_Pianura);
%PMF(P_Montagna);
%PMF(P_Roccia);
%PMF(P_Ambiente);

DATA WORK.PMF;
    LENGTH
        PCT_P_Montagna     8
        PCT_P_Pianura      8
        PCT_P_collina      8
        PCT_P_Roccia       8
        PCT_P_Ambiente     8 ;
    FORMAT
        PCT_P_Montagna   BEST11.
        PCT_P_Pianura    BEST11.
        PCT_P_collina    BEST11.
        PCT_P_Roccia     BEST11.
        PCT_P_Ambiente   BEST11. ;
    INFORMAT
        PCT_P_Montagna   BEST11.
        PCT_P_Pianura    BEST11.
        PCT_P_collina    BEST11.
        PCT_P_Roccia     BEST11.
        PCT_P_Ambiente   BEST11. ;
    INFILE '/mnt/storage/sasdata/Allacciamenti/PMF.csv'
        LRECL=59
        ENCODING="UTF-8"
        TERMSTR=CRLF
        DLM=';'
        MISSOVER
        DSD firstobs=2 ;
    INPUT
        PCT_P_Montagna   : ?? COMMAX11.
        PCT_P_Pianura    : ?? COMMAX11.
        PCT_P_collina    : ?? COMMAX11.
        PCT_P_Roccia     : ?? COMMAX11.
        PCT_P_Ambiente   : ?? COMMAX11. ;
RUN;



%include '/home/magatz/My SAS/Simulating_data_with_SAS/65378_example/RandMVOrd.sas';


/*Covariance matrix is not symmetric positive definite ....*/
proc iml;
	call randseed(220870);
	load module=_all_;

	varNames =  {"PCT_P_Montagna" "PCT_P_Pianura" "PCT_P_Collina" "PCT_P_Roccia" "PCT_P_Ambiente" };
	use work.PMF;
	read all var varNames into X;
	close work.PMF;
	print X[c=VarNames];

	/* expected values and variance for each ordinal variable */
	Expected = OrdMean(X) // OrdVar(X);
	print Expected[r={“Mean” “Var”} c=varNames];

	varNames2 =  {"P_Montagna" "P_Pianura" "P_Collina" "P_Roccia" "P_Ambiente" };
	use mydata2.db_clean_linea;
	read all var varNames2 into alldata;
	close mydata2.db_clean_linea;
	Delta = corr(alldata);
	print Delta;
	N_X = RandMVOrdinal(1000, X, Delta);
/*	 print N_X;*/
	
/*	first = N_X[1:100,];*/
/*	print first[label="First 100 Obs: Multivariate Ordinal"];*/
	
quit;

proc corr data=MYDATA2.DB_CLEAN_LINEA Pearson Spearman noprob plots=matrix(hist) outs=spear(where=(_TYPE_="CORR"));
   var P_Montagna P_Pianura P_Collina P_Roccia P_Ambiente;
run;
proc iml;
	start ImanConoverTransform(Y, C);
		X = Y;
		N = nrow(X);
		R = J(N, ncol(X));

		/* compute scores of each column */
		do i = 1 to ncol(X);
			h = quantile("Normal", rank(X[,i])/(N+1) );
			R[,i] = h;
		end;

		/* these matrices are transposes of those in Iman & Conover */
		Q = root(corr(R));
		P = root(C);
		S = solve(Q,P);                      /* same as  S = inv(Q) * P; */
		M = R*S;             /* M has rank correlation close to target C */

		/* reorder columns of X to have same ranks as M.
		   In Iman-Conover (1982), the matrix is called R_B. */
		do i = 1 to ncol(M);
			rank = rank(M[,i]);
			tmp = X[,i];       /* TYPO in first edition */
			call sort(tmp);
			X[,i] = tmp[rank];
		end;

		return( X );
	finish;

	/*Load marginal distributions*/
	varNames =  {"P_Montagna" "P_Pianura" "P_Collina" "P_Roccia" "P_Ambiente" };
	use MYDATA2.DB_CLEAN_LINEA;
	read all var varNames into A;
	close MYDATA2.DB_CLEAN_LINEA;

	/*Load target RANK correlation*/
	varNames =  {"P_Montagna" "P_Pianura" "P_Collina" "P_Roccia" "P_Ambiente" };
	use WORK.SPEAR;
	read all var varNames into C;
	close  WORK.SPEAR;
	X = ImanConoverTransform(A, C);
	RankCorr = corr(X, "Spearman");
	print RankCorr[format=5.2];

	/* write to SAS data set */
	create MVData from X[c=("x1":"x5")];
	append from X;
	close MVData;
quit;


data MYDATA2.MVDATA;
 set MVDATA;
  rename x1=P_MONTAGNA;
  rename x2=P_PIANURA;
  rename x3=P_COLLINA;
  rename x4=P_ROCCIA;
  rename x5=P_AMBIENTE;
run;

data mydata2.score_SIM;
 merge MYDATA2.MVDATA mydata2.COPULA_DATA;
 
 run;

/*Working for COPULA */

proc univariate data=mydata2.db_clean_linea;
 var P_Collina;
run;

data mydata2.db_clean_linea_p (label="DS con variabili P_ rese a numeri interi");
  set mydata2.db_clean_linea;
  array p[7]  P_:;
  do i=1 to dim(p);
	p[i]=p[i]*100;
  end;
  format P_: best8.;
run;

proc sgplot data=mydata2.db_clean_linea_p;
	vbar P_collina;
run;

proc sgplot data=mydata2.db_clean_linea_p;
	vbar P_Montagna;
run;

proc sgplot data=mydata2.db_clean_linea_p;
	vbar P_Pianura;
run;

proc datasets lib=work nolist kill;
quit;
options mprint;
%MACRO GET_LAMBDA(var);

	proc genmod data=mydata2.db_clean_linea_p  ;
		model &var = / dist=zip  ;
		zeromodel &var;
		ods output parameterestimates=pe_&var;
		output out=out p=lambda /*l=lower u=upper*/;
	run;

	proc print data=out(obs=1);
		var lambda /*lower upper*/;
	run;

	proc transpose data=pe_&var out=tpe_&var;
		var estimate;
		id parameter;
	run;
/*
	data tpe_&var;
		set tpe_&var;
		lambda = exp(intercept);
		mean = lambda;
		var = lambda;
		PrYeq0 = pdf("poisson",0,lambda);
		Pct90 = quantile("poisson",.90,lambda);
		call streaminit(220870);

		do i=0 to 10000;
			SIM_&var = rand("poisson",lambda);
			if SIM_&var le 10 then	output;
		end;
	run;
	title "Poisson simulated data for: " "&var"; 
	proc sgplot data=tpe_&var;
		vbar SIM_&var;
	run;
*/
%MEND;

proc countreg data=mydata2.db_clean_linea_p plots=all;
   model P_collina = / dist=poisson;
   output out=predpoi probcount(0 10 20 30 04 45 50 55 60 80 100);
run;


proc hpfmm data=mydata2.db_clean_linea_p plots=all ;
   model P_collina =  / dist=Poisson ;
   model       +            / dist=Constant;
   output out=coll ;
run;

proc hpfmm data=mydata2.db_clean_linea_p plots=all ;
   model P_collina =  / dist=Poisson ;

   output out=coll ;
run;

%GET_LAMBDA(P_Collina);
%GET_LAMBDA(P_Pianura);
%GET_LAMBDA(P_Montagna);

proc copula data=mydata2.db_clean_linea_p;
	var P_Collina P_Montagna P_Pianura;
	fit normal;
	simulate / seed=1234 ndraws=1000 marginals=empirical outuniform=UnifData;
run;






data Sim; 
set UnifData;

expo_collina = quantile("Poisson", P_Collina,0.0772815534);
/*expo_montagna = quantile("Beta", P_Montagna, 0.305074, 2.893661);*/
/*expo_pianura = quantile("Beta", P_Pianura,0.865231, 0.241106); */

run;

proc corr data=mydata2.db_clean_linea Spearman noprob plots=matrix(hist); 
title "Original Data"; 
var P_Collina /*P_Montagna P_Pianura*/; 
run;

proc corr data=Sim Spearman noprob plots=matrix(hist); 
title "Simulated Data"; 
var expo_collina; 
run;