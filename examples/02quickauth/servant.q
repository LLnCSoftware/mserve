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
  role:getrole req 2;                                   /get user role from request. default to null symbol.
  ex:$[10=type req 1; parse req 1; req 1] ;             /get parsed expression from request
  fn: allowedfn[role] ex 0 ;                            /get function by name from those allowed by role. Null for not found.
  if[null fn; :send[.z.w;] (req 0; 0N!"Error: unknown command: ", string ex 0)];   /reject request when function not found
  send[.z.w] (req 0; @[fn; ex 1; {[e] 0N!"Error: ",(string ex 0), " ", e}]); /run function on first parsed argument, return result or error.    
 };
send:{[h;data] if[h=0; -1 "\nresult:"; :show each data]; (neg h) data} ;  /allows testing from servant console using handle zero.
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

/ Environment Options
if[0<count getenv `Q_PLUGINS; {system "l ", x} each "," vs getenv `Q_PLUGINS] ; /When Q_PLUGINS specified, load listed "q-files".                                                                                 /When Q_SERVANTOF specified,
if[0<count getenv `Q_SERVANTOF;                                                 /When Q_SERVANTOF specified:
 .z.pw:{[u;p] (getenv `Q_SERVANTOF)~ "." sv string `int$ 0x0 vs .z.a};          / accept connectinon only from specified IP.
 .z.po:{.z.pw:{[u;p] 0b}; .z.pc:{exit 0}} ;                                     / accept only single connection, terminate on close
 ];
0N!"servant loaded" ;
