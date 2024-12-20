/connect and send queries to the demo "servant" via mserve_np.q; results in console
/usage:  q qs.q host port user password

/ connect to mserve_np.q
if[ 2>count .z.x; '"usage: q qs.q host port [user password]"] ;
host: .z.x 0; port: .z.x 1; user: .z.x 2; pw: .z.x 3;

h:neg hopen `$":",host,":",port,":",user,":",pw ;

/Client request: (id; query)  
qhi:0 ; 
send:{[query] h 0N!(qhi+:1; query) };

/mserve_np response: (id; result; info)
.z.ps:{-1 "ID: ", (string x 0); -1 "--info--"; show x 2; -1 "--result--"; show x 1 ; -1 ""};

/.z.ts:{ send["proc1 ", .Q.s1 rand `GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS ] };
.z.ts:{ send["proc1 ", .Q.s1 rand `AAPL`IBM ] };
	
