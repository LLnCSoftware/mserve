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

servantMessage:{[id;cmd;arg]
  -2 "tickdemo.q servant message: ", .Q.s1 (id; cmd; arg) ;
  if[cmd~`initdate; currentdate:: arg; :(::)] ;
  if[cmd~`endofday; if[null currentdate; currentdate::arg]; if[nextdate<arg+1; nextdate::arg+1; requestSync[]; :(::)]] ;
  if[cmd~`finishSync; hclose remotes[arg]; remotes::remotes _ arg; if[0=count remotes; restart "A"]; :(::)] ;  
  if[null currentdate; :(::)]; 
  if[cmd~`hdbAready; restart "B"; :(::)] ;
  if[cmd~`hdbBready; 
    currentdate::nextdate; 
    {x (`startofday; y)}[;currentdate] each where h2addr[;2] like "rdb.q *" ; 
  ];
 };


/To run without data comming in from feed.q, invoke this from console after startup.
go:{if[null currentdate; {x (`go; 1)} each where h2addr[;2] like "rdb.q *"; :"sent 'go' message to rdb.q"]; "ready now"};
 
/Send `requestSync message to all remote hosts before starting the endofday processing.
/This will bring all remote logs up to date, before restarting the hdb instances to ingest new data.
/Note: it is not necessary to stop the log updates while data is being ingested because the file ingested
/will be at least 2 days old, but all future updates will only affect files for the current date or later.
remotes:(`$())!(`int$()) ;
requestSync:{[] 
  remotes::{x!(count x)#0Ni} `$":",/: (hosts where not hosts~\:""),\:":5999"; 
  if[0=count remotes; :restart "A"] ;
  {remotes[x]:h: hopen x; (neg h) (`requestSync; 0); (neg h)[]} each key remotes ;
 };

/Restart hdb.q on the hdbA or hdbB database; to ingest new data from tick.q log.
restart:{[suffix]
  -2 "restart hdb",suffix ;
  A: select from routingTable where stype like ("hdb", suffix) ;    /routing table rows for hdb servers to restart
  cn_phasein:: exec stype like ("hdb", suffix) from routingTable ;  /phasein bit vector for these rows.
  cn_increment:: 0 ;                                                /start canary - holding at 0%. 
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
  cn_phasein:: (count routingTable)#0b ;                            /clear the phasein bit vector.
  cn_increment:: 0N ;                                               /stop the canary.
 };

