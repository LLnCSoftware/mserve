/
This client will connect to the master process and send a query
sample usage:q client.q -master 5000
\

args:.Q.opt[.z.x];
args[`master]:first"J"$args[`master];

/ connect to mserve_np.q
h:neg hopen args[`master];

/Client request: (id(int); callback(symbol); expression(string)
queryid: 0 ;
send:{[query]  
  -1 "send: id=",(string queryid), " query=", query ;
  h (queryid; `receive; query) 
 };

/mserve_np callback
receive:{[qid; qresult; qinfo]
  -1 "receive: id=", (string qid); 
  -1 "--info--"; show qinfo; -1 "--result--"; show qresult ; -1 "";
 };

/example client query:
/send["proc1 `IBM"] ;  /send[route; query]

/.z.ts:{ send["proc1 ", .Q.s1 rand `GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS ] };
.z.ts:{ send["proc1 ", .Q.s1 rand `AAPL`IBM ] };
	
