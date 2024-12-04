/connect and send queries to the demo "servant" via mserve_np.q; results in console
/sample usage:  q qs.q 5000  (port number of mserve_np)

/ connect to mserve_np.q
port:$[0=count .z.x 0; 5000; "J"$ .z.x 0] ;
h:neg hopen port;

/Client request: (id; callback; expression) example: send["proc1 `IBM"] 
qhi:0 ; 
send:{[query] h 0N!(qhi+:1; `receive; query) };

/mserve_np callback
receive:{[qid; qresult; qinfo] -1 "ID: ", (string qid); -1 "--info--"; show qinfo; -1 "--result--"; show qresult ; -1 "";};

/.z.ts:{ send["proc1 ", .Q.s1 rand `GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS ] };
.z.ts:{ send["proc1 ", .Q.s1 rand `AAPL`IBM ] };
	
