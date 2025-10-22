/api common to rdb.q and hdb.q
/Arguments: schema, log, [ dbpath ]
lastdate: {$[x=-0Wd; 0Nd; x]} max "D"$ -10#/: @[system; "ls ", (.z.x 1),"/", (.z.x 0), "*"; ()] ;

.api.echo:{x} ;
.api.myCommands:{[ignore]  key `.api} 
.api.myTables:{[ignore]
  t:tables[]; db:$[`dbpath in key `.; `$ last "/" vs dbpath; `rdb] ; 
  ([] db:(count t)#db; table:t) ,' raze {select rows:count date, beg:min date+time, end:max date+time from x} each t
 } ;
.api.vwap:{[d;s]
  if[0=count d; d: @[;`date] select max date from trade]; if[1=count d; d: raze (d; d)]; d:int2date d;
  if[s~`; :select trades:count i, sum size, vwap:size wavg price by sym from trade where date within d]; 
  select trades:count i, sum size, vwap:size wavg price by sym from trade where date within d, sym in s
 } 
.api.vwapd:{[d;s;w]
  if[0=count d; d: @[;`date] select max date from trade]; if[1=count d; d: raze (d; d)]; d:int2date d;
  if[s~`; :select trades:count i, sum size, vwap:size wavg price by sym, w xbar date from trade where date within d]; 
  select trades:count i, sum size, vwap:size wavg price by sym, date, w xbar date from trade where date within d, sym in s
 } ; 
.api.vwapt:{[d;s;w]
  if[-11=type w; w:string w] ;        /accept time window as string or symbol
  if[10<>type w; '"time window for vwapt must be string or symbol - number with suffix for unit"] ;
  if[0=count d; d: @[;`date] select max date from trade]; if[1=count d; d: raze (d; d)]; d:int2date d;
  if[s~`; :select trades:count i, sum size, vwap:size wavg price by sym, date, (inter2ms w) xbar time from trade where date within d]; 
  select trades:count i, sum size, vwap:size wavg price by sym, date, (inter2ms w) xbar time 
  from trade where date within d, sym in s
 } ; 

/utilities
str:{$[10=type x ; x; string x]} ;
inter2ms:{ /accept an interger as ms, or a string containing a suffixed integer as "seconds", "minutes", "hours" or "days"
  if[10<>abs type x; :"j"$x]; x:raze x; t:last x; v:1^"J"$ -1_ x; 
  $[t="s";1000*v; t="m";60000*v; t="h";60*60000*v; t="d";24*60*60000*v; "J"$x]
 } ;
int2date:{ /when date specified as integer, take as offset from lastdate
  if[14=(abs type x); :x] ;
  if[(abs type x) within (5 7); :(neg abs x)+lastdate] ;
  '"Date or integer range expected, got: ", .Q.s1 x ;  
 };



