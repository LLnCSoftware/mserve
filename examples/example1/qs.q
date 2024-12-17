/connect and send queries to the demo "servant" via mserve_np.q; results in console
/sample usage:  q qs.q 5000  (port number of mserve_np)

/ connect to mserve_np.q
port:$[0=count .z.x 0; 5000; "J"$ .z.x 0] ;
h:neg hopen port;

/Client request: (id; expression)  
qhi:0 ; 
send:{[query] h 0N!(qhi+:1; query) };

/mserve_np response: (id; result; info)
.z.ps:{-1 "ID: ", (string x 0); -1 "--info--"; show x 2; -1 "--result--"; show x 1 ; -1 ""};

.z.ts:{ send["proc1 ", .Q.s1 rand `GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS ] };

-1 "Try a single query:  send[\"proc1 `IBM\"]" ;
-1 "Try a series of queries by setting the timer: \t 2000";	
