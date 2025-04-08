/Provide a getRoutingCritera function which accepts an mserve request and returns a list of key-value pairs (dictionary).
/Provide a script which evaluates a boolean expression based on these key-value pairs for each avalable servant process
/Send each query to the first not-busy servant for which the boolean evaluates as true
/If all servants for which the boolean evaluates true are busy, the query must wait.
/If none of the booleans evaluate as true, reject the query with a error message.

/This dispatch algorithm makes use of the following services provided in mserve_np.q
/1. function "getArguments" which parses a q expression, always interpreting symbols as literals, not as variable names.
/2. dictionary "h" mapping each handle to the list of queries pending on that handle - to know if handle is busy 

algo: enlist "script-plugin" ;                     /plugin name and options (no options in this case)
getRoutingCriteria:{[arg;opt] ([symbol:arg 1])};   /default criteria are just the arguments of the query

makens:{[ns;dict](` sv `,ns) set ((`,key dict)!(::),value dict)}; /Evaluate boolean expressions with variable values comming
contextValues:{[dict;exprList] makens[`ctx;dict]; system "d .ctx"; r:value each exprList; system "d ."; r} /from a dictionary

check:{[]
  /compute "route" for new requests as a bit vector selecting matching rows from the dispach table.
  upd:exec qid! `$ raze each string routingBitVector'[query;client_options] from queries where null route ;
  update route: upd[qid] from `queries where qid in key upd ;

  /For each enqueued query, find the first matching row corresponding to a not-busy handle 
  notbusy: enlist busyBitVector[] ;
  hit: select qid, rtRow:first each where each (("1"= string route) and' ((count qid)#notbusy)) from queries where location=`master ;
  if[0<count hit; qid:(hit 0)`qid; hdl:(key h) (hit 0)`rtRow;  0N!(hdl;qid);  send_query[hdl; qid]] ;
 };

/Obtain variables for substitution from "getRoutingCriteria"
/Substitute into "condition" field to evaluate the boolean expressions.
/Return bit vector corresponding to routingTable rows, where 1 means "ok for this query".
routingBitVector:{[qry;opt]
  vars: getRoutingCriteria[getArguments qry; opt] ;
  contextValues[vars; (canaryFilter routingTable) `condition] 
 };

/The handle dictionary also corresponds positionally to the rows of the routing table.
/Handles mapped to an empty list, are not in use, i.e. not busy
/Return bit vector corresponding to routingTable rows, where 1 means "not busy"
busyBitVector:{ 0= count each value h};

/Canary
cn_server_type:`; cn_old_version:`; cn_new_version:`; cn_start:0Np; 
cn_increment:25 ; cn_interval:10000 ; /Default to switch 25% of querys per 10 seconds
canaryFilter:{[tbl]
  if[ any null (cn_server_type; cn_old_version; cn_new_version; cn_start); :tbl] ;
  new_percentage: 100 & cn_increment* (`long$ .000001* .z.P-cn_start) div cn_interval ;
  ignore_version: $[ (first 1?100)< new_percentage; cn_old_version; cn_new_version] ;
  update condition:0b from tbl where stype like cn_server_type and sversion=ignore_version 
 } ;

/Load Routing Table (afile= file name from command line) 
routingTable:("SSJ**"; enlist "|") 0: `$":",afile ;    /routing table (host:port|stype|sversion|condition|qfile)
servant: (":" vs/: string routingTable `address);      /servants to be loaded by the mserve startup
servant: servant ,' enlist each routingTable `qfile ;  /append q-file to load.

