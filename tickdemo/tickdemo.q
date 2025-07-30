\l scripted.q 
\l edconfig.q 
currentdate:0Nd; nextdate:0Nd; 
getRoutingCriteria:{[arg;opt] 
  d:arg 1; 0N!(`getRoutingCriteria; d; currentdate); 
  if[ 14<>abs type d; :([hiday:0N; loday:0N]) ];
  ([loday:(first d)-currentdate ; hiday:(last d)-currentdate])
 } ;

servantMessage:{[id;cmd;arg]
  if[cmd~`initdate; currentdate:: arg; :(::)] ;
  if[cmd~`endofday; nextdate::arg; restart "A"; :(::)] ;
  if[cmd~`hdbAready; restart "B"; :(::)] ;
  if[cmd~`hdbBready; 
    d:currentdate; currentdate::nextdate; 
    {x (`endofdayok; y)}[;d] each where h2addr[;2] like "rdb.q *" ;  
  ];
 };

restart:{}


