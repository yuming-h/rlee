
/*-----------------------------------------------------------*
 em_asymptotic()
 ==============

	Main macro to compute the mles
	alpha_k, p_k and lambda_k for
	k=1,...,in_num_classes

 	-in_sample: frequency dataset with variables
			n_i and freq
			-n_i: number of neighbours
			-freq: number of records with n_i
				 neighbours
	-in_num_classes: number of classes, a scalar
	-in_num_iter: number of iterations of the EM,
				a scalar
	-out_mles: dataset giving the estimates
				and the log-likelihood, with one row and the
				variables alpha_k, p_k and lambda_k
				for k=1,...,in_num_classes
*-----------------------------------------------------------*/

%macro em_asymptotic(in_sample=,
					 in_num_classes=,
					 in_num_iter=,
					 out_mles=);

%local k iter;

data init_estimates;
 alpha_1=1.0;
 p_1=0.7;
 lambda_1=2.0;
 output;
run;

data estimates_M_step;
 set init_estimates;
run;

%do iter=1 %to &in_num_iter.;

 proc sql;
  create table sample_E_step_0 as
  select a.*,b.*
  from &in_sample.(keep=n_i freq) as a, estimates_M_step as b;
 quit;

data sample_E_step_1;

 set sample_E_step_0;

 if n_i eq 0 then do;
  %do k=1 %to &in_num_classes.;
   p_n_i_&k.=(1-p_&k.)*exp(-lambda_&k.);
  %end;
 end;
 else do;
  %do k=1 %to &in_num_classes.;
   p_n_i_&k.=(p_&k.+(1-p_&k.)*lambda_&k./n_i)*PDF('POISSON',n_i-1,lambda_&k.);
  %end;
 end;

 %if &in_num_classes.=1 %then %do;
  total=alpha_1*p_n_i_1;
 %end;
 %else %do;
  total=alpha_1*p_n_i_1 + %do k=2 %to &in_num_classes.; + alpha_&k.*p_n_i_&k. %end;;
 %end;

  %do k=1 %to &in_num_classes.;
   E_c_&k.=alpha_&k.*p_n_i_&k./total;
   E_n_i_1_&k.=n_i*p_&k./(n_i*p_&k.+(1-p_&k.)*lambda_&k.);
   E_n_i_2_&k.=n_i*((n_i-1)*p_&k.+(1-p_&k.)*lambda_&k.)/(n_i*p_&k.+(1-p_&k.)*lambda_&k.);
  %end;
 run;

 %if &in_num_classes.=1 %then %do;
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
   %do k=2 %to &in_num_classes.; , sum(freq*E_c_&k.)/sum(freq) as alpha_&k., sum(freq*E_c_&k.*E_n_i_1_&k.)/sum(freq*E_c_&k.) as p_&k.,
   sum(freq*E_c_&k.*E_n_i_2_&k.)/sum(freq*E_c_&k.) as lambda_&k.  %end;
   from sample_E_step_1;
  quit;
 %end;

 %end;

 data &out_mles.;
  set estimates_M_step;
  %if &in_num_classes.=1 %then %do;
   p		= p_1;
   lambda	= lambda_1;
  %end;
  %else %do;
   p		= alpha_1*p_1 %do k=2 %to &in_num_classes.; + alpha_&k.*p_&k. %end;;
   lambda	= alpha_1*lambda_1 %do k=2 %to &in_num_classes.; + alpha_&k.*lambda_&k. %end;;
  %end;
 run; 

%mend em_asymptotic;

/*
%em_asymptotic();

proc printto;
run;
*/
