buffer:([] address:`$ "localhost:",/: string  5000+ 1+til 20;
  stype: 20# `local:servA ;
  sversion: 20?(1 1 2 1) ;
  condition:  "boolean expression ",/: string 1+til 20;
  qfile: 20# `servant.q; 
  h:neg 5+til 20
 );
update qfile:`servantbad.q from `buffer where sversion=2 ; 

pos:{([] pos:1+til count x),'delete h from x} ;

search:{
  if[10=type x; x:enlist x] ;
  if[0<>type x; '"strings expected"] ;
  if[any 10<> type each x; '"strings expected"] ;
  w: parse each x ;
  ?[pos buffer; w; 0b; ()]
 };

browse:{
  len: count buffer; 
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
