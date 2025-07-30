/ rdb - realtime database
/ usage: q rdb.q schema log -p port


\l tick/tplog.q                       /module to load back data from log files
system "l ", "tick/",(.z.x 0),".q"    /table schema needed to accept data from log files.

\l api.q                              /api common to rdb and hdb
\l ../secure_invocation.q
.z.ps:{
  if[cons; 0N!(.z.w; x 0; x 1; count x 2)];  /log to console
  if[.z.w in (0i;h); :value x];              /if subscription or log replay, just process it.
  if[`endofdayok~x 0; :endofdayok x 1];      /if special message `endofdataok, just process it.
  if[`go~x 0; :0 x] ;                        /allow startup without feed.q (invoke manually from mserve console).
  validateAndRunAsync x                      /process query via secure_invocation.q
 } ;
.z.pg:{"Use Async"} ;

/receive tick data
startup:1b ; cons:1b ; 
upd:{[t;x]
  if[.z.w=0; t:`$ (string t),"_t"] ; /upd from handle zero is log replay, store in temporay table
  insert[t;x] ; 
  if[startup; 0 (`go;0)] ;
 };

/startup

quote_t: quote ;    /temporary tables for log replay, same schema
trade_t: trade ;
h: hopen 5001 ;     /subscribe to tick.q - all tables all symbols.
h ".u.sub[`;`]" ;

go:{
 qlo: (first quote) `id ;
 tlo: (first trade) `id ;
 if[x; qlo: 0W^qlo; tlo: 0W^tlo] ;
 0N!(x; qlo; tlo) ;
 if[(null qlo) or (null tlo); :(::)] ;
 startup::0b ;

 rep[-2; 0] ;        /begin replaying log files
 system "sleep 4" ;  /simulate long replay

 quote:: (select from quote_t where id< qlo), quote ;
 trade:: (select from trade_t where id< tlo), trade ;
 quote[`sym]: `g# quote `sym ;
 quote[`id]:  `u# quote `id  ;
 trade[`sym]: `g# trade `sym ;
 trade[`id]:  `u# trade `id ;
 if[servantof>0; (neg servantof) (-1; `initdate; (max trade `date) & max quote `date)] ; 
 cons::0b ;
 -2 "\n*** rdb ready ***\n" ;
 };


/.u.end is called as part of the usual subscription processing in tick.q.
/Note when .u.end is called NEXT burst of data will be for new day.
/Call back to tickdemo.q to restart hdb processes to incorporate new data.
.u.end:{[dat] -2 "end of day: ", string dat;  mserve_handle (-1; `endofday; dat)} 

/purge data in rdb from any days prior to the day before the day that just ended.
/this is called via a "special message" tickdemo.q AFTER hdb processes have been restarted
endofdayok:{[dat] 
  -2 "end of day ok: ", string dat ;
  delete from `quote where date< -1+ dat ;
  delete from `trade where date< -1+ dat ;
 } ;


/util
inter2ms:{t:last x; v:"J"$ -1_ x; $[t="s";1000*v; t="m";60000*v; t="h";60*60000*v; t="d";24*60*60000*v; "J"$x]} ;


