/**** Stuff that would be in scripted.q *****

/ dummy data
buffer:([] address:`$ "localhost:",/: string  5000+ 1+til 20;
  stype: 20# `local:servA ;
  sversion: 20?(1 1 2 1) ;
  condition:  "boolean expression ",/: string 1+til 20;
  qfile: 20# `servant.q; 
  h:neg 5+til 20
 );
update qfile:`servantbad.q from `buffer where sversion=2 ; 

/canary control variables
cn_phasein:`$() ;
cn_phaseout: `$() ;

/utilities
moveItemInList:{[data;fr;to] 
  fr:0|fr-1; to:0|to-1; /one based
  en:count data; fr&:en-1; to&:en-1; if[fr=to; :data];
  a:til fr&to; b:fr&to; d:fr|to; c:1+b+til d-b+1; e:1+d+til en-d+1;
  data raze $[fr<to; (a;c;d;b;e); (a;d;b;c;e)]
 };  

/**** search or browse the editBuffer ****

/ convert buffer for human consumption
/ add 1-based position column, remove handle column.
pos:{([] pos:1+til count x),'delete h from x} ;

/ Allow user to search the buffer by specifying "where clauses" for a functional select
/ Example: search ("address like \"localhost:*\"; "sversion=2") 
search:{
  if[10=type x; x:enlist x] ;
  if[0<>type x; :"ERROR: strings expected"] ;
  if[any 10<> type each x; :"ERROR: strings expected"] ;
  w: parse each x ;
  ?[pos buffer; w; 0b; ()]
 };

/ Display a region of specified size around 1 or 2 rows in the buffer.
/ Example: browse 
browse:{
  len: count buffer; 
  if[0>type x; x:(x; 10)] ;
  if[-11=type x 0; x[0]: 1+(buffer `address)? x 0; if[len<x 0; :"ERROR: address not found"]] ;
  if[-11=type x 1; x[1]: 1+(buffer `address)? x 1; if[len<x 1; :"ERROR: address not found"]] ;
  
  if[3=count x; a:x 0; b:x 1; sz:x 2];
  if[2=count x; a:x 0; b:x 0; sz:x 1];
  if[1=count x; a:x 0; b:x 0; sz: 10];
  $[a<=b;[fr:a;to:b];[fr:b;to:a]] ;
  if[sz>=len;  :pos buffer] ;

  n:1+to-fr ; half:sz div 2; 
  if[sz<n; :(browse (fr; half)), (pos buffer)[len], browse (to; sz-half)] ;  

  fr-:1; to-:1; if[fr<0; :"ERROR: position is one based"] ; 
  half:(sz-n) div 2; beg:0|fr-half ;
  if[len<beg+sz; beg:len-sz];
  select[(beg;sz)] from pos buffer
 };

/***** Editing commands *******

/Find row containing "address", apply "settings" and move to postion "pos".
editServer:{[address; pos; settings]
  target: 1+ (buffer `address) ? address ;
  if[target>count buffer; :"ERROR: address not found"] ;
  if[null pos; pos:target] ;
  if[not `ok~ t:allow[settings] fields except `address`qfile; :t] ;
  updaterow[target; settings] ;
  buffer::moveItemInList[buffer; target; pos] ;
  `ok
 } ;

/Append a new row to the buffer, specifiying all fields in "settings"; then move to specified position.
/Launch a new server on the host/port given by the "address", running the "qfile" specified in the new row.
addServer:{[address; pos; settings]
  settings[`address]: address;
  if[not `ok~ t:allow[settings] fields;   :t] ;  
  if[not `ok~ t:require[settings] fields; :t] ;
  end: 1+ count buffer ;
  if[null pos; pos:end] ;
  buffer,:: buffer[end] ;
  updaterow[end; settings] ;
  buffer::moveItemInList[buffer;end;pos] ;
  cn_phasein,::address ;
  `ok
 };

/Copy row from specified "pos" to end of the buffer; update all fields in "settings"; then move above original copied row.
/Launch a new server on the host/port given by the "address", running the "qfile" specified in the new row.
copyServer:{[address; pos; settings]
  settings[`address]: address;
  if[not `ok~ t:allow[settings] fields; :t] ;  
  end: 1+ count buffer ;
  if[not pos within (1; end); :"ERROR: row to copy '",(string pos), "' not in range 1-", string end] ;
  buffer,:: buffer[pos] ;
  updaterow[end; settings] ;
  buffer::moveItemInList[buffer;end;pos] ;
  cn_phasein,::address ;
  `ok  
 };

replaceServer:{[address; pos; settings]
  oldserver:buffer[pos;`address] ;
  if[not `ok~ t:copyServer[address; pos; settings]; :t];
  cn_phaseout,::oldserver; 
  `ok
 };


/Upgrade (all or some) servers of a given "stype" to a new qfile and sversion.
/Select all rows from the buffer with a given stype and perhaps other "criteria". Invoke "replaceServer" on
/each of them, updating "address" to an unused port on the same host and perhaps qfile and sversion from "settings".
/Although the name is "upgrade" the operation could be a "downgrade" or simply a "restart", depending on the new qfile.
/The sversion should change or not change accordingly, but this is not enforced.
upgradeServers:{[criteria; settings]
  if[not `ok~ t:allow[criteria] `stype`sversion`host`qfile; :t] ;
  if[not `ok~ t:require[criteria] `stype; :t] ;  
  if[not `ok~ t:allow[settings] `qfile`sverson; :t] ;


 };

/Same as "upgradeServers" except we use "copyServer" rather than "replaceServer" - leave the old servers running
duplicateServers:{[criteria; settings]
  if[not `ok~ t:allow[criteria] `stype`sversion`host`qfile; :t] ;
  if[not `ok~ t:require[criteria] `stype; :t] ;  
  if[not `ok~ t:allow[settings] `qfile`sverson; :t] ;


 };

/Migrate selected servers to a new host.
/Select all rows from the buffer satisfying the "criteria" (not necessarily all of same stype). Invoke "replaceServer"
/on each of them, updating "address" to an unused port on the specified host, retaining the same qfile and condition.
/The stype and sversion may be updated to reflect the properties of the new host.
/In general the stype may depend on some combination of the host, qfile, and condition.
/However, only the host dependent part of the stype should be changed (Note: all new servers will be on SAME host!).
/To allow the non-host-dependent part of the stype to remain unchanged, we allow a "*" wildcard in the "stype" setting.
/To take advantage of this the stypes should include a delimiter separating the host dependent part.
/For example "t3xlarge-taiwan;servant;A-M" (host;qfile;condition).
/Could be changed to reflect a move to singapore using the pattern: "t3xlarge-singapore;*"
migrateServers:{[criteria; settings]
  if[not `ok~ t:allow[criteria] `stype`version`host`qfile; :t] ;
  if[not `ok~ t:allow[settings] `stype`sversion`host; :t] ;
  if[not `ok~ t:require[settings] `host; :t] ;


 };


/** Utilities **
fields: -1_ cols buffer;
allow:{[s;f] 
  na:(key s) except f ;
  if[0<count na; :"ERROR: Not Allowed: ", " " sv string na] ;
  `ok  
 };
require:{[s;f]
  ns:where isblank each (s f) ;
  if[0<count ns; '"ERROR: Not Specified: ", " " sv string f ns] ;
  `ok
 } ;

isblank:{0>type x; null x; 10=type x; 0=count trim x; 0=count x} ;
updaterow:{[r;d] updatefield[r] .' {(y;x[y])}[d] each key d ;};
updatefield:{[r;c;v] buffer[r-1;c]:v ;} ;


