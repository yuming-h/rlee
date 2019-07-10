libname local 'F:\Organize\byDates\2019Jan25\Asymptotic\data\Census_of_Ag\BC_organic';
option symbolgen;

proc printto log='F:\Organize\byDates\2019Jan25\Asymptotic\log\bcorganic_log.txt' new;
run;
proc printto print='F:\Organize\byDates\2019Jan25\Asymptotic\output\bcorganic_out.txt' new;
run;

/*----------------------------------------------*/
/* Macro variables
/*----------------------------------------------*/
%let num_iter	 = 16000;
%let num_classes = 32;

/*----------------------------------------------*/
/*
/*----------------------------------------------*/
%let num_farms				= 8102;
%let farms_wo_pairs			= 41;
%let farms_with_some_pairs	= 8061;
%let blocking_only			= 1;

%macro prepare_sample();
%if &blocking_only.=0 %then %do;
proc sql;
 create table num_unlinked_dset
 as select &num_farms. - count(*) as freq
 from local.freq_ni_map_cr_map_removed(where=(strip(status) eq 'D'));
quit;

data sample_unlinked;
 set num_unlinked_dset;
 n_i=0;
run;

data links_per_record;
 set local.freq_ni_map_cr_map_removed_90(where=(strip(status) eq 'D') rename=(N=n_i));
 keep n_i;
run;
proc sql;
 create table sample_linked
 as select n_i, count(*) as freq
 from links_per_record group by n_i;
quit;

data local.sample;
 set sample_unlinked sample_linked;
run;
%end;
%else %do;
 data sample_wo_pairs;
  n_i	= 0;
  freq	= &farms_wo_pairs.;
  output;
 run;

 proc sql;
  create table pairs_per_record as
  seclect sum(N) as n_i
  from local.freq_ni_map_cr_map_removed group by table_a_rec_id;
 quit;

 proc sql;
  create table sample_with_pairs
  as select n_i, count(*) as freq
  from pairs_per_record group by n_i;
 quit;

 data local.sample;
  set sample_wo_pairs sample_with_pairs;
 run;
%end;
%mend prepare_sample;

%prepare_sample();

/*----------------------------------------------*/
/* Identify and remove the outliers
/*----------------------------------------------*/

proc sql;
 create table mean_sd_dset
 as select sum(freq*n_i)/sum(freq) as mean_n_i,
 sqrt((sum(freq*n_i**2)-(sum(freq*n_i))**2/sum(freq))/(sum(freq)-1)) as sd_n_i
 from local.sample;
quit;

proc sql;
 create table sample_0
 as select a.*,b.*
 from local.sample a, mean_sd_dset b;
quit;

data trimmed_sample(keep=n_i freq);
 set sample_0;
 if(abs(n_i-mean_n_i)/sd_n_i lt 3);
run;

/*----------------------------------------------*/
/* Read the data
/*----------------------------------------------*/
/*
data local.sample;
 set sample;
run;
*/
proc sql;
 create table total_obs_dset
 as select sum(freq) as total_obs
 from trimmed_sample;
quit;

proc sql;
 create table trimmed_sample_0
  as select a.*,b.*
  from trimmed_sample a, total_obs_dset b;
quit;

data sample;
 set trimmed_sample_0;
 retain cum_freq;
 if(_n_ eq 1) then cum_freq=freq;
 else cum_freq=cum_freq+freq;
 cum_pct=cum_freq/total_obs;
run;

/*----------------------------------------------*/
/* em_asymptotic()
/*----------------------------------------------*/

%macro em_asymptotic();

%do k=1 %to &num_classes.;
 data init_lambda_&k.;
  set sample(where=(cum_pct ge &k./&num_classes.));
  lambda_&k.=max(0.1,n_i);
  if _n_ eq 1;
  keep lambda_&k.;
 run;
%end;

proc sql;
 create table init_p
 as select %do k=1 %to &num_classes.; %if &k.>1 %then %do; , %end; 1-sum(freq*(n_i eq 0))/sum(freq) as p_&k. %end;
 from sample;
quit;

%let num_classes_minus_1 = %eval(&num_classes-1);

data init_alpha;
 %do k=1 %to &num_classes.;
   alpha_&k.= 1/&num_classes.;
 %end;
 output;
run;

proc sql;
 create table estimates_M_step
 as select a.*, b.* %do k=1 %to &num_classes.; ,init_lambda_&k..* %end;
 from init_p a, init_alpha b %do k=1 %to &num_classes.; ,init_lambda_&k. %end;;
quit;

data init_estimates;
 set estimates_M_step;
run;

%do iter=1 %to &num_iter.;

 proc sql;
  create table sample_E_step_0 as
  select a.*,b.*
  from sample(keep=n_i freq) as a, estimates_M_step as b;
 quit;

data sample_E_step_1;

 set sample_E_step_0;

 if n_i eq 0 then do;
  %do k=1 %to &num_classes.;
   p_n_i_&k.=(1-p_&k.)*exp(-lambda_&k.);
  %end;
 end;
 else do;
  %do k=1 %to &num_classes.;
   p_n_i_&k.=(p_&k.+(1-p_&k.)*lambda_&k./n_i)*PDF('POISSON',n_i-1,lambda_&k.);
  %end;
 end;

 %if &num_classes.=1 %then %do;
  total=alpha_1*p_n_i_1;
 %end;
 %else %do;
  total=alpha_1*p_n_i_1 + %do k=2 %to &num_classes.; + alpha_&k.*p_n_i_&k. %end;;
 %end;

  %do k=1 %to &num_classes.;
   E_c_&k.=alpha_&k.*p_n_i_&k./total;
   E_n_i_1_&k.=n_i*p_&k./(n_i*p_&k.+(1-p_&k.)*lambda_&k.);
   E_n_i_2_&k.=n_i*((n_i-1)*p_&k.+(1-p_&k.)*lambda_&k.)/(n_i*p_&k.+(1-p_&k.)*lambda_&k.);
  %end;
 run;

 %if &num_classes.=1 %then %do;
  proc sql;
   create table estimates_M_step as
   select sum(freq*E_c_1)/sum(freq) as alpha_1, sum(freq*E_c_1*E_n_i_1_1)/sum(freq*E_c_1) as p_1,
   sum(freq*E_c_1*E_n_i_2_1)/sum(freq*E_c_1) as lambda_1
   from sample_E_step_1;
  quit;
 %end;
 %else %do;
  proc sql;
   create table estimates_M_step as
   select sum(freq*E_c_1)/sum(freq) as alpha_1, sum(freq*E_c_1*E_n_i_1_1)/sum(freq*E_c_1) as p_1,
   sum(freq*E_c_1*E_n_i_2_1)/sum(freq*E_c_1) as lambda_1
   %do k=2 %to &num_classes.; , sum(freq*E_c_&k.)/sum(freq) as alpha_&k., sum(freq*E_c_&k.*E_n_i_1_&k.)/sum(freq*E_c_&k.) as p_&k.,
   sum(freq*E_c_&k.*E_n_i_2_&k.)/sum(freq*E_c_&k.) as lambda_&k.  %end;
   from sample_E_step_1;
  quit;
 %end;

 %end;

 data local.empirical_estimates;
  set estimates_M_step;
  %if &num_classes.=1 %then %do;
   p		= p_1;
   lambda	= lambda_1;
  %end;
  %else %do;
   p		= alpha_1*p_1 %do k=2 %to &num_classes.; + alpha_&k.*p_&k. %end;;
   lambda	= alpha_1*lambda_1 %do k=2 %to &num_classes.; + alpha_&k.*lambda_&k. %end;;
  %end;
 run; 

 data local.overall_estimates;
   set estimates_M_step;
   %if &num_classes.=1 %then %do;
    p 		= p_1;
	lambda	= lambda_1;
   %end;
   %else %do;
    p 		= alpha_1*p_1 %do k=2 %to &num_classes.; + alpha_&k.*p_&k. %end;;
	lambda	= alpha_1*lambda_1 %do k=2 %to &num_classes.; + alpha_&k.*lambda_&k. %end;;
   %end;
   keep p lambda;
 run;

%mend em_asymptotic;

%em_asymptotic();

proc printto;
run;
