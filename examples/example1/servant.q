trade:([]time:`time$();sym:`symbol$();price:`float$();size:`int$())
n:3000000
st:09:00:00.000
et:16:00:00.000
portfolio:`GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS
`trade insert (st+n?et-st;n?portfolio;n?100f;n?10000)

.z.pg:{"USE ASYNC"} ;
.z.exit:{-1 "servant closed"} ;
.z.po:{ .z.pc:{exit 0} } ;             /Once connection opened, set to terminate on close (allow other connections for debugging)
/.z.po:{ .z.pw:{0b}; .z.pc:{exit 0}};  /More secure. Allow only a single connection.

/request: (id; query)
/response: (id; result)
.z.ps:{[req] 
  ex:$[10=type req 1; parse req 1; req 1] ;    /parse the query when it is a string 
  fn: functions ex 0 ;                         /get the function given its name
  if[null fn; :(neg .z.w) (req 0; 0N!"Error: unknown command: ", string ex 0)];   /reject anything else
  (neg .z.w) (req 0; @[fn; ex 1; {[e] 0N!"Error: ",(string ex 0), " ", e}]);      /invoke function with its single argument
 };                                                                               /return result or error with same id from request.

/api endpoints

proc1:{[s]do[100;
		res:0!select MAX:max price,MIN:min price,OPEN:first price,CLOSE:last price,
		AVG:avg price,VWAP:size wavg price,DEV:dev price,VAR:var price
		by SYM:sym from trade where sym in s;];
		res
	}

proc2:{[s]do[400;
		res:0!select MAX:max price,MIN:min price,OPEN:first price,CLOSE:last price,
		AVG:avg price,VWAP:size wavg price,DEV:dev price,VAR:var price
		by SYM:sym from trade where sym in s;];
		res
	}

functions: (system "f")# value `. ;   /dictionary of all functions in main namespace
0N!"servant loaded" ;
