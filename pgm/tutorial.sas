
/*-------------------------------------*/
/* Tutorial
/*-------------------------------------*/

libname local 'F:\Organize\byDates\2019Jan25\Asymptotic\TaeHyun\Tutorial\data';

option symbolgen;

proc printto log='F:\Organize\byDates\2019Jan25\Asymptotic\TaeHyun\Tutorial\log\tutorial_log.txt' new;
run;
proc printto print='F:\Organize\byDates\2019Jan25\Asymptotic\TaeHyun\Tutorial\output\tutorial_out.txt' new;
run;

%include 'F:\Organize\byDates\2019Jan25\Asymptotic\TaeHyun\Tutorial\pgm\em_macro.sas';

/*-------------------------------------*/
/* Simulate homogeneous data
/*-------------------------------------*/

%let randseed=100;
%let p=0.9;
%let lambda=1.0;
%let N=1000;

data all_nis;
 call streaminit(&randseed.);
 do i=1 to &N.;
  n_i=rand('BERNOULLI',&p.)+rand('POISSON',&lambda.);
  output;
 end;
run;

proc sql;
 create table sample as
 select n_i, count(*) as freq
 from all_nis group by n_i;
quit;

%em_asymptotic( in_sample=sample,
				in_num_classes=1,
				in_num_iter=100,
				out_mles=mles);

proc printto;
run;
