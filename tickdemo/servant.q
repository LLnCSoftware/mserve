/ populate rdb
h: hopen 5001 ;
h ".u.sub[`;`]" ;
upd:insert ;

/ populate hdb


/ query rdb
.api.echo:{x} '
.api.lcommands:{ key `.api} ;
.api.ltables:{ {(x; count get x)} each tables[] } ;
.api.vwap:{select trades:count i, sum size, vwap:size wavg price by sym, (onems*w2ms x) xbar time from trade}

/ interface
\l ../secure_invocation.q
.z.ps:{if[.z.w=h; :value x]; validateAndRunAsync x} ;

/-----------------
onems: `long$ 1e6 ;
w2ms:{[w] 
  n:type w; w:`long$ w; 
  if[n within (-7;-5); :w]; if[n=-18; :1000*w]; if[n=-17; :60000*w]; 
  '"window size type error: expect integer (ms), second (h:m:s), or minute (h:m)"; 
 };


/system "t 10000" ;
