options casdatalimit=ALL;
cas mysession sessopts=(caslib=casuser timeout=1800);
caslib _all_ assign;

proc tsne data=mydata.db_allac ndimensions=2 perplexity=6.31726152 
		learningrate=15.4890862 maxiters=1646;
	input costo:  Totale_lunghezza;
	output out=mydata.tsne_out copyvar=commessa;
run;

proc fedsql sessref=mysession;
	create table mydata.db_rete_tsne {options replace=True} as select A.*, 
		B._DIM_1_, B._DIM_2_ from mydata.db_allac as A inner join mydata.tsne_out 
		as B on a.Commessa=B.Commessa;
	quit;

ods graphics on / width=1000 height=1000;
proc sgplot data=mydata.db_rete_tsne;
 scatter x=_dim_1_ y=_dim_2_;
run;


proc fedsql sessref=mysessione;
	create table mydata.db_rete_cluster {options replace=True} as select A.*, 
		B._CLUSTER_ID_ from mydata.db_allac as A inner join casuser.br_rete_cluster 
		as B on a.Commessa=B.Commessa;
	quit;