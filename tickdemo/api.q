/api common to rdb.q and hdb.q

.api.echo:{x} ;
.api.myCommands:{[ignore]  key `.api} 
.api.myTables:{[ignore]
  t:tables[]; db:$[`dbpath in key `.; `$ last "/" vs dbpath; `rdb] ; 
  ([] db:(count t)#db; table:t) ,' raze {select rows:count date, beg:min date+time, end:max date+time from x} each t
 } ;
.api.vwap:{[d;s;w]
  if[0=count d; d: @[;`date] select max date from trade]; if[1=count d; d: raze (d; d)] ;
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


