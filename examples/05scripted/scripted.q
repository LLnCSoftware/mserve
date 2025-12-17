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
receiveContextSource:{contextSource::x} ;

/ContextValues by default evaluates the boolean expressions from the routing table in a namespace
/The following function creates that namespace from the dictionary returned by getRoutingCriteria.
makens:{[ns;dict](` sv `,ns) set ((`,key dict)!(::),value dict)}; 

check:{[]
  /compute "route" for new requests as a bit vector selecting matching rows from the dispach table.
  upd: validateRouting exec qid!routingBitVector'[qid;query;client_options] from queries where 0=count each route ;
  update route: upd[qid] from `queries where qid in key upd ;  
  
  /For each enqueued query, find the first matching row corresponding to a not-busy handle 
  notbusy: enlist notbusyBitVector[] ;
  hit: select qid, rtRow:first each where each (route and' ((count qid)#notbusy)) from queries where location=`master ;
  hit: select from hit where not null rtRow ;
  if[0<count hit; qid:(hit 0)`qid; hdl:(routingTable `h) (hit 0)`rtRow; send_query[hdl; qid]] ;
 };

/Return an error response to client when no server qualifies for the request
validateRouting:{[upd]
   err: where {all x=0} each upd ;
   send_result[;"Error: No qualifying server"; (::)] each err ;
   upd
 };


/Trap error obtaining routing bit vector
routingBitVector:{[qid;qry;opt] 
  .[routingBitVector1; (qry;opt); {send_result[x; 0N!"Error: Routing failed '", y; (::)]; (count routingTable)#0b}[qid;] ] 
 };

/Obtain variables for substitution from "getRoutingCriteria"
/Substitute into "condition" field to evaluate the boolean expressions.
/Return bit vector corresponding to routingTable rows, where 1 means "ok for this query".
routingBitVector1:{[qry;opt]
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
/Handles which are null in the routing table will also be mapped to an empty list, but are not currently available.
/Return bit vector corresponding to routingTable rows, where 1 means "not busy" and "available"
notbusyBitVector:{ (0= count each h routingTable `h) and (not null each routingTable `h) };

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
canaryFailover:{                                          
  if[(0>=cn_increment) or all cn_phasein=0b; :x] ;        /No canary, 0%, or nothing to phase in -- just return
  if[10<>type x 1; :x; not "ERROR"~ upper 5# x 1; :x];    /Error is a string result strarting with ERROR; no error -- just return
  phasein: (routingTable `address) where cn_phasein ;     /Get phase in addresses from routing table
  address:x[2] `qsvr; if[not address in phasein; :x];     /If servant address not included -- just return 
  cn_cnterr+::1; if[cn_cnterr<cn_maxerr; :x] ;            /less than max errors -- just return 
  -1 "\n*****\n failover - hold at 0%\n*****\n" ;
  cn_increment::0; cn_start::0Np; 
  x                   /return response
 } ;
filterResponse:canaryFailover ;                    

/**** servant managment - for configuration editor and restarting serants *****
/ The original mserve_np.q would sleep for 5 seconds after launching its servants.
/ That was ok when servants were only launched at startup, but to support hot editing
/ of the routing table, servants need to start up while queries are being processed,
/ and its not acceptable to to pause dispatch for that long.
/ There will still be a 5 second pause at startup, but when servants are launched
/ after startup, the pause will be implemented using the timer, not sleep.

/ "launchAll" will launch new servants from a subset of the routing table,
/ replacing the previous handle in the specified routing object (not the live routing table)
/ with the launcher handle for each remote host, or null for localhost.
/ The routing object is returned so that it can be passed to "connectAll" 
/ after waiting 5 seconds on the timer. 

/ "connectAll" will close any handles >0 in the specified routing object
/ It will then obtain new handles for all servants via hopen, which will be set in the (live) routing table.

launchAll:{[routing]
  servants: {(":" vs string x `address), enlist string x `qfile} each routing ; 
  hh: launch each servants ;  
  update h:hh from routing
 };

connectAll:{[routing]
   -2 "connect to ",(string count routing), " newly launched instances" ;
   hclose each abs (routing `h) where 0< routing `h ;
   hdl:connectServant each routing ;
   update h:hdl from `routingTable where address in (routing `address) ;
 };

/connect new servant
connectServant:{[route]
  newh: neg hopen 0N!hsym route `address ;
  h[newh]:() ;
  h2addr[newh]: {(":" vs string x `address), enlist string x `qfile} route ;
  h2route[newh]: enlist () ;
  h2idle[newh]: 0Np ;
  newh
 };

/***** Startup ******
/Load Routing Table (afile= file name from command line) 
/Note: The scripted dispatch method uses a alternate form of the mserve_np.q command line
/which specifies the routing table csv file ("afile") instead of a number of servers, and a server launch command.
/This alternate form is recognized by having only a single argument on the command line. 
/Having only a single argument precludes adding available remote hosts as additional arguments.
/However, with scripted dispatch the host for each servant is provided in the routing table, so that is not necessary.
/A more serious limitation is that there seems to be no way to supply arguments to the servers for such things
/as the location of the database, except in the routing table csv file itself.
/To allow servant arguments on the mserve command line we typically combine them with the servant path
/in a single quoted argument: mserve_np.q 3 'server.q arg1 arg2.. '. 
/We can do the same thing with scripted dispatch: mserve_np.q mserve_np.q 'routing.csv arg1 arg2.. '.
/Except here the additional arguments specify substitutions to be made into the routing table.
/This is used in the tickdemo to allow rdb to startup without data comming in from feed.q.
/The rdb lines in the routing table will specify the port to connect to tick.q as $tick$,
/and the command line will be mserve_np.q 'routingtable.csv tick=' to override the default of 5001'

/ Allow subsitituions specified on command line in the routing table
substitute:{[expr]
  arg: " " vs afile ;
  if[2>count arg; :expr] ;
  k: {(x?"=")#x} each 1_ arg ;
  v: {(1+ x?"=")_ x} each 1_ arg ;
  k: {if["$"<>first x; x:"$",x]; if["$"<>last x; x:x,"$"]; x} each k ;
  {[d;e;x] ssr[e; x; $[x in key d; d x; x]]}[k!v;]/ [expr; k]
 };

routingTable: read0 `$":", resolve[getenv `LAUNCHQ_BASE] {(x?" ")#x} afile ; /read routing table from csv 
routingTable: ("SSJ*S"; enlist ",") 0: substitute each routingTable ;

servant: (":" vs/: string routingTable `address) ,' enlist each (string routingTable `qfile) ;
hosts: {$[x in ("localhost";"127.0.0.1");"";x]} each  distinct first (flip servant)
cn_phasein:cn_phaseout: (count routingTable)# 0b ; /initialize phase in/out bitvectors to 0 of proper length.

show routingTable ; 
requestContextSource[routingTable `condition; routingDescriptor]; /request initial context source

/Mserve callback provides handles to routing table
/To allow loading the configuration editor before that occurs we must avoid initializing
/the editor state until after the handles are added to the routing table. The confguration
/editor will override the "initialize" method for that purpose.
initialize:{} ;
readyCallback:{[x] 
  routingTable:: routingTable,'([] h:x) ;
  initialize[] ;
 } ;
