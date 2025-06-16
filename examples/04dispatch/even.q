/"Even" dispatch algorithm: check for free servant, further down the list than the last one
/this distributes the queries more evenly across the servants; howerver, it can actually 
/degrade performance because more queries run with a cold cache
algo: enlist "even-plugin" 
lasthdl:0i ;
check_even:{[]
  /0N!"check_even" ;
  qid: exec first qid from queries where location in `master ;
  list: asc where 0=count each h ; 
  if[0=count list; :(::)] ;
  hdl: first list where list<lasthdl ;
  if[null hdl; hdl: first list] ;
  lasthdl:: hdl; send_query[hdl;qid] ;
 };  

