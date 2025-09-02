/launcher.q (soon to be renamed to "remote.q") has 3 functions:
/1. Launch q programs on remote hosts using the "launchQ.q" protocol.
/2. Sync directories with the "servantof" machine (if any)
/3. Announce itself as available to the "servantof" machine (if any).

/usage: q launcher.q servantof-ip announce-port dir1 dir2 ...
servantof: $[0=count .z.x; ""; .z.x 0] ;         /This program serves requests only from this ip address
announce:  "J"$ $[0=count .z.x; ""; .z.x 1] ;    /Annouce IP of this host to servantof machine on this port number
syncdirs:  2_ .z.x ;                             /Sync these directories to same path on servantof machine

\l launchQ.q

/Async requests and responses
.z.ps:{
  if[`launchQ=x 0; :doLaunch 1_ x] ;
  if[`requestSync=x 0; :requestSync[] ] ;
  if[`finishsync=x 0; :finishsync[] ] ;
  '"unexpected command: ", .Q.s1 x  ;
 } ;

doLaunch:{
  if[10=type x; x: enlist x] ;
  if[not all (10=) type each x; '"launchQ: expect a list of strings ([base-path; [env-settings;]] launch-command)"] ;  
  if[1=count x; launchQ[""; ""; x 0]] ;
  if[2=count x; launchQ[x 0; ""; x 1]] ;
  launchQ[x 0; x 1; x 2] ;
 } ;

/The rsync job runs on the timer, once every 2 minutes
/To ensure directories are up-to-date as of a given point in time, we provide a "requestSync" command.
/This always starts a new rsync operation, if one is running already, a new one is started as soon as the old one finishes.
/When the new rsync finishes a "finishSync" message is relayed back to the requesting program.
/When this message is received, the  directories are up-to-date as of the time of the request
/In the mserve tick demo, this is needed in 2 places: before the hdb instances are restarted at "endofday",
/and whenever an rdb instance starts up on a remote host.
/Note: restarting timer sends next tick immediately 
sync_flag:0; syncbegin:0Np; connected:0b ;
requestSync:{[] 
  -1 "\ndirectory sync request\n";  sync_flag:2; 
  if[null syncbegin; sync_flag=1; syncCount::syncEvery; system "t ", string timerFreq;]
 } ; 


finishsync:{
  -1 finishmsg[]; syncbegin::0Np; 
  if[sync_flag=2; sync_flag::1; syncCount::syncEvery; system "t ", string timerFreq];
  if[sync_flag=1; sync_flag::0; (neg .z.w) (`finishSync; `$ myip, ":5999")] ;
 };
finishmsg:{ 
  a: "rsyncjob finished ", (string `long$ .000001* .z.p-syncbegin),"ms  flag=", string sync_flag ;
  b: "directory sizes ", " " sv  {{(x?"\t")#x} first system "du -h -d 0 ", x} each syncdirs ;
  a, " ", b
 };

/Timer calls
timerFreq:5000 ;  /announce every 10 seconds
syncEvery:12 ;     /sync every 2 minutes
syncCount:0 ;
.z.ts:{ 
  -1 "timer ", string syncCount ;
  if[syncEvery<syncCount+::1; syncCount::0; dosyncdir[]]; 
  if[not connected; connected::@[doannounce;0;0b]] 
 };
syncnow:{syncCount:syncEvery; system "t ", string timerFreq} ;
syncnow[] ;

/Start up

rsyncjob:"" ;       /rsyncjob blank when not in use
dosyncdir:{ } ;     /Stub for directory sync when not in use
doannounce:{0b} ;   /Stub for annoucnement when not in use

/When servantof address specified, only accept connection from that address (or localhost for rsync callback)
if[0<count servantof; .z.pw:{[u;p] ("." sv string `int$ 0x0 vs .z.a) in (servantof; "127.0.0.1") }] ;                 
myip: "." sv string `int$ 0x0 vs .z.a ;

/When servantof address specified, with at least one directory to sync
/Run an rsync job periodically
if[(0<count servantof) and 0<count syncdirs;
  rsyncjob: tilda each resolve[""] each syncdirs ;
  rsyncjob: ";\n" sv {"rsync -avz ", servantof, ":", x, "/ ", x, " 1>/dev/null 2>1" } each rsyncjob ;
  callback: "echo 'h:hopen 5999; (neg h) (`finishsync; 0); (neg h)[]; exit 0' | q &" ;
  -1 "rsyncjob:\n", rsyncjob, "\n" ;
  dosyncdir:{ syncbegin::.z.p; system rsyncjob, "; ", callback ;}
 ];

/When servant of address and announcement port are specified, 
/announce yourself by sending a synchronous message to that address and port
/Continue announcements until connection is successfull and `OK returned.
if[(0<count servantof) and not null announce;
  doannounce:{ `OK= (`$":", servantof, ":", string announce) myip } 
 ];

