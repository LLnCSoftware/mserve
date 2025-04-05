/Provide a getRoutingCritera function which accepts an mserve request and returns a list of key-value pairs (dictionary).
/Provide a script which evaluates a boolean expression based on these key-value pairs for each avalable servant process
/Send each query to the first not-busy servant for which the boolean evaluates as true
/If all servants for which the boolean evaluates true are busy, the query must wait.
/If none of the booleans evaluate as true, reject the query with a error message.

/This dispatch algorithm makes use of the following services provided in mserve_np.q
/1. function "getArguments" which parses a q expression, always interpreting symbols as literals, not as variable names.
/2. dictionary "h" mapping each handle to the list of queries pending on that handle - to know if handle is busy 
/3. dictionary "h2addr" mapping each handle to it host and port.
/4. function   "launch" to run servant process "q-file"

algo: enlist "script-plugin" ;                   /plugin name and options (no options in this case)
routingTable:  "S*" 0: `:script.csv ;            /routing table with servant addresses and boolean expressions 

a2d:{ (`$ "arg",/: string til count x)!x};      /provide arguments in dictionary 
getRoutingCriteria:{a2d getArguments x} ;       /default criteria are just the arguments

makens:{[ns;dict](` sv `,ns) set ((`,key dict)!(::),value dict)}; /Evaluate boolean expressions with variable values comming
contextValues:{[dict;exprList] makens[`ctx;dict]; system "d .ctx"; r:value each exprList; system "d ."; r} /from a dictionary

check:{[]
  /compute "route" for new requests as a bit vector selecting matching rows from the dispach table.
  update route: routingBitVector each (query;client_options) from queries where null route ;

  /For each enqueued query, find the first matching row corresponding to a not-busy handle 
  hit: select qid, rtRow:(first where each route and busyBitVector[]) from queries where location=`master ;
  hit: exec (qid; rtRow) from hit where not null rtRow ;

  qid: hit[0]; hdl:routingTable[hit 1; `handle];
  send_query[hdl; qid] ;
 };

routingBitVector:{[req]
  0N!`routing ;
  vars: getRoutingCritera[req] ;
  contextValues[vars; canaryFilter routingTable] 
 };

busyBitVector:{
  0N!`busy ;
  handles: routingTable `handle ;
  0= count each (h handles)
 };

/Canary
cn_server_type:`; cn_old_version:`; cn_new_version:`; cn_start:0Np; 
cn_increment:25 ; cn_interval:10000 ; /Default to switch 25% of querys per 10 seconds
canaryFilter:{[tbl]
  if[ null any (cn_server_type; cn_old_version; cn_new_version; cn_start); :tbl] ;
  new_percentage: 100 & cn_increment* (`long$ .000001* .z.P-cn_start) div cn_interval ;
  ignore_version: $[ (first 1?100)< new_percentage; cn_old_version; cn_new_version] ;
  update expr:0b from routingTable where server_type like cn_server_type and server_version=ignore_version 
 } ;

/Launch Servants

launchServants:{ launchOneServant til count routingTable };
launchOneServant{[n] launch routingTable[n;`servant]}



