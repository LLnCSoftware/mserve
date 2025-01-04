/simulate opening database upon load by creating random data
trade:([]time:`time$();sym:`symbol$();price:`float$();size:`int$())
n:3000000
st:09:00:00.000
et:16:00:00.000
portfolio:`GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS
`trade insert (st+n?et-st;n?portfolio;n?100f;n?10000)

/simulate closing database upon exit by issuing a message to stdout
.z.exit:{-1 "servant closed"} ;           

/api endpoints that runs a query 100 times

proc1:{[s]do[100;
		res:0!select MAX:max price,MIN:min price,OPEN:first price,CLOSE:last price,
		AVG:avg price,VWAP:size wavg price,DEV:dev price,VAR:var price
		by SYM:sym from trade where sym in s;];
		res
	}

/same as proc1 but with 400 iterations

proc2:{[s]do[400;
		res:0!select MAX:max price,MIN:min price,OPEN:first price,CLOSE:last price,
		AVG:avg price,VWAP:size wavg price,DEV:dev price,VAR:var price
		by SYM:sym from trade where sym in s;];
		res
	}

/adapt for use with mserve

.z.pg:{"USE ASYNC"} ;          /disallow synchronous IPC
.z.po:{ .z.pc:{exit 0} } ;     /After connection made, set to exit upon close. (shutdown all servants along with mserve)
  
/implement calling convention: request=(id; query) response=(id; result)
.z.ps:{[req] (neg .z.w) (req 0; @[value; req 1; {[e] 0N!"Error: ",(.Q.s1 req), " ", e}]) };

0N!"servant loaded" ;
