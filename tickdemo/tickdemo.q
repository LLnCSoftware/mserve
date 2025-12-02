\l scripted.q 
\l edconfig.q 
currentdate:0Nd; nextdate:0Nd; 
getRoutingCriteria:{[arg;opt] 
  d:arg 1; 0N!(`getRoutingCriteria; d; currentdate); 
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
  msgqueue::msgqueue, (string `long$ (.z.P-eventBaseTime) * .000001),"-", (str cmd), ";" ;
  if[cmd~`initdate; nextdate:: currentdate:: arg; :(::)] ;
  if[cmd~`endofday; if[null currentdate; currentdate::arg]; if[nextdate<arg+1; nextdate::arg+1; requestSync[]; :(::)]] ;
  if[cmd~`finishSync; hclose remotes[arg]; remotes::remotes _ arg; if[0=count remotes; restart "A"]; :(::)] ;  
  if[(null currentdate)|currentdate=nextdate; :(::)]; 
  if[cmd~`hdbAready; if[0=0|restarting-::1; restart "B"]; :(::)] ;
  if[cmd~`hdbBready; if[0=0|restarting-::1;
    currentdate::nextdate; 
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
  if[restarting<>0; -2 "Warning: previous hdb restart not completed: ", (string restarting), " missing callbacks"];
  A: select from routingTable where stype like ("hdb", suffix) ;    /routing table rows for hdb servers to restart
  restarting::count A ; 
  -2 "restart hdb",suffix," ",(string restarting),"instances" ;
  hclose each abs A `h ;                                            /close handle for each server to be restarted.
  system "sleep 1" ;                                                /wait for connections to drop
  h:: h _/ A `h ;                                                    /remove these handles
  h2addr:: h2addr _/ A `h ;                                          / from all "h" dictionaries
  h2route:: h2route _/ A `h ;                                        / ..
  h2idle:: h2idle _/ A `h ;                                          / ..
  update h:0Ni from `routingTable where address in (A `address) ;   /remove these handles from the routing table rows.
  launchAll A ;                                                     /Launch new servers corresponding to these rows; then wait 5 sec.
  hdl: connectServant each A ;                                      /Connect to the new servers, obtaining new handles.
  update h:hdl from `routingTable where address in (A `address) ;   /set new handles in corresponding routing table rows.
 };

