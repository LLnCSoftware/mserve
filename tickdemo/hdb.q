\l tick/tplog.q                       /module to load back data from log files
system "l ", "tick/",(.z.x 0),".q";   /table schema needed to accept data from log files.
dbpath: .z.x 2 ;                      /Arguments: schema, log, db (path to hdb directory.

/ query rdb
.api.echo:{x} ;
.api.lcommands:{ key `.api} ;
.api.ltables:{ {(x; count get x)} each tables[] } ;
.api.vwap:{select trades:count i, sum size, vwap:size wavg price by sym, date, (inter2ms x) xbar time from trade} ;

/ interface
\l ../secure_invocation.q
.z.ps:{if[.z.w=0i; :value x]; validateAndRunAsync x} ;

/startup
/Override repDayEnd in tplog.q to append each complete day to database
repDayEnd:{[date] repDayEndTable[date;] each tables[] ;} 
repDayEndTable:{[d;t]
 /-2 "Write table ", (string t), " to date ", string d ;
 symrows: group t `sym ;                     /get row indexes for each symbol
 parted: t raze value symrows;               /get table parted on sym column.
 directory: `$":", dbpath, "/", (string d), "/", (string t), "/" ;
 directory set .Q.en[`$":",dbpath;] parted;  /write table to new partition
 @[directory; `sym; `p#] ;                   /set parted attribute on sym
 @[directory; `id; `u#] ;                    /set unique attribute on id
 t set 0# get t ;                            /clear table for next date
 };

/locate database - expect it to be partitioned by date.
if[0=count dbpath; '"Usage: q hdb.q schema log database-path"];
ls: key `$":", dbpath ;

/start date to load is day after latest per-day directory
start: max "D"$ string ls where ls like "[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]" ;
start: $[start=-0Wd; -3650; start+1]  /if database empty load up to 10 years 
-2 "Start replay at: ", string start ;

/replay log files
upd:insert ;
rep[start; -2] ; 

/when replay finished
![`.; (); 0b; tables[]];   /delete all tables
system "l ", dbpath  ;     /load the partitioned database on disk
-2 "Database ", dbpath, " opened" ;


/util
inter2ms:{t:last x; v:"J"$ -1_ x; $[t="s";1000*v; t="m";60000*v; t="h";60*60000*v; t="d";24*60*60000*v; "J"$x]} ;

