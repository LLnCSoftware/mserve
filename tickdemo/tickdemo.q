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
  if[cmd~`endofday; if[null currentdate; currentdate::arg]; if[nextdate<arg+1; nextdate::arg+1; requestSync[]; :(::)]] ;
  if[cmd~`finishSync; hclose remotes[arg]; remotes::remotes _ arg; if[0=count remotes; restart "A"]; :(::)] ;  
  if[(null currentdate)|currentdate=nextdate; :(::)]; 
  if[cmd~`hdbAready; if[0=0|restarting-::1; restart "B"]; :(::)] ;
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
 
/Send `requestSync message to all remote hdb hosts before starting the endofday processing.
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
  remotes: exec address from routingTable where (stype like "hdb*"), not address like "localhost*" ;
  remotes: {x!(count x)#0Ni} `$ ":",/: (distinct {(x?":")#x} each string remotes),\: ":5999";
  if[0=count remotes; :restart "A"] ;
  {remotes[x]:h: hopen 0N!x; (neg h) 0N!(`requestSync; 0); (neg h)[]} each key remotes ;
 };


/Restart hdb.q on the hdbA or hdbB database; to ingest new data from tick.q log.
restarting: 0;
restart:{[suffix]
  if[restarting<>0; -2 "\nWarning: previous hdb restart not completed: ", (string restarting), " missing callbacks\n"];
  routing: select from routingTable where stype like ("hdb", suffix) ;  /get routing table rows to be restartred
  update h:0Ni from `routingTable where address in (routing `address) ; /suppress dispatch by clearing handles in live routing table.
  restarting::count routing ;                                           /number of hdbXready callbacks to expect
  -2 "\nrestart hdb",suffix," ",(string restarting)," servants\n" ; 
  timerAdd[1000; closeOld; routing] ;
 };

closeOld:{[routing]
  if[ any 0<count each h routing `h; timerAdd[1000; closeOld; routing]] ; /Wait until any queries on these handles finish
  -2 "\ndisconnect hdb servants to be restarted\n" ;
  hclose each 0N!abs routing `h ;                           /close all handles - servants terminate on disconnect
  h::h _/ (routing `h);                                      /remove handles from h dictionaries.
  h2addr:: h2addr _/ (routing `h) ;                          /Note: .z.pc does not fire for handles closed locally.
  h2route:: h2route _/ (routing `h) ;
  h2idle:: h2idle _/  (routing `h) ;                         
  timerAdd[1000; doLaunch; routing] ;                       /After 1 second, start new servants
 };

doLaunch:{[routing]
  timerAdd[5000; connectAll; launchAll routing] ;          /launch new servers; connect to them after 5 seconds.
 };                                                                        

