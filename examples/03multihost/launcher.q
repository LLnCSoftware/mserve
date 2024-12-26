environment:"" ;
setEnvString:{ environment:: x; `OK} ;
.z.ps:{value 0N!"system \"", environment, " ", (.z.X 0), " " , x, " &\"" ;} ;

/ When env Q_SERVANTOF specified, allow connection only from that IP address
if[0< count getenv `Q_SERVANTOF; .z.pw:{[u;p] (getenv `Q_SERVANTOF)~ "." sv string `int$ 0x0 vs .z.a}];
