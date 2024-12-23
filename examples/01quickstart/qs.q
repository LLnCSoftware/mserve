/connect and send queries to the demo "servant" via mserve_np.q; display results in console
/sample usage:  q qs.q hostname 5000 [username password]  (host and port of mserve_np, optional log-in credentials)

/ connect to mserve_np.q
h:neg hopen `$":", ":" sv .z.x ;

/Client request: (id; expression)  
qhi:0 ; 
send:{[query] h 0N!(qhi+:1; query) };

/mserve_np response: (id; result; info)
.z.ps:{-1 "ID: ", (string x 0); -1 "--info--"; show x 2; -1 "--result--"; show x 1 ; -1 ""};

.z.ts:{ send["proc1 ", .Q.s1 rand `GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS ] };

-1 "Try a single query:  send[\"proc1 `IBM\"]" ;
-1 "Try a series of queries by setting the timer: \t 3000";	
