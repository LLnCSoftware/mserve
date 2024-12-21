trade:([]time:`time$();sym:`symbol$();price:`float$();size:`int$())
n:3000000
st:09:00:00.000
et:16:00:00.000
portfolio:`GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS
`trade insert (st+n?et-st;n?portfolio;n?100f;n?10000)

.z.pg:{"USE ASYNC"} ;
.z.exit:{-1 "servant closed"} ;
.z.po:{ .z.pc:{exit 0} } ;                /After first connection made, set to exit when it closes.

/request: (id; query)
/response: (id; result)
.z.ps:{[req] /0N!req ;
  ex:$[10=type req 1; parse req 1; req 1] ;  /if query is a string, parse it.
  fn: (value `.api) 0N!ex 0 ;                   /get function given its name at index 0 of the parsed query/
  if[null fn; :(neg .z.w) (req 0; 0N!"Error: unknown command: ", string ex 0)];   /reject anything else
  (neg .z.w) (req 0; @[fn; ex 1; {[e] 0N!"Error: ",(string ex 0), " ", e}]);      /invoke function on argument at index 1 of parsed query
 };                                                                         /respond with id from request, and result or error message.

/api endpoints

.api.proc1:{[s]do[200;
		res:0!select MAX:max price,MIN:min price,OPEN:first price,CLOSE:last price,
		AVG:avg price,VWAP:size wavg price,DEV:dev price,VAR:var price
		by SYM:sym from trade where sym in s;];
		res
	}

.api.proc2:{[s]do[800;
		res:0!select MAX:max price,MIN:min price,OPEN:first price,CLOSE:last price,
		AVG:avg price,VWAP:size wavg price,DEV:dev price,VAR:var price
		by SYM:sym from trade where sym in s;];
		res
	}

0N!"servant loaded" ;
