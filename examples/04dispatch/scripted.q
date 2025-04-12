/Provide a getRoutingCritera function which accepts an mserve request and returns a list of key-value pairs (dictionary).
/Provide a script which evaluates a boolean expression based on these key-value pairs for each avalable servant process
/Send each query to the first not-busy servant for which the boolean evaluates as true
/If all servants for which the boolean evaluates true are busy, the query must wait.
/If none of the booleans evaluate as true, reject the query with a error message.

/This dispatch algorithm makes use of the following services provided in mserve_np.q
/1. function "getArguments" which parses a q expression, always interpreting symbols as literals, not as variable names.
/2. dictionary "h" mapping each handle to the list of queries pending on that handle - to know if handle is busy 

algo: enlist "script-plugin" ;                     /plugin name and options (no options in this case)
getRoutingCriteria:{[arg;opt] ([symbol:arg 1])};   /Single criterion is "symbol", which comes from argument 1 (arg 0 is command).

makens:{[ns;dict](` sv `,ns) set ((`,key dict)!(::),value dict)}; /Evaluate boolean expressions with variable values comming
contextValues:{[dict;exprList] makens[`ctx;dict]; system "d .ctx"; r:value each exprList; system "d ."; r} /from a dictionary

check:{[]
  /compute "route" for new requests as a bit vector selecting matching rows from the dispach table.
  upd: validateRouting exec qid! routingBitVector'[query;client_options] from queries where null route ;
  update route: upd[qid] from `queries where qid in key upd ;  

  /For each enqueued query, find the first matching row corresponding to a not-busy handle 
  notbusy: enlist notbusyBitVector[] ;
  hit: select qid, rtRow:first each where each (("1"= string route) and' ((count qid)#notbusy)) from queries where location=`master ;
  hit: select from hit where not null rtRow ;
  if[0<count hit; qid:(hit 0)`qid; hdl:(routingTable `h) (hit 0)`rtRow; send_query[hdl; qid]] ;
 };

/Return an error response to client when no server qualifies for the request
validateRouting:{[upd]
   err: where {all x=0} each upd ;
   send_result[;"Error: No qualifying server"; (::)] each err ;
   `$ raze each string upd
 };

/Obtain variables for substitution from "getRoutingCriteria"
/Substitute into "condition" field to evaluate the boolean expressions.
/Return bit vector corresponding to routingTable rows, where 1 means "ok for this query".
routingBitVector:{[qry;opt]
  vars: getRoutingCriteria[getArguments qry; opt] ;
  restrictFallback contextValues[vars; (canaryFilter routingTable) `condition] 
 };

/A fallback is any routing table row whos condition is always true (1b).
/Fallbacks are typically placed at the bottom of the the routing table
/to be used ONLY when no other rule qualifies. (perhaps they don't maintain
/locality, and hence are slower). But they may used anyway when all other
/qualifiying servers are busy. 
/Avoid this by clearing the fallback bits when other bits are set.
fallbackPos:(::) ;  /(disable by setting fallbackPos to ())
restrictFallback:{[bits]
  if[0=count fallbackPos; :bits] ;
  if[fallbackPos~(::); fallbackPos:: where (routingTable `condition) in ("1b"; "(1b)")] ;
  test:bits; test[fallbackPos]:0b ;
  $[all test=0b; bits; test]
 };

/The handle dictionary may be in a different order because the routing table was edited using "setRule'.
/By evaluating "h" on the routingTables "h" column, we get the h[] values in routing table order.
/Handles mapped to an empty list are not in use, i.e. not busy
/Return bit vector corresponding to routingTable rows, where 1 means "not busy"
notbusyBitVector:{ 0= count each h routingTable `h};

/Canary
cn_server_type:`; cn_old_version:0N; cn_new_version:0N; cn_start:0Np; 
cn_increment:25 ; cn_interval:30000 ; /Default to switch 25% of querys per 30 seconds
canaryFilter:{[tbl]
  if[ any null (cn_server_type; cn_old_version; cn_new_version); :tbl] ;
  if[ null cn_start; cn_start:: .z.P] ;
  new_percentage: 100 & cn_increment* (`long$ .000001* .z.P-cn_start) div cn_interval ;
  ignore_version: $[ (first 1?100)< new_percentage; cn_old_version; cn_new_version] ;
  /0N!(`canary; cn_server_type; new_percentage; ignore_version) ;
  update condition:enlist "0b" from tbl where stype=cn_server_type, sversion=ignore_version 
 } ;

/****** Synchronous api to edit routing table ******

invalid:"Routing commands must be lists of strings" ;
.z.pg:{
  if[0<>type x; :invalid]; if[any 10<>type each x; :invalid] ;
  if[(x 0)~"getRule"; :getRule x 1] ;
  if[(x 0)~"setRule"; :setRule[x 1; x 2; x 3]] ;
  "Unexpected routing command: ", x 0 ;
 } ;

getRule:{1_ "," 0: select from (delete h from routingTable) where address like str x } ;
setRule:{[pos;routing;canary] 
  if[10=type pos; pos: "J"$ pos] ;
  if[0<count canary;
    if[3<>count canary; :"phase-in requires 3 settings: oldversion, percentage, per-interval (suffix: m=minutes, h=hours, d=days)"] ;
    canary: "," vs canary ;
    cn_old_version: "J"$ canary 0 ;
    cn_increment:   "J"$ ssr[;"%";""] canary 1 ;
    cn_interval:    interval canary 2 ;
    if[any null (cn_old_version; cn_increment; cn_interval); :"Invalid phase-in specification."] ;
  ] ;
  /update routing table
  len:count routingTable;  pos:len^pos ;
  routing: (-1_ cols routingTable)! ("SSJ**"; ",") 0: routing ;   /same as a routing table csv row
  hit: (routingTable `address)? routing `address ;                /Is address already in table ?
  if[hit<len; routing[`h]: routingTable[hit;`h]; routingTable[hit]:routing] ;  /yes: replace row, but keep same handle
  if[hit=len; routing[`h]: connectServant routing; routingTable,:routing] ;    /no:  connect servant then add row w new handle
  if[hit<>pos; routingTable::moveItemInList[routingTable;hit;pos]];  /if not in requested position, move.
  /clear previous routing symbol in enqueued queries (recompute upon next "check[]")
  update route:` from `queries where location=`master ;
  /start canary (if any)
  if[0<count canary; cn_server_type:routing `stype; cn_new_version:routing `sversion; cn_start:.z.P] ; 
 } ;

interval:{u:last x; x: -1_ x; ("J"$x)* $[u="m"; 60000; u="h"; 60*60000; u="d"; 24*60*60000; 0N]}
moveItemInList:{[data;fr;to] 
  en:count data;
  a:til fr&to; b:fr&to; d:fr|to; c:1+b+til d-b+1; e:1+d+til en-d+1;
  data raze 0N! $[fr<to; (a;c;d;b;e); (a;d;b;c;e)]
 }; 

connectServant:{[routing]
  newh: neg @[hopen; hsym routing `address; 0Ni]; 
  if[ null newh;
    servant,: enlist (":" vs string routing `address), enlist routing `qfile ;    /add new servant
    lh: launch last servant ;  /lh=handle to launcher.q when servant on foreign host
    -1 "Wait 5 seconds" ; system "sleep 5"; 
    if[not null lh; hclose lh] ;
    newh: neg hopen hsym routing `address ;
  ];
  h[newh]:() ;
  h2addr[newh]: last servant ;
  h2route[newh]: enlist `$() ;
  h2idle[newh]: 0Np ;
  newh 
 };

/***** Startup ******

/Load Routing Table (afile= file name from command line) 
routingTable:("SSJ**"; enlist ",") 0: `$":",afile ;    /routing table (host:port|stype|sversion|condition|qfile)
servant: (":" vs/: string routingTable `address);      /servants to be launched by the mserve startup
servant: servant ,' enlist each routingTable `qfile ;  /append q-file to load.

/Mserve callback provides handles to routing table
readyCallback:{[x] routingTable:: routingTable,'([] h:x)} ;

