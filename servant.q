trade:([]time:`time$();sym:`symbol$();price:`float$();size:`int$())
n:3000000
st:09:00:00.000
et:16:00:00.000
portfolio:`GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS
`trade insert (st+n?et-st;n?portfolio;n?100f;n?10000)

.z.pg:{"USE ASYNC"} ;
.z.exit:{-1 "servant closed"} ;

/request: (id; query; options)
/response: (id; result)
.z.ps:{ 
  role:$[99=type x 2; (x 2) `role; `];
  ex:$[10=type x 1; parse x 1; x 1] ;
  fn: {$[0=count x; (::); x]} allowedfn[role] ex 0 ;
  if[null fn; :send[.z.w;] (x 0; 0N!"Error: unknown command: ", string ex 0)];
  send[.z.w] (x 0; @[fn; ex 1; {[e] 0N!"Error: ",(string ex 0), " ", e}]);
 };
send:{[h;data] if[h=0; -1 "\nresult:"; :show each data]; (neg h) data} ;
allowedfn:{[role] (system "f")# value `.} ;

/api endpoints

proc1:{[s]do[200;
		res:0!select MAX:max price,MIN:min price,OPEN:first price,CLOSE:last price,
		AVG:avg price,VWAP:size wavg price,DEV:dev price,VAR:var price
		by SYM:sym from trade where sym in s;];
		res
	}

proc2:{[s]do[800;
		res:0!select MAX:max price,MIN:min price,OPEN:first price,CLOSE:last price,
		AVG:avg price,VWAP:size wavg price,DEV:dev price,VAR:var price
		by SYM:sym from trade where sym in s;];
		res
	}

/Specify env: KDBQ_PLUGINS=authoriz.q to authorize based on permissions table (overides allowedfn).
{system "l ",x} each {$[0=count x; (); "," vs x]} getenv `KDBQ_PLUGINS
0N!"servant loaded" ;
