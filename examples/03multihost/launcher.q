\l launchQ.q

.z.ps:{
  if[10=type x; x: enlist x] ;
  if[not all (10=) type each x; '"launchQ: expect a list of strings ([base-path; [env-settings;]] launch-command)"] ;  
  if[1=count x; launchQ[""; ""; x 0]] ;
  if[2=count x; launchQ[x 0; ""; x 1]] ;
  launchQ[x 0; x 1; x 2] ;
 } ;

/ When env Q_SERVANTOF specified, allow connection only from that IP address
if[0< count getenv `Q_SERVANTOF; .z.pw:{[u;p] (getenv `Q_SERVANTOF)~ "." sv string `int$ 0x0 vs .z.a}];
