/
This client will connect to the master process and send a query
sample usage:q client.q -master 5000
\

args:.Q.opt[.z.x];
args[`sym]:first`$args[`sym];
args[`master]:first"J"$args[`master];

/res will be a list containing all the result sets
results:([id:`int$()] 
  rep:`int$();           /repetition factor
  query:();              /query expression
  route:`$() ;           /routing symbol
  elapsed:`int$();       /elapsed time (includes time in mserve queue)
  execution:`int$();     /execution time (excludes time in mserve queue) 
  servant:`$();          /servant address used
  start:`time$();        /start time for calculating "elapsed"
  result:()              /saved result
 );

/ connect to mserve_np.q
h:neg hopen args[`master];

/Client request: (id(int); callback(symbol); expression(string); rep)
queryid: 0 ;
sendRR:{[rep; route; query]  
  `results upsert `id`rep`query`route`start!(queryid+:1; rep; query; route; .z.T) ;
  -1 "send: id=",(string queryid), " route=", (string route), " rep=", (string rep), "query=", query ;
  h (queryid; `receive; query; rep; route) 
 };
sendR: sendRR[1;] ;    /sendR[route;query]
send: sendRR[1;`;] ;   /send[query] ;

/mserve_np callback
receive:{[aid; aexecution; aservant; aresult]
  -1 "receive: id=", (string aid) ;
  update elapsed:`int$ .z.T-start, execution:aexecution, servant:aservant, result:aresult from `results where id=aid ;
  -1 "--info--"; show `result _ results[aid]; -1 "--result--"; show results[aid;`result] ; -1 "";
 };

/example client query:
sendR[`ibm; "proc1 `IBM"] ;  /send[route; query]

.z.ts:{ send["proc1 ", .Q.s1 rand `GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS ] };
	
/\t 500	
