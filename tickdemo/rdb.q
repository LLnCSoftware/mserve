/ rdb - realtime database
/ usage: q rdb.q schema log tickport -p port


\l tick/tplog.q                       /module to load back data from log files (this uses args 0 and 1)
system "l ", "tick/",(.z.x 0),".q";   /table schema needed to accept data from log files.
tickport: .z.x 2 ;                    /port on to subscribe to tick.q (if blank run without tick.q).

\l api.q                              /api common to rdb and hdb
\l ../secure_invocation.q
.z.ps:{
  if[cons; 0N!(.z.w; x 0; x 1; count x 2)];  /log to console
  if[.z.w in (0i;h;hfs); :value x];          /if subscription or log replay, just process it.
  if[`startofday~x 0; :startofday[x 1]];     /if special message `startofday, purge data more than 2 days old.
  if[`finishSync~x 0; :`go2[]];              /if special message `finishSync, continue startup after syncing log
  if[`go~x 0; :0 x] ;                        /allow startup without feed.q (invoke manually from mserve console).
  validateAndRunAsync x                      /process query via secure_invocation.q
 } ;
.z.pg:{"Use Async"} ;

/receive tick data
startup:1b ; cons:0b ; 
upd:{[t;x]
  if[.z.w<>h; t:`$ (string t),"_t"] ; /upd from handle zero (or hfs) is log replay, store in temporay table
  insert[t;x] ; 
  if[startup; 0 (`go;0)] ;
 };

/startup
h:0Ni ;
if[ not ""~tickport;
  h: hopen `$":",(getenv `Q_SERVANTOF),":",tickport ;     /subscribe to tick.q - all tables all symbols.
  h ".u.sub[`;`]" ;
 ];

quote_t: quote ;    /temporary tables for log replay, same schema
trade_t: trade ;

hh:0Ni; hfs:0Ni ;
h_servantof:0Ni ;
servantof:{h_servantof:: x} ;
go:{
 qlo: (first quote) `id ;
 tlo: (first trade) `id ;
 if[x; qlo: 0W^qlo; tlo: 0W^tlo] ;
 if[(null qlo) or (null tlo); :(::)] ;
 startup::0b ;

 /Attempt to open port 5999 on localhost. On a remote host this should be launcher.q
 /On local host (the mserve machine) there should be no launcher and this should fail.
 /In that case continue with "go2" below.
 /Otherwise send the "requestSync" message to launcher.q
 /Which will respond with the "finishSync" message, when fresh copy of tick.q log has been made, using "rsync".
 /The "finishSync" message just invokes "go2" below, as in the local case.
 /Note we do this AFTER receving the first record by subscription, which should ensure that the first subscription
 /record will also be in the log, and so we have overlap rather than a gap between the log and subscription data.
 hh:@[hopen; 5999; 0Ni]; if[null hh;  :go2[]] ;
 -1 "starting remote rdb: sync log directory" ;
 (neg hh) (`requestSync; 0); (neg hh)[]; 
 };

go2:{
 hfs::.z.w;
 qlo: 0W^(first quote) `id ;
 tlo: 0W^(first trade) `id ;
 if[not null hh; hclose hh; hh::0Ni] ;

 -1 "Load back data into rdb from log directory" ;
 rep[-2; 0] ;        /begin replaying log files
 system "sleep 4" ;  /simulate long replay

 quote:: (select from quote_t where id< qlo), quote ;
 trade:: (select from trade_t where id< tlo), trade ;
 delete quote_t from `. ;
 delete trade_t from `. ;
 quote[`sym]: `g# quote `sym ;
 quote[`id]:  `u# quote `id  ;
 trade[`sym]: `g# trade `sym ;
 trade[`id]:  `u# trade `id ;
 if[h_servantof>0; (neg h_servantof) (-1; `initdate; (max trade `date) | max quote `date)] ; 
 cons::0b ; hfs::0Ni ;
 -2 "\n*** rdb ready ***\n" ;
 };

/.u.end is called as part of the usual subscription processing in tick.q.
/Note when .u.end is called NEXT burst of data will be for new day.
/Call back to tickdemo.q to restart hdb processes to incorporate new data.
.u.end:{[dat] -2 "\nend of day: ", string dat; (neg h_servantof) (-1; `endofday; dat)} 

/Purge data in rdb from any earlier than 2 days prior to the current date - retaining the most recent 3 days in the rdb.
/Note: This occurs after both hdbA and hdbB instances have been restarted and have presumably ingested this data.
startofday:{[dat] 
  -2 "\nrdb startofday: ", string dat ;
  delete from `quote where date< -2+ dat ;
  delete from `trade where date< -2+ dat ;
 } ;

/util
inter2ms:{t:last x; v:"J"$ -1_ x; $[t="s";1000*v; t="m";60000*v; t="h";60*60000*v; t="d";24*60*60000*v; "J"$x]} ;

if[""~tickport; go 1] ; /if no tick, don't wait for feed

