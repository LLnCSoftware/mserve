/connect and send queries to the demo "servant" via mserve_np.q; results in console
/usage:  q qs.q portnumber username password

/ connect to mserve_np.q
port:$[0=count .z.x 0; 5000; .z.x 0] ;
user:.z.x 1; pw: .z.x 2;

h:neg hopen `$"::",port,":",user,":",pw ;

/Client request: (id; callback; expression) example: send["proc1 `IBM"] 
qhi:0 ; 
send:{[query] h 0N!(qhi+:1; query) };

/mserve_np response: (qid; result; info)
.z.ps:{-1 "ID: ", (string x 0); -1 "--info--"; show x 2; -1 "--result--"; show x 1 ; -1 ""};

/.z.ts:{ send["proc1 ", .Q.s1 rand `GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS ] };
.z.ts:{ send["proc1 ", .Q.s1 rand `AAPL`IBM ] };
	
