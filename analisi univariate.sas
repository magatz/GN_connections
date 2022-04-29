

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