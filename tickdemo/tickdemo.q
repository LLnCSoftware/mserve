\l scripted.q 
\l edconfig.q 
currentdate:0Nd; nextdate:0Nd; 
getRoutingCriteria:{[arg;opt] 
  d:arg 1; /0N!(`getRoutingCriteria; d; currentdate); 
  /If request arrives before rdb receives a record from feed.q, currentdate will be unset because rdb.q has not initialized
  if[null currentdate; '"rdb.q not ready; (invoke 'go[]' from console)"];
  /Route based on offset from current date
  if[(abs type d) within (6 7); :([loday:first d; hiday: last d])] ; 
  if[ 14<>abs type d; :([hiday:0N; loday:0N]) ];
  ([loday:(first d)-currentdate ; hiday:(last d)-currentdate])
 } ;

eventBaseTime:.z.P ;
servantMessage:{[id;cmd;arg]
  -2 "tickdemo.q servant message: ", .Q.s1 (id; cmd; arg) ;
  msgqueue::msgqueue, (string `long$ (.z.P-eventBaseTime) * .000001),":", (str cmd), ";" ;
  if[cmd~`initdate; nextdate:: currentdate:: arg; :(::)] ;
  if[cmd~`endofday; if[null currentdate; currentdate::arg]; if[nextdate<arg+1; nextdate::arg+1; shutdownA[]; :(::)]] ;
  if[cmd~`finishSync; hclose remotes[arg]; remotes::remotes _ arg; if[ 0=count remotes; (doLaunch "A")[] ]; :(::)] ;  
  if[(null currentdate)|currentdate=nextdate; :(::)]; 
  if[cmd~`hdbAready; if[0=0|restarting-::1; restartB[] ]; :(::)] ;
  if[cmd~`hdbBready; if[0=0|restarting-::1;
    currentdate::nextdate;
    msgqueue::msgqueue, (string `long$ (.z.P-eventBaseTime) * .000001),":startofday;" ; 
    {x (`startofday; y)}[;currentdate] each where h2addr[;2] like "rdb.q *" ; 
    ls: @[system; "ls data/log/schema* 2>/dev/null"; ()] ;                     /move log files more than 2 days old to archive
    ls: ls where ("D"$ -10#/:ls)< -2+ currentdate ;                            /this will cause the rsync job (w --delete)
    {system "mv ", x, " data/archive"} each ls ;                               /to remove these log files from all servants
  ]];                                                                          /now that they have been added to hdb
 };

/Add record of servant messages received to response "info" dictionary using "filterResponse" stub in mserve_np.q
/This stub has previously been overriden by "canaryFailover" in scripted.q, so invoke that at the end.
msgqueue:"" ;
filterResponse:{
  x[2;`events]: msgqueue;  
  x[2;`eventBaseTime]: `datetime$ eventBaseTime ;
  msgqueue::""; eventBaseTime:: .z.P ;
  canaryFailover x
 };

/To run without data comming in from feed.q, invoke this from console after startup.
go:{if[null currentdate; {x (`go; 1)} each where h2addr[;2] like "rdb.q *"; :"sent 'go' message to rdb.q"]; "ready now"};
 
/Previously, the requestSync message was sent first and the hdbA servers were shut down when
/the correpsonding finishSync message was received. However this required an additional IPC
/connection to the launcher for each remote hdb host, which caused our demo to exeede the 8
/allowed connections for the kdbX community edition.
/By shutting down the hdbA servers before the requestSync, we free up at least onc IPC connection
/for each hdb instance, which allows our demo to run with the community edition.
/This means we need to:
/When endoday received: shut down the hdbA servers, wait a second, send the requestSync message
/When finishSync received, launch the hdbA servers, wait 5 seconds, and connect to them.
/When hdb Aready received, shut down the hdbB servers, wait a second, re-launch them, wait 5 seconds, and connect.
/When there are no remote hdb servers,
/Omit the requestSync/finishSync and relaunch the hdbA servers a second after disconnecting them.

restarting:0 ;
shutdownA:{
  -2 "\nendofday: shutdown hdbA servers" ;
  n: exec count i from routingTable where (stype like "hdb*"), not address like "localhost*" ; /check for remote hdb servers
  routing: select from routingTable where stype like "hdbA" ;
  update h:0Ni from `routingTable where stype like "hdbA" ;     /suppress dispatch by clearing handles in live routing table
  $[0=n; closeThen[doLaunch "A"; routing]; closeThen[requestSync; routing]] ;
 }

/Wait for all queries on specified routing table rows to finish, then close the corresponding server connections.
/Invoke the specified function 1 second after closing.
closeThen:{[fn;routing]
 if[ any 0<count each h routing `h; timerAdd[1000; closeThen[fn;]; routing]] ; /Wait until any queries on these handles finish
  if[restarting<>0; -2 "Warning: previous hdb restart not completed: ", (string restarting), " missing callbacks"];
  -2 "disconnect hdb servants to be restarted" ;
  hclose each 0N!abs routing `h ;                     /close all handles - servants terminate on disconnect
  h::h _/ (routing `h);                               /remove handles from h dictionaries.
  h2addr:: h2addr _/ (routing `h) ;                   /Note: .z.pc does not fire for handles closed locally.
  h2route:: h2route _/ (routing `h) ;
  h2idle:: h2idle _/  (routing `h) ;                         
  timerAdd[1000; fn; routing] ;                       /After 1 second, start new servants
 };

/Send `requestSync message to all remote hdb hosts.
/This runs a new rsync job to ensure the tick.q logs are up to date before ingesting data for the hdb.
/Remote rdb instances are not included, because rdb does not ingest the logs at end of day, but rather at startup. 
/The "remotes" global maps the socket addresses of the hdb launchers to the handles used to send the `requestSync.
/This global is defined in mserve_np.q and causes messages from these handles to be treated like responses
/or servant messages rather than requests. Of course we want these to be servant messages, and so must start
/with -1 in place of the query id.
/Note: it is not necessary to stop the log updates while data is being ingested because the file ingested
/will be at least 2 days old, but all future updates will only affect files for the current date or later.
remotes:(`$())!(`int$()) ;
requestSync:{[] 
  -2 "\nRequest sync from remote launchers\n" ;
  remotes: exec address from routingTable where (stype like "hdb*"), not address like "localhost*" ;
  remotes: {x!(count x)#0Ni} `$ ":",/: (distinct {(x?":")#x} each string remotes),\: ":5999";
  {remotes[x]:h: hopen 0N!x; (neg h) 0N!(`requestSync; 0); (neg h)[]} each key remotes ;
 };

/Startup hdbA servers, when remote servers present, after finishSync messages received, otherwize 1 second after shutdown
/Note second argument (y) allows passing as a projection eg. (doLaunch "A")  to "closeThen".
doLaunch:{[x;y]
  -2 ("\nLaunch hdb", x), " servers\n" ;
  routing: select from routingTable where stype like ("hdb", x) ;  /routing table rows
  restarting:: count routing ;                                   /number of callbacks expected
  timerAdd[5000; connectAll; launchAll routing] ;                /launch new servers; connect to them after 5 seconds.
 };                                                                        

/Restart hdbB servers, when all hdbA servers have restarted
restartB:{[]
  -2 "\nShutdown hdbB servers\n" ;
  routing: select from routingTable where stype like "hdbB" ;
  update h:0Ni from `routingTable where stype like "hdbB" ;  /suppress dispatch by clearing handles in live routing table
  closeThen[doLaunch "B"; routing]; 
 }

