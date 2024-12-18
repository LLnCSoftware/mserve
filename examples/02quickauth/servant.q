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
.z.ps:{[req] /0N!req ;
  role:getrole req 2;
  ex:$[10=type req 1; parse req 1; req 1] ;
  fn: {$[0=count x; (::); x]} allowedfn[role] ex 0 ;
  if[null fn; :send[.z.w;] (req 0; 0N!"Error: unknown command: ", string ex 0)];
  send[.z.w] (req 0; @[fn; ex 1; {[e] 0N!"Error: ",(string ex 0), " ", e}]);
 };
send:{[h;data] if[h=0; -1 "\nresult:"; :show each data]; (neg h) data} ;
getrole:{[opt] $[99=type opt; opt `role; `]} ;   /overidden in authent.q
allowedfn:{[role] value `.api} ;                 /overidden in authriz.q

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

/Specify env: KDBQ_PLUGINS=authoriz.q to authorize based on permissions table (overrides allowedfn).
{system "l ",x} each {$[0=count x; (); "," vs x]} getenv `KDBQ_PLUGINS
0N!"servant loaded" ;
