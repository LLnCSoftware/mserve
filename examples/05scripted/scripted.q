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

algo: enlist "script-plugin" ;                     /plugin name and options (no options in this case)
if[not `getRoutingCriteria in key `. ; getRoutingCriteria:{[arg;opt] ([symbol:arg 1])} ];   .
if[not `routingDescriptor  in key `. ; routingDescriptor:(::) ];                           

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

/**** Installation/Phase-In controls for new routing table - typically invoked manually via editor *****

cancelPhaseIn:{[] 
  if[null cn_increment; :"No phase in to cancel" ];
  if[cn_increment<>0; :"Cancel only when holding at 0% - use alterPhaseIn[0;0N]"];
  if[(cn_backupRT~(::)) or cn_backupCS~(::); :"No backup to restore";]; 
  alterRouting[(::); cn_backupRT; cn_backupCS]
 } ; 

finishPhaseIn:{[]
  if[null cn_increment; :"No phase in to finish" ];
  if[cn_increment<>-1; :"Finish only when holding at 100% - use alterPhaseIn[-1; 0N]" ];
  if[all cn_phaseout=0b; 
   cn_increment::0N; cn_interval::0N; cn_start::0Np; 
   cn_backupRT::(::); cn_backupCS::(::); cn_phasein::cn_phaseout; 
   :"done - nothing to phase out"
  ];
  alterRoutingReq[(::); delete from routingTable where cn_phaseout]
 } ;

/ Allows changeing increment and/or interval for a canary in progress 
/ Specify 0N to leave increment or interval unchanged.
/ Specify increment as 0 or -1 to hold at 0% or 100% respectively.
alterPhaseIn:{[increment; interval]
  if[not null increment; cn_increment::increment] ;
  if[not null interval: cn_interval::interval] ;
  if[cn_increment=0; cn_start::0Np] ;
 } ;

/ Applies change to routing table after obtaining a new context source.
/ After validating the "canary" parameters, receiveContextSource is replaced by an appropriate 
/ projection of "alterRouting" below, before calling requestContextSource.
alterRoutingReq:{[canary; newRT]
  if[cn_increment>=0; -1 "Phase in already in progress"; :(::)];
  if[not canary~(::); 
    if[(canary[`increment]<-1) or canary[`interval]<=0; -1 "increment or interval missing"; :(::)];
    if[`phasein  in key canary; t:canary `phasein;  if[(1h<>type t) or (count t)<>count newRT; -1 "invalid phasein bit vector";  :(::)]];
    if[`phaseout in key canary; t:canary `phaseout; if[(1h<>type t) or (count t)<>count newRT; -1 "invalid phaseout bit vector"; :(::)]];
  ];
  -1 "awaiting context source" ;
  receiveContextSource::alterRouting[canary; newRT;] ;
  requestContextSource[newRT `condition; routingDescriptor] ;
 };

/ Alter Routing: This should be invoked as a callback after obtaining the new context source (newCS),
/ which could take some time to build. When canary is omitted (::), the operation is one of:
/ applying an abrut change (no phase in), or of finishing or canceling a previous canary.
/ In this case, the canary settings and backups will be cleared. Otherwize a new canary is being
/ started, and this can only happen when no previous canary is in effect.
alterRouting:{[canary; newRT; newCS]
  -1 "received context source" ;
  $[canary~(::); [cn_backupRT::(::); cn_backupCS::(::)]; [cn_backupRT::routingTable; cn_backupCS::contextSource]];

  update route:` from `queries where location=`master ; fallbackPos::(::) ; /invalidate previous routing symbols
  routingTable::newRT; contextSource::newCS;                                /install new routing table and context source
  hclose each abs drophandles (key h) except routingTable `h ;              /disconnect servants not present in new routing table

  if[canary~(::); canary:([increment:0N;interval:0N]) ];
  cn_increment:: canary `increment; cn_interval:: canary `interval; cn_start::0Np;
  cn_phasein:: $[`phasein in key canary; canary `phasein; (count routingTable)#0b ];
  cn_phaseout:: $[`phaseout in key canary; canary `phaseout; (count routingTable)#0b ] ;
  ed_buffer::routingTable ;
  `ok
 };
drophandles:{ h::h _/ x; h2addr::h2addr _/ x; h2route::h2route _/ x; h2idle::h2idle _/ x; x} ;

/**** connect new servant (used by configuration editor) *****
connectServant:{[route]
  newh: neg hopen hsym route `address ;
  h[newh]:() ;
  h2addr[newh]: {(":" vs string x `address), enlist string x `qfile} route ;
  h2route[newh]: ` ;
  h2idle[newh]: 0Np ;
  newh
 };

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
requestContextSource:{[conditions; routingDescriptor] receiveContextSource conditions} ;
receiveContextSource:{ contextSource::x} ;

/***** Startup ******
/Load Routing Table (afile= file name from command line) 
routingTable:("SSJ*S"; enlist ",") 0: `$":",afile ;        /routing table (host:port|stype|sversion|condition|qfile)
cn_phasein:cn_phaseout: (count routingTable)# 0b ;         /initialize phase in/out bitvectors to 0 of proper length.

requestContextSource[routingTable `condition; routingDescriptor]; /request initial context source

servant: (":" vs/: string routingTable `address);             /servants to be launched by the mserve startup
servant: servant ,' enlist each string routingTable `qfile ;  /append q-file to load.

/Mserve callback provides handles to routing table
readyCallback:{[x] 
  routingTable:: routingTable,'([] h:x) ;
  system "l edconfig.q" ;
 } ;

