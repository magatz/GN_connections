data New;
	basis1=(c1=1 OR c1=0);
	basis3=(c1=1);
	basis5=NOT(c1=1)*MAX(x1-0.7665019053, 0);
	basis7=NOT(c1=1 OR c1=0)*MAX(x1-0.7665019053, 0);
	basis8=NOT(c1=1 OR c1=0)*MAX(0.7665019053-x1, 0);
	basis9=(c1=1)*MAX(x1-0.5530566455, 0);
	basis10=(c1=1)*MAX(0.5530566455-x1, 0);
	basis11=(c1=1)*MAX(x1-0.045800759, 0);
	basis13=(c1=1)*MAX(x1-0.9526330293, 0);
	basis15=(c1=1 OR c1=0)*MAX(x1-0.9499325226, 0);
	basis17=(c1=1 OR c1=0)*MAX(x1-0.5142821095, 0);
	basis19=(c1=1 OR c1=0)*MAX(x1-0.9889635476, 0);
	pred=5.3829 - 4.3871*basis1 + 32.7761*basis3 +
             20.2859*basis5 - 11.4183*basis7 - 7.0758*basis8 +
             58.4911*basis9 - 71.6388*basis10 - 69.0764*basis11 -
             119.71*basis13 + 66.5733*basis15 + 6.6681*basis17 -
             185.21*basis19;
run;

data cost.input_ds_1;
	set mycas.input_ds_1;
run;

proc univariate data=MYCAS.input_ds_1;
	id descrizione_progetto;
	var lunghezza_condotte diametro;

	/* 	histogram lunghezza_condotte / gamma; */
	histogram diametro / gamma;
run;

data mycas.test(keep=lunghezza_condotte );
	call streaminit(HARDWARE);

	do i=1 to 500;
		lunghezza_condotte=int((rand("Gamma", 0.58795, 553.5184)));
		diametro=int((rand("Gamma", 26.29719, 4.015298)));

		if diametro le 75 then
			diametro=50;
		else if diametro gt 75 and diametro le 125 then
			diametro=100;
		else if diametro gt 125 and diametro le 175 then
			diametro=150;
		else if diametro gt 175 and diametro le 400 then
			diametro=200;
		else if diametro gt 400 then
			diametro=500;
		output;
	end;
run;


