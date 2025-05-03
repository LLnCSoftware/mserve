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
  fr-:1; to-:1; if[any (fr;to) <0; '"one-based"];
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
  if[0<>type x; '"strings expected"] ;
  if[any 10<> type each x; '"strings expected"] ;
  w: parse each x ;
  ?[pos buffer; w; 0b; ()]
 };

/ Display a region of specified size around 1 or 2 rows in the buffer.
/ Example: browse 
browse:{
  len: count buffer; 
  if[0>type x; x:(x; 10)] ;
  if[-11=type x 0; x[0]: 1+(buffer `address)? x 0; if[len<x 0; '"address not found"]] ;
  if[-11=type x 1; x[1]: 1+(buffer `address)? x 1; if[len<x 1; '"address not found"]] ;
  
  if[3=count x; a:x 0; b:x 1; sz:x 2];
  if[2=count x; a:x 0; b:x 0; sz:x 1];
  if[1=count x; a:x 0; b:x 0; sz: 10];
  $[a<=b;[fr:a;to:b];[fr:b;to:a]] ;
  if[sz>=len;  :pos buffer] ;

  n:1+to-fr ; half:sz div 2; 
  if[sz<n; :(browse (fr; half)), (pos buffer)[len], browse (to; sz-half)] ;  

  fr-:1; to-:1; if[fr<0; '"one based"] ; 
  half:(sz-n) div 2; beg:0|fr-half ;
  if[len<beg+sz; beg:len-sz];
  select[(beg;sz)] from pos buffer
 };

/***** Editing commands *******

/Find row containing "address", apply "settings" and move to postion "pos".
editServer:{[address; pos; settings]
  target: 1+ (buffer `address) ? address ;
  if[target>count buffer; '"address not found"] ;
  if[null pos; pos:target] ;
  disallow[settings] `address`qfile ;
  updaterow[target; settings] ;
  buffer::moveItemInList[buffer; target; pos] ;
 } ;

/Append a new row to the buffer, specifiying all fields in "settings"; then move to specified position.
/Launch a new server on the host/port given by the "address", running the "qfile" specified in the new row.
addServer:{[address; pos; settings]
  settings[`address]: address;
  disallow[settings] () ;  
  require[settings] fields ;
  end: count buffer ;
  if[null pos; pos:end] ;
  buffer,:: buffer[end] ;
  updaterow[end; settings] ;
  buffer::moveItemInList[buffer;end;pos] ;
  cn_phasein,::address ;
 };



/** Utilities **
fields: -1_ cols buffer;
disallow:{[s;f] 
  na:(key s) except fields except f ;
  if[0<count na; '"Not Allowed: ", " " sv string na] ;
 };
require:{[s;f]
  ns:where (s f) in (0N;`;"") ;
  if[0<count ns; '"Not Specified: ", " " sv string f ns] ;
 } ;

addrow:{p:count buffer; buffer,::x; p} ;
updaterow:{[r;d] updatefield[r] .' {(y;x[y])}[d] each key d ;};
updatefield:{[r;c;v] buffer[r-1;c]:v ;} ;


