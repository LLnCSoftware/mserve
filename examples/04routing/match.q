/attempt to send query to a servent with same routing symbol 
/otherwise attempt to send first query to a servant with an unset or expired routing symbol
/otherwise request call on the timer

/This dispatch algorithm makes use of the following services provided in mserve_np.q
/1. function "getArguments" which parses a q expression, always interpreting symbols as literals, not as variable names.
/2. dictionary "h" mapping each handle to the list of queries pending on that handle
/3. dictionary "h2route" mapping each handle to its last routing symbol
/4. dictionary "h2idle" mapping each handle to its idle timestamp.
/5. timestamp "nextCheck" which schedules a call to "check" on the timer.
/6. function "addMs" which adds milliseconds to a timestamp

algo: enlist "match-plugin" ;              /plugin name and options (no options in this case)
routeExpireMs:12000 ;                      /handles allowed to change routes after this many idle ms
getRoutingSymbol:{(getArguments x) 1} ;    /use first argument to api command as routing symbol (start of date range).
check:{[]
  nextCheck::0Wp ; /disable call on timer

  /compute routing symbol for any queries which lack it
  update route:getRoutingSymbol each query from `queries where location=`master, null route ;

  /dispatch first enqueued query for which some non-busy handle has the same routing symbol, to the first such handle
  match: select qid, hdl:{first (where x in/: h2route) inter (where 0=count each h) } each route from queries where location=`master ;
  match: select from match where not null hdl ;
  if[0<count match; 0N!(`match; match[0;`qid]; match[0;`hdl]); :send_query[ match[0;`hdl]; match[0;`qid] ]]  

  /dispactch first enqueued query for which no handle has the same routing symbol
  /to first non-busy handle whos routing symbol is unset or expired
  qry: exec first qid from queries where location=`master, not route in raze h2route ;
  hdl: first where (0=count each h) and h2idle< addMs[neg routeExpireMs;.z.P] ;
  if[(not null qry) and not null hdl; 0N!(`claim; qry; hdl); :send_query[hdl; qry] ];

  /If queue not empty, but nothing dispatched, request call on timer (wait for some routing string to expire)
  if[`master in (value queries) `location; 
    nextCheck:: addMs[routeExpireMs; min .z.P, value h2idle]; 0N!(`wait; qry; tms nextCheck-.z.P)
  ]
 };



