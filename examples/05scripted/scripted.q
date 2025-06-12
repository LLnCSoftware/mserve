/Provide a getRoutingCritera function which accepts an mserve request and returns a list of key-value pairs (dictionary).
/Provide a script which evaluates a boolean expression based on these key-value pairs for each avalable servant process
/Send each query to the first not-busy servant for which the boolean evaluates as true
/If all servants for which the boolean evaluates true are busy, the query must wait.
/If none of the booleans evaluate as true, reject the query with a error message.

/This dispatch algorithm makes use of the following services provided in mserve_np.q
/1. function "getArguments" which parses a q expression, always interpreting symbols as literals, not as variable names.
/2. dictionary "h" mapping each handle to the list of queries pending on that handle - to know if handle is busy 

/The getRoutingCriteria and routingDescriptor objects are application specific, and must be provided
/by a plugin which is loaded BEFORE this one, ie. must precede "scripted.q" in the MSERVE_PLUGINS env variable.

/The getRoutingCriteria function transforms the query arguments and reqest options in to a dictionary of variables
/to be substituted into the "conditions" in the routingTable, to decide which servers are qualified for which requests.
/The default just creates one variable "symbol" from the first argument of each query.

/The default routingDescriptor is the general null (:;). This is appropriate when the conditions in the routing table are
/evaluated one-by-one to produce a routingBitVector with a bit for each row in the routing table, which is the default method.
/However, an additional plugin may provide a more efficient way to obtain the routing bit vectors, such as retrieving
/them from a precomputed store, or evaluating them in a decision tree. In this case a routingDescriptor must be provided 
/according to the requirements of that plugin.

/ ContextSource is an abstraction to allow a plugin to provide a faster way to compute 
/ the routing bit vector such as using precomputed values or a decision tree.
/ The default "contextSource" is just the  routing table condition column, and this is also the 
/ input to the "getContextSource" function, which the plugin would override, along with the "contextValues" 
/ function which actually computes the bit vector given the routing criteria and context source.  

/ The requestContextSource is intended to be overridden by a plugin which will make an asynchronous call to an
/ external process which will build the contextSource and return it to receiveContextSource in a callback.
/ However, by default requestContextSource simply calls receiveContextSource directly.
/ A new contextSource is needed at startup and whenever the routingTable is edited or a canary is finalized.
/ At startup the received object is simply set in the contexSource global.
/ However when the routeingTable is edited or a canary is finalized, receiveContextSource will be replaced
/ by an appropriate projection of the alterRouting function, which also manipulates the canary control globals.
algo: enlist "script-plugin" ;                     /plugin name and options (no options in this case)
if[not `getRoutingCriteria   in key `. ; getRoutingCriteria:{[arg;opt] ([symbol:arg 1])} ];   .
if[not `routingDescriptor    in key `. ; routingDescriptor:(::) ];                           
if[not `requestContextSource in key `. ; requestContextSource:{[cond;rd] receiveContextSource cond}] ;
if[not `contextValues in key `. ; contextValues:{[vars;cs] makens[`ctx;vars]; system "d .ctx"; r:value each cs; system "d ."; r}];
receiveContextSource:{ contextSource::x} ;

/ContextValues by default evaluates the boolean expressions from the routing table in a namespace
/The following function creates that namespace from the dictionary returned by getRoutingCriteria.
makens:{[ns;dict](` sv `,ns) set ((`,key dict)!(::),value dict)}; 

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
  restrictFallback canaryFilter contextValues[vars; contextSource]  
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

/The handle dictionary may be in a different order because the routing table was edited. 
/By evaluating "h" on the routingTables "h" column, we get the h[] values in routing table order.
/Handles mapped to an empty list are not in use, i.e. not busy
/Return bit vector corresponding to routingTable rows, where 1 means "not busy"
notbusyBitVector:{ 0= count each h routingTable `h};

/**** Canary Filter ******
cn_increment:0N; cn_interval:0N; cn_start:0Np; 
cn_phasein:`boolean$(); cn_phaseout:`boolean$(); cn_backupRT:(::); cn_backupCS:(::);
cn_percentage:{0^ cn_increment* 1+ (`long$ .000001* .z.P-cn_start) div 60000|cn_interval} ;
canaryFilter:{[bitvector]
  if[null cn_increment; :bitvector] ;                                                 /no canary
  if[cn_increment<0; -1 "phase-in holding at 100%"; :bitvector and not cn_phaseout] ; /canary holding at 100% 
  if[cn_increment=0; -1 "phase-in holding at 0%" ;  :bitvector and not cn_phasein]  ; /canary holding at 0% 
  if[null cn_start; cn_start:: .z.P] ;                 /start on first request
  new_percentage: cn_percentage[] ; 
  if[new_percentage>=100+cn_increment; endPhaseIn[]] ;
  random:first 1?100; use_new: random< new_percentage ;
  -1 "phase-in ",(string random)," < ",(string 100& new_percentage), "%  error ",(string cn_cnterr)," of ",(string cn_maxerr) ;
  bitvector and not $[use_new; cn_phaseout; cn_phasein]  
 };
endPhaseIn:{ cn_increment::-1; cn_start::0Np; -1 "\n*****\n end phase-in - hold at 100%\n*****\n"; } ;

/**** Canary Failover ******
/ This overrides "filterResponse" in mserve_np.q
/ When canary in effect, screen responses for errors. Revert to original config when error count exceeds maximum. 
cn_cnterr: 0 ;
cn_maxerr: 3^ "J"$ getenv `CN_MAXERR ;
filterResponse:{                                          /x= (id; result; info)
  if[(0>=cn_increment) or all cn_phasein=0b; :x] ;        /No canary, 0%, or nothing to phase in -- just return
  if[10<>type x 1; :x; not "ERROR"~ upper 5# x 1; :x];    /Error is a string result strarting with ERROR; no error -- just return
  phasein: (routingTable `address) where cn_phasein ;     /Get phase in addresses from routing table
  address:x[2] `qsvr; if[not address in phasein; :x];     /If servant address not included -- just return 
  cn_cnterr+::1; if[cn_cnterr<cn_maxerr; :x] ;            /less than max errors -- just return 
  -1 "\n*****\n failover - hold at 0%\n*****\n" ;
  cn_increment::0; cn_start::0Np; 
  x                   /return response
 } ;

/**** connect new servant (used by configuration editor) *****
connectServant:{[route]
  newh: neg hopen hsym route `address ;
  h[newh]:() ;
  h2addr[newh]: {(":" vs string x `address), enlist string x `qfile} route ;
  h2route[newh]: ` ;
  h2idle[newh]: 0Np ;
  newh
 };

/***** Startup ******
/Load Routing Table (afile= file name from command line) 
routingTable:("SSJ*S"; enlist ",") 0: `$":",afile ;        /routing table (host:port|stype|sversion|condition|qfile)
cn_phasein:cn_phaseout: (count routingTable)# 0b ;         /initialize phase in/out bitvectors to 0 of proper length.

requestContextSource[routingTable `condition; routingDescriptor]; /request initial context source

servant: (":" vs/: string routingTable `address);             /servants to be launched by the mserve startup
servant: servant ,' enlist each string routingTable `qfile ;  /append q-file to load.

/Mserve callback provides handles to routing table
/We can't load the configuration editor edconfig.q until after the handles are provided
/because it edconfig.q, creates the editable copy of the routing table upon load, 
/and expectes the handles to be included.
readyCallback:{[x] 
  routingTable:: routingTable,'([] h:x) ;
  system "l edconfig.q" ;
 } ;

