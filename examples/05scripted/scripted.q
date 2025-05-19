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

/**** Canary Filter ******
cn_increment:0N; cn_interval:0N; cn_start:0Np; 
cn_phasein:`$(); cn_phaseout:`$(); cn_backupRT:(::);
cn_percentage:{0^ cn_increment* 1+ (`long$ .000001* .z.P-cn_start) div cn_interval} ;
canaryFilter:{[tbl] 
  if[ any null (cn_increment; cn_interval); :tbl] ;         /no canary
  if[ all 0= count each (cn_phasein; cn_phaseout); :tbl] ;  /nothing to phase in or out
  if[ (0<cn_increment) and null cn_start; cn_start::.z.P];  /hold at 0% until cn_increment>0 
  new_percentage: cn_percentage[] ;                         /then start phase in/out upon first request.
  /instead of an interval at 0% provide 2 intervals at 100% for better error detection before end of phase in.
  use_new: first 1?100 ; 
  -1 "phase-in ", (string use_new), " < ", (string 100& new_percentage), "%  error ",(string cn_cnterr)," of ",(string cn_maxerr);
  out: $[ use_new < new_percentage; 
    (update condition:(count i)# enlist "0b" from tbl where address in cn_phaseout); /ignore old = use new 
    (update condition:(count i)# enlist "0b" from tbl where address in cn_phasein)   /ignore new = use old
  ];
  if[new_percentage>=100+cn_increment; routingTable::out; endPhaseIn[] ] ; 
  out
 } ;

/**** Canary Failover ******
/ When canary in effect, screen responses for errors. Revert to original config when error count exceeds maximum. 
cn_cnterr: 0 ;
cn_maxerr: 3^ "J"$ getenv `CN_MAXERR ;
filterResponse:{                                          /x= (id; result; info)
  if[(0>=cn_increment) or 0=count cn_phasein; :x] ;       /No canary, 0%, or nothing to phase in -- just return
  if[10<>type x 1; :x; not "ERROR"~ upper 5# x 1; :x];    /Error is a string result strarting with ERROR; no error -- just return
  address:x[2] `qsvr; if[ not address in cn_phasein; :x]; /If servant address not in "cn_phasein" -- just return 
  cn_cnterr+::1; if[cn_cnterr<cn_maxerr; :x] ;            /less than max errors -- just return 
  -1 "failover - cancel phase in" ;
  cancelPhaseIn[] ;   /cancel phase in
  x                   /return response
 } ;

/**** canary termination ********
endPhaseIn:{ cn_phasein::`$(); cn_phaseout::`$(); cn_backupRT::(::) ; 
 cn_increment::0N; cn_interval::0N; cn_start::0Np; -1 "end phase-in"; } ;

cancelPhaseIn:{[]
   update route:` from `queries where location=`master ; fallbackPos::(::) ; 
   if[not cn_backupRT~(::); routingTable::cn_backupRT; -1 "routing table restored";
    hclose each abs drophandles (key h) except routingTable `h;]; endPhaseIn[] ;
 };
drophandles:{ h::h _/ x; h2addr::h2addr _/ x; h2route::h2route _/ x; h2idle::h2idle _/ x; x} ;

finishPhaseIn:{[] 
  update condition:(count i)# enlist "0b" from `routingTable where address in cn_phaseout ; 
  endPhaseIn[] ;
 };

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
routingTable:("SSJ*S"; enlist ",") 0: `$":",afile ;    /routing table (host:port|stype|sversion|condition|qfile)
servant: (":" vs/: string routingTable `address);      /servants to be launched by the mserve startup
servant: servant ,' enlist each string routingTable `qfile ;  /append q-file to load.

/Mserve callback provides handles to routing table
readyCallback:{[x] routingTable:: routingTable,'([] h:x); system "l edconfig.q"} ;

