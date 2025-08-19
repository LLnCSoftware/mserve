\l launchQ.q

.z.ps:{if[10<>type x; '"Launch String Expected"];  launchQ[""; ""; x]} ;

/ When env Q_SERVANTOF specified, allow connection only from that IP address
if[0< count getenv `Q_SERVANTOF; .z.pw:{[u;p] (getenv `Q_SERVANTOF)~ "." sv string `int$ 0x0 vs .z.a}];
