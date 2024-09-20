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
send:{[rep; query]  
  `results upsert `id`rep`query`start!(queryid+:1; rep; query; .z.T) ;
  -1 "send: id=",(string queryid), " rep=", (string rep), "query=", query ;
  h (queryid; `receive; query; rep) 
 };

/mserve_np callback
receive:{[aid; aexecution; aservant; aresult]
  -1 "receive: id=", (string aid) ;
  update elapsed:`int$ .z.T-start, execution:aexecution, servant:aservant, result:aresult from `results where id=aid ;
  -1 "--info--"; show `result _ results[aid]; -1 "--result--"; show results[aid;`result] ; -1 "";
 };

/example client query:
send[1; "proc1 `IBM"] ;  /send[rep; query]

.z.ts:{ send[1; "proc1 ", .Q.s1 rand `GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS ] };
	
/\t 500	
