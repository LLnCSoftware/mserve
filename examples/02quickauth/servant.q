/simulate opening database upon load by just creating random data
trade:([]time:`time$();sym:`symbol$();price:`float$();size:`int$())
n:3000000
st:09:00:00.000
et:16:00:00.000
portfolio:`GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS
`trade insert (st+n?et-st;n?portfolio;n?100f;n?10000)

/simulate closing database upon exit by just issuing a message
.z.exit:{-1 "servant closed"} ;

/api endpoints
.api.echo:{x} ;

.api.proc1:{[s]do[100;
		res:0!select MAX:max price,MIN:min price,OPEN:first price,CLOSE:last price,
		AVG:avg price,VWAP:size wavg price,DEV:dev price,VAR:var price
		by SYM:sym from trade where sym in s;];
		res
	};

.api.proc2:{[s]do[300;
		res:0!select MAX:max price,MIN:min price,OPEN:first price,CLOSE:last price,
		AVG:avg price,VWAP:size wavg price,DEV:dev price,VAR:var price
		by SYM:sym from trade where sym in s;];
		res
	};


/ provide "secure invocation" protocol

\l secure_invocation.q                   /load the module
.z.pg:{"USE ASYNC"} ;                    /disallow synchronous
.z.ps:validateAndRunAsync;               /use async protocol from secure_invocation.q

0N!"servant loaded" ;
