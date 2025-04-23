/Nathan Perrem
/First Derivatives
/2013-05.22
/-
/Eric Lazarus 2024-09-18 Added support for servants on multiple hosts (requires "launcher.q" running on each remote host).
/-
/This is a heavily modified version of Arthur Whitney's mserve solution which can be found at code.kx:
/https://code.kx.com/trac/wiki/Cookbook/LoadBalancing
/-
/The purpose of mserve is to provide load balancing capabilities so that queries from one or more clients
/can be sent to the master who will send these queries in a load balanced way to the servants.
/The servants will then send the results back to the master who sends the results back to the client
/-
/Sample usage:  q mserve_np.q -p 5001 2 servant.q  [host1 host2 ...]
/-
/.z.x 0  - 1st argument - number of servant to start up
/.z.x 1  - 2nd argument - the script we want each servant to load 
/.z.x 2+ - additional arguments are host names or ip addresses on which to run servants (round robbin).
/-
/On startup of the master process, the following steps take place:
/1. Master decides on the hosts and port numbers the servants will listen on
/2. Master starts up the servant processes listening on the required ports 
/3. Master connects to the servants
/-
/We maintain a dictionary on the master process which keeps track on all the outstanding requests on the servants.
/This dictionary maps each servant handle to a list of all query ids for whom that servant has requests currently.
/-
/All the communication between client-master, master-servant, servant-master and master-client is asynchronous.
/-
/Allow selection of dispatch algorithm via environment variable 2024.11.26
/MSERVE_ALGO= (default is "match")
/  orig  - send to first free servant (in order of "servant" list).
/  even  - send to first free servant, furthr down list from last dispatch. (utilize all servants evenly)
/  match - computes a routing string for each query. Prefer a servant whos previous query had same routing string.

\c 10 133

/ Ingest Arguments
/ Delay startup until after application and plugins are loaded
/ to allow a plugin to change the startup procedure

myq: .z.X 0 ;              /Path to "q" interpreter
mys: string system "s" ;   /Servants will have same s-value as mserve
acount: "J"$ .z.x 0 ;      /Number of servants
afile:  .z.x 1 ;           /File to load

/When using scripted dispatch method, omit or specify the number of servers as zero,
/and provide the dispatch csv file instead of a servant "q-file".
/A servant will be started for each row in the dispatch table, using the q-file in the row.
if[null acount; acount:0; afile:.z.x 0] ;  /First arg not numeric ? Assume omitted. Use zero.

port: system "p"; 
if[port=0i; system "p 5000"; port:5000i] ;

hosts: {$[x~"localhost"; ""; x]} each 2_ .z.x ;
if[0=count hosts; hosts: enlist ""] ;

servant: port+ {1+ x-first x} each (count hosts; 0N)# til acount ;
servant: raze {(enlist first x),/: enlist each string 1_ x} each (enlist each hosts) ,' servant ;
servant: {x, enlist afile} each servant ;

/ utilities
str: {$[10=type x; x; string x]} ;         /convert non-string to string
tms: { `long$ .000001 * x } ;              /convert timestamp difference to ms
addMs:{y+1000000*x} ;                      /add ms to timestamp
ip2string:{"." sv string `int$ 0x0 vs x} ; /convert ip address from integer to string

/** Synchronous interface **
z.pg:{:"SEND MESSAGE ASYNCH!"};

/** Query table **
queries:([qid:`u#`int$()]
  query:();
  client_qid: `int$() ;
  client_options: () ;
  client_handle:`int$();
  time_received:`timestamp$();
  time_sent: `timestamp$() ;
  time_returned:`timestamp$();
  route: `symbol$() ;
  backlog: `int$() ;
  servant_address:`symbol$();
  location:`symbol$() 
 );
/update `u#qid from `queries;	

/** Send Query to Servant **
send_query:{[hdl; qid]
  if[0<hdl; -1 "****ERROR: positive handle ", (string hdl), " will try negation"; hdl:neg hdl] ;
	if[not null qid;
    -1 ts[], "-> Forward Request: #", (str queries[qid;`client_qid]), " to ", {x[0],":",x[1], "  (", x[2], ")"} h2addr hdl ;
  	query:queries[qid;`query];
    options: queries[qid; `client_options];
  	h[hdl],:qid;
    h2route[hdl]: enlist queries[qid; `route] ;
    h2idle[hdl]: 0Wp ;
  	queries[qid;`servant_address]: `$ {x[0],":",x[1]} h2addr hdl;
    queries[qid;`time_sent]: .z.P ;
  	queries[qid;`location]:`servant;
    hdl (qid; query; options) ; 
	];
 };

/** Send Result (or error) to Client **
send_result:{[qid;result;info]
	query:queries[qid;`query] ;
	queries[qid;`location`time_returned]:(`client;.z.P);
	client_handle:queries[qid;`client_handle] ;
  client_queryid: queries[qid; `client_qid] ;
  servant_address: queries[qid; `servant_address] ;
  servant_elapsed: tms .z.P - queries[qid; `time_sent] ;
  total_elapsed: tms .z.P - queries[qid; `time_received] ;
  remaining: exec count i from queries where location in `master`servant ;
  backlog: `long$ queries[qid; `backlog] ;
  route:queries[qid; `route] ;
  if[ 99<>type info; info: `qsvr`elapsed`execution!(servant_address; total_elapsed; servant_elapsed) ];
  info,: `route`backlog`remaining!(route; backlog; remaining) ;
  response: filterResponse(client_queryid; result; info) ;
  -1 ts[], "-> Return Response: #", (str response 0), "  ", describeResult[response 1; response 2] ;
	client_handle response ;
  h2idle[neg .z.w]: .z.P ;
 }; 
filterResponse:{x} ;  /Stub to modify response in a plugin

/** Built-in dispatch methods **
 
/original: check if free slave. If free slave exists -> try to send oldest query 
/this tends to put too many queries on the same slave
check_orig:{[] 
  /0N!"check_orig" ;
	qid: exec first qid from queries where location=`master;  /oldest query
  if[not 0N=hdl:?[count each h;0];send_query[hdl;qid]] ;
 };

/previous: check for free slave, further down the list than the last one
/this distributes the queries more evenly across the slaves
/howerver it can actually degrade performance because more queries run with a cold cache
lasthdl:0i ;
check_even:{[]
  /0N!"check_even" ;
	qid: exec first qid from queries where location in `master ;
  list: asc where 0=count each h ;
  if[0=count list; :(::)] ;
  hdl: first list where list<lasthdl ;
  if[null hdl; hdl: first list] ;
  lasthdl:: hdl; send_query[hdl;qid] ;
 }; 

/current: attempt to send a query to servent with same routing symbol 
/otherwise attempt to send first query to a servant with an unset or expired routing symbol
/otherwise request call on the timer
routeExpireMs:12000 ;
check_match:{[]
  nextCheck::0Wp ; /disable call on timer

  /compute routing symbol for any queries which lack it
  update route:getRoutingSymbol each query from `queries where location=`master, null route ;

  /dispatch first enqueued query for which some non-busy handle has the same routing symbol, to the first such handle
  match: select qid, hdl:{first (where x in/: h2route) inter (where 0=count each h) } each route from queries where location=`master ;
  match: select from match where not null hdl ;
  if[0<count match; 0N!(`match; match[0;`qid]; match[0;`hdl]);  :send_query[ match[0;`hdl]; match[0;`qid] ]] 

  /dispactch first enqueued query for which no handle has the same routing symbol
  /to first non-busy handle whos routing symbol is unset or expired
  qry: exec first qid from queries where location=`master, not route in raze h2route ;
  hdl: first where (0=count each h) and h2idle< addMs[neg routeExpireMs;.z.P] ;
  if[(not null qry) and not null hdl; 0N!(`claim; qry; hdl); :send_query[hdl; qry] ];

  /If queue not empty, but nothing dispatched, request call on timer
  if[`master in (value queries) `location; 
    nextCheck:: addMs[routeExpireMs; min .z.P, value h2idle]; 0N!(`wait; qry; tms nextCheck-.z.P)
  ]
 };

/ select dispatch algorithm
algo: " " vs (ssr[;"  "; " "]/) getenv `MSERVE_ALGO ;
if[0=count algo 0; algo:enlist "match"];

check:(check_orig; check_even; check_match; (::)) `orig`even`match? `$ algo 0 ;
if[ null check; '"Unknown dispatch algorithm: ", getenv `MSERVE_ALGO] ;

/ default routing string is first argument to api command
fixarg:{$[11=type x; $[1=count x; x 0; x]; 0=type x; $[(1=count x)&11=type x 0; x 0; (100>type x 0); x; enlist~x 0; 1_ x; `invaid]; x]};
getArguments:{[cmd] if[10=type cmd; cmd:parse cmd]; arg:fixarg each 1_ cmd; (cmd[0], arg) };
getRoutingSymbol:{[cmd] if[10=type cmd; cmd:parse cmd]; `$ str fixarg cmd[1]} ;
if[0<count getenv `MSERVE_ROUTING; getRoutingSymbol: value getenv `MSERVE_ROUTING] ;


/.z.ps is where all the action resides. As said already, all communication is asynch, so any request from a client
/or response from a servant will result in .z.ps executing on the master
/-
/input to .z.ps is x
/There are 2 possibilities
/1. x is a query received from a client
/2. x is a result received from a servant
/-
/.z.w stores the asynch handle back to whoever has sent the master the asynch message (either a client or servant)
/We have an if else statement checking whether the call back handle (.z.w) to the other process exists in the key of h or not
/if .z.w exists in h => message is a response from a servant
/if .z.w does not exist in h => message is a new request from a client

getrole:{`}; /overridden in plugin "authent.q" (looks up role for .z.u in users table 
.z.ps:{[x]
	$[not(w:neg .z.w)in key h;
	[ /request - (client qid; query; options)	
    -1 ts[], "-> Receive Request: #", (" " sv str each x) ; 
    cqid:x[0]; query:x[1]; options: x[2]; if[99<>type options; options:([])]; /options must be a dictionary
    sqid: 1^1+exec last qid from queries;                                     /server id for new query
    bklg: exec count i from queries where location in `master`servant ;       /queries in queue ahead of this one
    role:getrole[];                                                           /overridden in authent.q plugin
    if[not null role; options[`user]:.z.u; options[`role]:role];

    `queries upsert (sqid; query; cqid; options; (neg .z.w); .z.P; 0Np; 0Np; `; bklg; `; `master); 
    /check for a free slave.If one exists,send oldest query to that slave
    check[];
	] ;
	[ /response - (server qid; result; info)
    /0N!(`servantrsp; x) ;
    qid:x[0]; result:x[1]; info:x[2];
  	/try to send result back to client
  	.[send_result;
  		(qid;result;info);
  		{[qid;error]queries[qid;`location`time_returned]:(`client_failure;.z.P)}[qid]
  	 ];
  	/drop the first query id from the slave list in dict h
  	h[w]:1_h[w];
    /route up to 2 additional queries to servants
    check[]; check[] ;
	]];	
 };

/Change location of queries outstanding on the dead servant to master
.z.pc:{
	update location:`master from `queries where qid in h@neg x; /reassign lost queries to master process (for subsequent re-assignment)
	h::h _ (neg x); /remove dead servant handle from h
	check[];
	/if client handle went down, remove outstanding queries
	delete from `queries where location=`master,client_handle=neg x;
 };

/ Purge completed queries from the table
nextCheck:0Wp ;  /check on timer (set by dispatch algo) default +infinity (never check)
lastPurge:.z.P ;  /purge completed queries every 5 minutes
purgeCompletedMs:60000* 30^ "J"$ getenv `MSERVE_PURGE ;  /default 30 minutes
purgeCompleted:{ delete from `queries where location=`client, purgeCompletedMs< tms .z.P - time_returned } ;

.z.ts:{
  if[nextCheck<.z.P; check[]] ;
  if[600000<.z.P-lastPurge; purgeCompleted[]; lastPurge::.z.P]
 };
\t 5000


/ Launch to servants
/ expect "launcher" listening on port 5999 on each host other than "localhost".
servant_env:"Q_SERVANTOF='", (ip2string .z.a), "' Q_PLUGINS='", (getenv `Q_PLUGINS), "'";
local_env:"Q_SERVANTOF='127.0.0.1' Q_PLUGINS='", (getenv `Q_PLUGINS), "'" ;
loclaunch:{value 0N!"system \"", local_env, " ", (.z.X 0), " ", x, " &\"" ;} ;

launch:{-1 "mserve_np.q: Launch ", (x 2), " on `:", (x 0), ":", (x 1); 
  cmd:(x 2), " -s ", mys, " -p ", (x 1) ;  
  if[(x 0) in (""; "localhost"); loclaunch cmd; :0N] ;
  hh:hopen `$":",(x 0), ":5999" ; 
  hh "setEnvString \"", servant_env, "\"" ; 
  (neg hh) cmd; (neg hh)[]; 
  hh 
 } ; 

/****** Formatting for log messages *******

/timestamp
lastout:0Np ;
addMinutes:{y+ x*3600000000000} ; /x*60*60000*1000000
ts:{
  stime:.z.P ;
  if[lastout< addMinutes[-15] stime; lastout::stime; -1  ssr[;"D";"  "] -10_ (string stime)];
  14_ -6_ string .z.P 
 };

/describe result
describeResult:{[x;y]
  info: "  server=", (1_ str y `qsvr), " route=", (str y `route), " elapsed= ", (str y `elapsed) ;
  if[10=type x; if["ERROR"~upper 5# x; :($[40<count x; 40#x,".."; x],info)]]; 

  t:gettype x; if[t in ("null"; "empty"); :t];
  $[(0>type x); ""; (string count x)," "], t, $[0>type x; " atom"; 0<type x; "s"; ""], info  
 } ; 

gettype:{[x]
  num:abs type x ; 
  if[x~(::); :"null"] ;
  if[0>num; if[null x; :"null"]] ;
  if[(0=num) & 0=count x; :"empty"] ;
  if[num<20; :alltypes num] ;
  if[num within (20;76); :"enum"] ;
  if[num within (77;97); :"type ", num] ;
  if[num=98; :"table row"] ;
  if[num=99; :$[98= type key x; "keyed row"; "dict item"]] ;
  if[num within (100;111); :"function"] ;
  if[num>111; :"type ", num] ;
 };
alltypes:(0 1 2 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19h)!("mixed"; "boolean"; "guid"; "byte"; 
  "short"; "int"; "long"; "real"; "float"; "char"; "symb"; "timestamp"; "month"; "date"; "datetime";
  "timespan"; "minute"; "second"; "time") ; 

/******* Startup below this point *****
readyCallback:{} ; /pass handles back to (scripted.q) plugin after startup

/ Load plugins
if[0<count getenv `MSERVE_PLUGINS;   {system "l ",x;} each "," vs getenv `MSERVE_PLUGINS];

-1 "servant addresses" ;
-1 each .Q.s1 each servant ;
-1 "" ;

h: launch each servant ; 

-1 "Wait 5 seconds" ;
system "sleep 5"
hclose each h where not null h ;
h:() ;

/ hopen handle to each servant
-1 "Connect to servants" ;
h:{neg hopen `$":",( x 0),":", (x 1)} each servant;
readyCallback h ;
-1 "OK" ;

/ map each servant handle back to the servant address
h2addr:h!servant ; 

/ map each servant handle to a list of routing symbols from previous queries (initialize to empty)
h2route: h!(count h)# enlist `$() ;
h2idle:  h!(count h)# 0Np ;

/map each servant asynch handle to an empty list and assign resultant dictionary back to h
/The values in this dictionary will be the unique query ids currently outstanding on that servant (should be max of one)
h!:()
 
-1 "Using dispatch algorithm: '",(" " sv algo), "'" ;
0N!"mserve_np.q loaded" ;


