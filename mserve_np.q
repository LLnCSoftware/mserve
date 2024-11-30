/ 
Nathan Perrem
First Derivatives
2013-05.22

Eric Lazarus 2024-09-18 Added support for servants on multiple hosts (requires "launcher.q" running on each remote host).

This is a heavily modified version of Arthur Whitney's mserve solution which can be found at code.kx:
https://code.kx.com/trac/wiki/Cookbook/LoadBalancing

The purpose of mserve is to provide load balancing capabilities so that queries from one or more clients
can be sent to the master who will send these queries in a load balanced way to the servants.
The servants will then send the results back to the master who sends the results back to the client

Sample usage:  q mserve_np.q -p 5001 2 servant.q  [host1 host2 ...]

.z.x 0  - 1st argument - number of servant to start up
.z.x 1  - 2nd argument - the script we want each servant to load 
.z.x 2+ - additional arguments are host names or ip addresses on which to run servants (round robbin).

On startup of the master process, the following steps take place:
1. Master decides on the hosts and port numbers the servants will listen on
2. Master starts up the servant processes listening on the required ports 
3. Master connects to the servants
4. Master sends a message to each servant telling servant to:
	a)define .z.pc such that servant terminates when master disconnects
	b)load in the appropriate script so the servant has data

We maintain a dictionary on the master process which keeps track on all the outstanding requests on the servants.
This dictionary maps each servant handle to a list of all query ids for whom that servant has requests currently.

All the communication between client-master, master-servant, servant-master and master-client is asynchronous.

1 Store query as well as client handle when new request is received by master
2 assign unique id to each new query
3 Store combination of client handle,query id,query and call back function in queries table
4 Do not automatically send new query to least busy servant, instead only send new query when a servant is free

******** comments below this point need revision *********

Change to communication protocol 2024.09.18

1. Add required client_query_id and optional repetition factor to mserve request. 
   request: (client_query_id; callback; query; rep)
2. Add client_query_id, servant elapsed time and servant address to mserve response.
   response: (callback; client query id; servant elapsed time; servant address; servant response)
3. Add client_qid, client_rep, and time sent to "queries" table.
4. Provide a dictionary "d" mapping servant handle back to servant address.

Change to communication protocol 2024.09.25

1. Expect the responder function to be provided in the servant, rather than passing it with the request.

Allow selection of dispatch algorithm via environment variable 2024.11.26
MSERVE_ALGO= (default is "orig")
  orig  - send to first free servant (in order of "servant" list).
  even  - send to first free servant, furthr down list from last dispatch. (utilize all servants evenly)
  match - client sends routing string w query. Prefer a servant whos previous query had same routing string.
\

\c 10 133

/ get servant addresses from arguments
port: system "p" ;
hosts: {$[x~"localhost"; ""; x]} each 2_ .z.x ;
if[0=count hosts; hosts: enlist ""] ;

servant: port+ {1+ x-first x} each (count hosts; 0N)# til "J"$ .z.x 0 ;
servant: raze {(enlist first x),/: enlist each string 1_ x} each (enlist each hosts) ,' servant ;
-1 "servant addresses" ;
-1 each .Q.s1 each servant ;
-1 "" ;

/ launch servants 
/ expect "launcher" listening on port 5999 on each host other than "localhost".
mycode: .z.x 1 ;
myq: .z.X 0 ;
mys: string system "s" ;
str: {$[10=type x; x; string x]} ;
launch:{value 0N!"system \"", (.z.X 0), " ", x, " &\"" ;} ;

h:{-1 "mserve_np.q: Launch ", mycode, " on `:", (x 0), ":", (x 1); 
  cmd: mycode, " -s ", mys, " -p ", (x 1) ;  
  if[""~(x 0); launch cmd; :0N] ;
  hh:hopen `$":",(x 0), ":5999" ; 
  (neg hh) cmd; (neg hh)[]; 
  hh 
 } each servant ; 

-1 "Wait 5 seconds" ;
system "sleep 5"
hclose each h where not null h ;
h:() ;

/ hopen handle to each servant
-1 "Connect to servants" ;
h:{neg hopen `$":",( x 0),":", (x 1)} each servant;
{ x ".z.pc:{-1 \"closed\"; exit 0}"} each h ; /shutdown on lost connection
-1 "OK" ;

/ map each servant handle back to the servant address
d:h!servant ; 

/ map each servant handle to a list of routing symbols from previous queries (initialize to empty)
r: h!(count h)# `$() ;

/map each servant asynch handle to an empty list and assign resultant dictionary back to h
/The values in this dictionary will be the unique query ids currently outstanding on that servant (should be max of one)
h!:()
 
.z.pg:{:"SEND MESSAGE ASYNCH!"};

queries:([qid:`u#`int$()]
		query:();
    client_qid: `int$() ;
    client_rep: `int$() ;
		client_handle:`int$();
		client_callback:`symbol$();
		time_received:`time$();
    time_sent: `time$() ;
		time_returned:`time$();
		slave_handle:`int$();
		location:`symbol$() ;
    route: `symbol$() ;
    bbi: `int$()
		);

/update `u#qid from `queries;	

send_query:{[hdl; qid]
	/if there is an outstanding query to be sent, try to send it
	if[not null qid;
  	query:queries[qid;`query];
    rep:queries[qid; `client_rep] ;
    bbi:queries[qid; `bbi] ;
  	h[hdl],:qid;
  	queries[qid;`slave_handle]:hdl;
    queries[qid;`time_sent]: .z.T ;
  	queries[qid;`location]:`slave;
    hdl (`respond; (qid; query; rep; bbi)) ;
	];
 };

send_result:{[qid;result;info]
	query:queries[qid;`query] ;
	client_handle:queries[qid;`client_handle] ;
  client_queryid: queries[qid; `client_qid] ;
	client_callback:queries[qid;`client_callback] ;
  servant_address: {`$":",(x 0),":",(x 1)} d queries[qid; `slave_handle] ;
  servant_elapsed: `long$ .z.T - queries[qid; `time_sent] ;
  if[ 0=count info; info: `qsvr`execution!(servant_address; servant_elapsed) ];

  /0N!(`mserversp; client_handle; client_callback; client_queryid; result; info) ;
	client_handle (client_callback; client_queryid; result; info);
	queries[qid;`location`time_returned]:(`client;.z.T);
  r[ queries[qid; `slave_handle] ]: queries[qid; `route] ;
 }; 
 
/original: check if free slave. If free slave exists -> try to send oldest query 
/this tends to put too many queries on the same slave
check_orig:{[] 
	qid: exec first qid from queries where location=`master;  /oldest query
  if[not 0N=hdl:?[count each h;0];send_query[hdl;qid]] ;
 };

/previous: check for free slave, further down the list than the last one
/this distributes the queries more evenly across the slaves
/howerver it can actually degrade performance because more queries run with a cold cache
lasthdl:0i ;
check_even:{[]
	qid: exec first qid from queries where location=`master;  /oldest query
  list: asc where 0=count each h ;
  if[0=count list; :(::)] ;
  hdl: first list where list<lasthdl ;
  if[null hdl; hdl: first list] ;
  lasthdl:: hdl; send_query[hdl;qid] ;
 }; 

/current: attempt to send oldest query to a free slave 
/prefer a slave whos previous query had the same routing symbol 
check_match:{[]
  n: 1|"J"$algo 1 ;
	qry: exec first qid, first route from queries where location=`master;  /oldest query
	hfree: asc where 0=count each h ;                                      /free servant handles
  if[ (null qry `qid) or 0=count hfree; :(::)];                          /if no unsent query or no free servant ? return 

  /hmatch: $[null qry `route; `$(); hfree where r[hfree]= qry `route];    /free servant handles matching route
  rt: (`.)^ qry `route ;   /use "-" or null for non-specific route
  hmatch: $[rt= `.; hfree where 0=count r[hfree] except `.; hfree where rt in r[hfree]] ; 

  if[0<count hmatch; hfree: hmatch] ;         /if any matching, consider only those.
  hdl: first hfree where hfree>lasthdl ;      /if any beyond last servent dispatched in the list, use first of those.
  if[null hdl; hdl: first hfree] ;            /otherwize use first remaining.
  lasthdl:: hdl; send_query[hdl; qry `qid] ;  /save handle as last dispathed servant, and send query to it.
 };

/ select dispatch algorithm
algo: " " vs (ssr[;"  "; " "]/) getenv `MSERVE_ALGO ;
check:(check_orig; check_orig; check_even; check_match; (::)) ``orig`even`match? `$ algo 0 ;
if[ null check; '"Unknown dispatch algorithm: ", getenv `MSERVE_ALGO] ;
-1 "Using dispatch algorithm: '",$[""~getenv `MSERVE_ALGO; "orig"; getenv `MSERVE_ALGO], "'" ;

/ default routing string is first argument to api command
getRoutingString:{[cmd] if[10=type cmd; cmd:parse cmd]; cmd[1]} ;
if[0<count getenv `MSERVE_ROUTING; getRoutingString: parse getenv `MSERVE_ROUTING] ;

/
.z.ps is where all the action resides. As said already, all communication is asynch, so any request from a client
or response from a servant will result in .z.ps executing on the master

input to .z.ps is x
There are 2 possibilities
1. x is a query received from a client
2. x is a result received from a servant

.z.w stores the asynch handle back to whoever has sent the master the asynch message (either a client or servant)

We have an if else statement checking whether the call back handle (.z.w) to the other process exists in the key of h or not
if .z.w exists in h => message is a response from a servant
if .z.w does not exist in h => message is a new request from a client
\
 
.z.ps:{[x]
	$[not(w:neg .z.w)in key h;
	[ /request - (client qid; callback; query; route; rep; bbi)  Note:"route" and "rep" are optional.	
    /0N!(`mservereq; x) ;
    sqid: 1^1+exec last qid from queries; /server id for new query
    cqid: x[0]; callback: x[1]; query: x[2]; rep:1|x[3]; bbi:x[4]; 
    route:getRoutingSymbol(query) ;
    `queries upsert (sqid; query; cqid; rep; (neg .z.w); callback; .z.T; 0Nt; 0Nt; 0N; `master; route; bbi); 
    /check for a free slave.If one exists,send oldest query to that slave
    check[];
	] ;
	[ /response - (server qid, result, info)
    qid:x[0];
    result:x[1];
    info:$[2<count x; x[2]; ()] ;
  	/try to send result back to client
  	.[send_result;
  		(qid;result;info);
  		{[qid;error]queries[qid;`location`time_returned]:(`client_failure;.z.T)}[qid]
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
