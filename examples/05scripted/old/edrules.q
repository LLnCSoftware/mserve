/****** Synchronous api to edit routing table ******

invalid:"Routing commands must be lists of strings" ;
.z.pg:{ 0N!x ;
  if[0<>type x; :invalid]; if[any 10<>abs type each x; :invalid] ;
  if[(x 0)~"getRule"; :getRule x 1] ;
  if[(x 0)~"setRule"; :setRule[x 1; x 2; x 3]] ;
  if[(x 0)~"saveRoutingTable"; :saveConfiguration[]] ;
  if[(x 0)~"cancelPhaseIn"; :cancelPhaseIn[]] ;
  if[(x 0)~"finishPhaseIn"; :finishPhaseIn[]] ;
  0N!"Unexpected routing command: ", x 0 ; 
 } ; 

saveConfiguration:{ 
  if[not null cn_server_type; '"Phase-in in progress "+(string cn_percentage)+"%"]; 
  delete from `routingTable where condition in ("0b"; "(0b)") ; /remove phased-out rules from routing table.
  hclose each abs drophandles (key h) except routingTable `h ;  /remove and close handles no longer present in routing table
  (`$":",afile,"1") 0: "," 0: delete h from routingTable ;      /write csv file, appending "1" to original file name 
  "OK"
 } ; 

getRules:{
  csvf: 1_ "," 0: delete h from routingTable ;
  pos: {x,": "} each string til count csvf ;
  match: where csvf like str x ;
  info: $[null cn_increment; enlist "no canary";
   ((string cn_percentage[]), "% increment ",(string cn_increment), "% per ", asInter cn_interval;
    "phase in:  ", ", " sv string cn_phasein;
    "phase out: ", ", " sv string cn_phaseout
   )] ;
  ((pos match) ,' (csvf match)), info
  /1_ "," 0: select from (delete h from routingTable) where address like x[0], stype like x[1] 
 } ;

setRule:{[pos;routing;canary]
  if[10=abs type pos; pos: "J"$ pos] ;
  if[0<count canary;
    canary: "," vs canary ;
    if[2<>count canary; :"phase-in requires 2 settings: percentage, per-interval (suffix: m=minutes, h=hours, d=days)"] ;
    cn_increment:: "J"$ ssr[;"%";""] canary 0 ;  /specify cn_increment zero to delay phase in until all rules entered.
    cn_interval:: interval canary 1 ;
    if[any null (cn_increment; cn_interval); :"Invalid phase-in specification."] ;
    if[(::)~cn_backupRT; cn_backupRT:: routingTable; -1 "routing table backed up"] ;
  ] ;
  /update routing table
  len:count routingTable;  pos:len^pos ;
  routing: (-1_ cols routingTable)! ("SSJ**"; ",") 0: routing ;   /same as a routing table csv row
  hit: (routingTable `address)? routing `address ;                /Is address already in table ?
  if[hit<len;                                                     /Yes, in table:
    if[not (routing `qfile)~routingTable[hit;`qfile]; :"Cannot change 'qfile' in an existing rule"] ;
    if[(not null cn_increment) and routing[`condition] in ("0b";"(0b)"); /when canary and condition is "false" 
      routing[`condition]: routingTable[hit;`condition];                 / preserve existing condition during phase-out
      cn_phaseout,: routing[`address]                                    / add to phase-out list
    ];
    routing[`h]: routingTable[hit;`h]; routingTable[hit]:routing ; /replace row, but keep same handle.
  ];
  if[hit=len;                                                     /No, not in table
    if[(not null cn_increment) and not routing[`condition] in ("0b";"(0b)"); /when canary and condtion is not "false" 
      cn_phasein,: routing[`address];                                        / add to phase-in list
    ];
    routing[`h]: connectServant routing; routingTable,::routing ;  /connect servant then add row w new handle
  ];
  if[hit<>pos; routingTable::moveItemInList[routingTable;hit;pos]];  /if not in requested position, move.
  /clear previous routing symbol in enqueued queries, and fallback positions (recompute upon next "check[]")
  update route:` from `queries where location=`master ; fallbackPos::(::) ;
  "OK"
 } ;

interval:{u:last x; x: -1_ x; ("J"$x)* $[u="m"; 60000; u="h"; 60*60000; u="d"; 24*60*60000; 0N]} ;
asInter:{{t:last where x>0; (string x t),t} "mhd"!(x div 60000; x div 60*60000; x div 24*60*60000)} ;

moveItemInList:{[data;fr;to]
  en:count data; fr&:en-1; to&:en-1; if[fr=to; :data];
  a:til fr&to; b:fr&to; d:fr|to; c:1+b+til d-b+1; e:1+d+til en-d+1;
  data raze $[fr<to; (a;c;d;b;e); (a;d;b;c;e)]
 };

connectServant:{[routing]
  0N!"connect servant ", string routing `address ;
  newh: neg @[hopen; hsym routing `address; 0Ni];
  /0N!newh ;
  if[ null newh;
    servant,: enlist (":" vs string routing `address), enlist routing `qfile ;    /add new servant
    lh: launch last servant ;  /lh=handle to launcher.q when servant on foreign host
    -1 "Wait 5 seconds" ; system "sleep 5";
    if[not null lh; hclose lh] ;
    newh: neg hopen hsym routing `address ;
  ];
  h[newh]:() ;
  h2addr[newh]: last servant ;
  h2route[newh]: enlist `$() ;
  h2idle[newh]: 0Np ;
  newh
 };
 
