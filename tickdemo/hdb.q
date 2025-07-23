
/ populate hdb
/writedb:{ .Q.dpft[`:data/db; 2025.07.01; `sym; ] each `quote`trade; } ;

\l tick/tplog.q                       /module to load back data from log files
system "l ", "tick/",(.z.x 0),".q"    /table schema needed to accept data from log files.

/ query rdb
.api.echo:{x} ;
.api.lcommands:{ key `.api} ;
.api.ltables:{ {(x; count get x)} each tables[] } ;
.api.vwap:{select trades:count i, sum size, vwap:size wavg price by sym, (inter2ms x) xbar time from trade} ;

/ interface
\l ../secure_invocation.q
.z.ps:{if[.z.w=0i; :value x]; validateAndRunAsync x} ;

/On startup, populate hdb with log files 1 day old but not yet ingested.
rep[-100; -2] ;

upd:{[t;x] 



/util
inter2ms:{t:last x; v:"J"$ -1_ x; $[t="s";1000*v; t="m";60000*v; t="h";60*60000*v; t="d";24*60*60000*v; "J"$x]} ;

