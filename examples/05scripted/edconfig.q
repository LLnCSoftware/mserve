/**** Stuff needed from scripted.q (or mserve_np.q) *****

if[ not `routingTable in key `.;
  /port range
  loport:{$[x=0i; 5000i; x]} system "p" ;
  hiport:{(1000* x div 1000)+997} loport ;

  / dummy data
  routingTable:([] address:`$ "localhost:",/: string  loport+ 1+til 20;
    stype: 20# `local:servA ;
    sversion: 20?(1 1 2 1) ;
    condition:  "boolean expression ",/: string 1+til 20;
    qfile: 20# `servant.q; 
    h:neg 5+til 20
   );
  update qfile:`servantbad.q from `routingTable where sversion=2 ; 
  
  routingDescriptor:(::) ;
  contextSource: routingTable `condition ;
  alterRoutingReq:{[cn; newRT]
    routingTable::newRT; contextSource::newRT `condition ;
    if[ cn~(::); cn:([increment:0N;interval:0N]) ];
    cn_increment:: cn `increment; cn_interval:: cn `interval ;
    cn_phasein::$[`phasein in key cn; cn `phasein; (count newRT)#0b] ;
    cn_phaseout::$[`phaseout in key cn; cn `phaseout; (count newRT)#0b] ;
  };

  / Launch new servers
  launch:{-1 "simulate Launch ", (x 2), " on `:", (x 0), ":", (x 1); 0N} ;
  h:(`int$())!() ;                    /map handle to outstanding queries
  h2addr:(`int$())!();                /map handle to (host;port;qfile)
  h2route: (`int$())!`symbol$() ;     /map handle to routing symbol
  h2idle:  (`int$())!`timestamp$() ;  /map handle to idle timestamp

  connectServant:{[route]
    /newh: neg hopen hsym route `address ;
    newh: -1+ min ed_buffer `h ;
    h[newh]:() ;
    h2addr[newh]: {(":" vs string x `address), enlist string x `qfile} route ;
    h2route[newh]: ` ;
    h2idle[newh]: 0Np ;
    newh
   };

  /canary control globals
  cn_backupCS:(::) ;
  cn_backupRT:(::) ;
  cn_increment: 0N ;
  cn_interval: 0N ;
  cn_phasein: (count routingTable)#0b ;
  cn_phaseout: (count routingTable)#0b ;
 ];

/**** search or browse the editBuffer ****

/temporary copies, so changes do not go live until applyChanges is called
/Note: copy on update - ed_buffer occupies no additional memory until part of it is updated. 
ed_buffer:routingTable ;
ed_phasein:`$() ;
ed_phaseout: `$() ;

/ start with copy of routing table.
/ add 1-based position column, remove handle column.
pos:{([] pos:1+til count x; stat:stat each x `address) ,' delete h from x} ;
stat:{[address]  
  ph:$[cn_increment=0N; ""; cn_increment<0; "100%"; cn_increment=0; "0%"; (string cn_percentage[]),"%" ];
  $[address in ed_phasein; "phase in ",ph; address in ed_phaseout; "phase out ",ph; ""]
 };  

/ Allow user to search the buffer by specifying "where clauses" for a functional select
/ Example: search ("address like \"localhost:*\"; "sversion=2") 
search:{
  if[10=type x; x:enlist x] ;
  if[0<>type x; :"ERROR: strings expected"] ;
  if[any 10<> type each x; :"ERROR: strings expected"] ;
  w: parse each x ;
  ?[pos ed_buffer; w; 0b; ()]
 };

/ Display a region of specified size around 1 or 2 rows in the buffer.
/ Example: browse 
browse:{
  len: count ed_buffer; 
  if[0>type x; x:(x; 10)] ;
  if[-11=type x 0; x[0]: 1+(ed_buffer `address)? x 0; if[len<x 0; :"ERROR: address not found"]] ;
  if[-11=type x 1; x[1]: 1+(ed_buffer `address)? x 1; if[len<x 1; :"ERROR: address not found"]] ;
  if[any not (type each x) in\: (-5 -6 -7h); :"ERROR: arguments should be symbol or integer"] ;
  
  if[3=count x; a:x 0; b:x 1; sz:x 2];
  if[2=count x; a:x 0; b:x 0; sz:x 1];
  if[1=count x; a:x 0; b:x 0; sz: 10];
  if[a<0; a:len]; if[b<0; b:len];
  $[a<=b;[fr:a;to:b];[fr:b;to:a]] ;
  if[sz>=len;  :pos ed_buffer] ;

  n:1+to-fr ; half:sz div 2; 
  if[sz<n; :(browse (fr; half)), (pos ed_buffer)[len], browse (to; sz-half)] ;  

  fr-:1; to-:1; if[fr<0; :"ERROR: position is one based, got 0"] ; 
  half:(sz-n) div 2; beg:0|fr-half ;
  if[len<beg+sz; beg:len-sz];
  select[(beg;sz)] from pos ed_buffer
 }; 
;
/************ Editing commands ***********

/Find row containing "address", apply "settings" and move to postion "pos".
/Setting condition to "0b" would take the server out out service; instead, put on phase-out list to allow canary.
editServer:{[address; pos; settings]
  if[not null cn_increment; :"Phase-in in progress - cannot edit"] ;
  if[-11=type pos; pos: 1+(ed_buffer `address) ? pos; if[pos>count ed_buffer; :"ERROR: address not found"]] ;
  target: 1+ (ed_buffer `address) ? address ; if[target>count ed_buffer; :"ERROR: address not found"] ;
  if[not `ok~ t:allow[settings] fields except `address`qfile; :t] ;
  if[0<count settings `condition; if[(settings `condition) in ("0b"; "(0b)"); settings _: `condition; ed_phaseout,::address]];  
  if[null pos; pos:target] ;
  if[pos<0; pos:1+count ed_buffer] 
  updaterow[target; settings] ;
  ed_buffer::moveItemInList[ed_buffer; target; pos] ;
  `ok
 } ;

/Append a new row to the buffer, specifiying all fields in "settings"; then move to specified position.
/Launch a new server on the host/port given by the "address", running the "qfile" specified in the new row.
addServer:{[address; pos; settings]
  if[not null cn_increment; :"Phase-in in progress - cannot edit"] ;
  if[-11=type pos; t:pos; pos: 1+(ed_buffer `address) ? pos; if[pos>count ed_buffer; :"ERROR: pos address not found, ", str t]] ;
  if[address in ed_buffer `address; :"ERROR: new address alrealy in table, ", str address];
  settings:([address:address]), settings ;
  if[not `ok~ t:allow[settings] fields;   :t] ;  
  if[not `ok~ t:require[settings] fields; :t] ;
  end: 1+ count ed_buffer ;
  if[pos<0; pos:end] ;
  ed_buffer,:: ed_buffer[end] ;
  updaterow[end; settings]; ed_buffer[end-1;`h]:0Ni ;
  ed_buffer::moveItemInList[ed_buffer;end;pos] ;
  ed_phasein,::address ;
  `ok
 };

/Copy row from specified "pos" to end of the buffer; update all fields in "settings"; then move above original copied row.
/Launch a new server on the host/port given by the "address", running the "qfile" specified in the new row.
copyServer:{[address; pos; settings; rep]
  if[not null cn_increment; :"Phase-in in progress - cannot edit"] ;
  if[-1<>type rep; :"ERROR: 'replace' flag must be a boolean (1b 0b)"];
  if[-11=type pos; t:pos; pos: 1+(ed_buffer `address) ? pos; if[pos>count ed_buffer; :"ERROR: old address not found, ", str t]];
  if[address in ed_buffer `address; :"ERROR: new address alrealy in table, ", str address];
  end: 1+ count ed_buffer ;
  if[not pos within (1; end); :"ERROR: row to copy '",(string pos), "' not in range 1-", string end] ;
  settings:([address:address]), settings ;
  oldaddress:ed_buffer[pos-1;`address] ;
  if[not `ok~ t:allow[settings] fields; :t] ;  
  ed_buffer,:: ed_buffer[pos-1];
  updaterow[end; settings]; ed_buffer[end-1;`h]:0Ni;
  ed_buffer::moveItemInList[ed_buffer;end;pos] ;
  if[rep; ed_phaseout,::oldaddress] ;
  ed_phasein,::address ;
  `ok  
 };

/Upgrade (all or some) servers of a given "stype" to a new qfile and sversion.
/Select all rows from the buffer with a given stype and perhaps other "criteria". Invoke "replaceServer" on
/each of them, updating "address" to an unused port on the same host and perhaps qfile and sversion from "settings".
/Although the name is "upgrade" the operation could be a "downgrade", "restart", or "reassignment" depending on the new qfile.
/The sversion should change or not change accordingly, but this is not enforced.
upgradeServers:{[stype; criteria; settings; rep]
  if[not null cn_increment; :"Phase-in in progress - cannot edit"] ;
  criteria: ([stype:stype]), criteria ;
  if[not `ok~ t:allow[criteria] `stype`sversion`host`qfile; :t] ;
  if[not `ok~ t:require[criteria] `stype; :t] ;  
  if[not `ok~ t:allow[settings] `qfile`sversion; :t] ;
  oldservers: addressByCriteria criteria ;
  {newx:unusedPort x; t:copyServer[newx; x; y; z]; (t;newx)} [;settings;rep] each oldservers 
 };


/Migrate (all or some) servers of a given "stype" to a new host.
/Select all rows from the buffer with a given stype and perhapse other "criteria". Invoke "replaceServer" on each
/of them, updating "address" to an unused port on the specified host, retaining the same qfile and condition.
/The stype and sversion may be updated to reflect the properties of the new host.
/In general the stype may depend on some combination of the host, qfile, and condition.
/Any new stype must be chosen to reflect only the change of host (which is why we only allow one stype per call)
migrateServers:{[stype; criteria; settings; rep]
  if[not null cn_increment; :"Phase-in in progress - cannot edit"] ;
  criteria: ([stype:stype]), criteria ;
  if[not `ok~ t:allow[criteria] `stype`sversion`host`qfile; :t] ;
  if[not `ok~ t:require[criteria] `stype; :t] ;  
  if[not `ok~ t:allow[settings] `stype`sversion`host; :t] ;
  if[not `ok~ t:require[settings] `host; :t] ;
  oldservers: addressByCriteria criteria ;
  {newx: unusedPort (str y `host), ":", str hiport; y:`host _ y; 
   t:copyServer[newx; x; y; z]; (t;newx)} [;settings;rep] each oldservers 
 };

/******* edit state controls *******
clearChanges:{
  ed_phasein::  (routingTable `address) where cn_phasein ;
  ed_phaseout:: (routingTable `address) where cn_phaseout ;
  ed_buffer::routingTable ;
 };

applyChanges:{[pct_increment; per_interval]
  /Convert canary paramters from string.
  pct_increment: "J"$ ssr[;"%";""] pct_increment ;  /percentage eg. "25%" to integer
  per_interval: interval2ms per_interval ;          /time interval eg "3h" to milliseconds

  if[(ed_buffer~routingTable) and all 0=count each (ed_phasein; ed_phaseout); :"no changes to apply"] ;
  if[(not null pct_increment) and all 0=count each (ed_phasein; ed_phaseout); :"nothing to phase in or out"];

  /launch and connect "phasein" servers; capture handles
  routing:  select from ed_buffer where address in ed_phasein ;
  launchAll routing ;
  hdl: connectServant each routing ;
  update h:hdl from `ed_buffer where address in routing `address ;

  /set canary parameters
  no_canary: any null (pct_increment; per_interval) ;
  if[no_canary; delete from `ed_buffer where address in ed_phaseout] ;

  canary: $[no_canary;  (::);
     ([increment:pct_increment; interval:per_interval; 
      phasein:(ed_buffer `address) in\: ed_phasein ; 
      phaseout:(ed_buffer `address) in\: ed_phaseout])
   ];
  alterRoutingReq[canary; ed_buffer] ; 
  clearChanges[] ;
  `ok
 };

launchAll:{[routing]
  servants: {(":" vs string x `address), enlist string x `qfile} each routing ; 
  lh: launch each servants ;
  system "sleep 5" ;
  {if[not null x; hclose x]} each lh ;  /close handles to launcher on remote hosts.
 };

/**** Installation/Phase-In controls for new routing table - typically invoked manually via editor *****

cancelPhaseIn:{[]
  if[null cn_increment; :"No phase in to cancel" ];
  if[cn_increment<>0; :"Cancel only when holding at 0% - use alterPhaseIn[0;0N]"];
  if[(cn_backupRT~(::)) or cn_backupCS~(::); :"No backup to restore";];
  alterRouting[(::); cn_backupRT; cn_backupCS]
 } ;

finishPhaseIn:{[]
  if[null cn_increment; :"No phase in to finish" ];
  if[cn_increment<>-1; :"Finish only when holding at 100% - use alterPhaseIn[-1; 0N]" ];
  if[all cn_phaseout=0b;
   cn_increment::0N; cn_interval::0N; cn_start::0Np; cn_cnterr::0 ;
   cn_backupRT::(::); cn_backupCS::(::); cn_phasein::cn_phaseout;
   :"done - nothing to phase out"
  ];
  alterRoutingReq[(::); delete from routingTable where cn_phaseout]
 } ;


/ Allows changeing increment and/or interval for a canary in progress 
/ Specify 0N to leave increment or interval unchanged.
/ Specify increment as 0 or -1 to hold at 0% or 100% respectively.
alterPhaseIn:{[increment; interval]
  increment:$[10=type increment; "J"$ ssr[increment; "%"; ""]; increment] ;
  interval:$[10=type interval; interval2ms interval; interval] ;
  if[null cn_increment; :"No active phase-in to modify"];
  if[not null increment; cn_increment::increment; cn_start::0Np; cn_cnterr::0] ;
  if[not null interval: cn_interval::interval; cn_start::0Np; cn_cnterr::0] ;
 } ;

/ Applies change to routing table after obtaining a new context source.
/ After validating the "canary" parameters, receiveContextSource is replaced by an appropriate 
/ projection of "alterRouting" below, before calling requestContextSource.
alterRoutingReq:{[canary; newRT]
  if[cn_increment>=0; :"Phase in already in progress"];
  if[not canary~(::);
    if[(not canary[`increment]>=0) or not canary[`interval]>0; :"increment or interval missing"];
    if[`phasein  in key canary; t:canary `phasein;  if[(1h<>type t) or (count t)<>count newRT; :"invalid phasein bit vector"]];
    if[`phaseout in key canary; t:canary `phaseout; if[(1h<>type t) or (count t)<>count newRT; :"invalid phaseout bit vector"]];
  ];
  -1 "awaiting contextSource" ;
  receiveContextSource::alterRouting[canary; newRT;] ;
  requestContextSource[newRT `condition; routingDescriptor] ;
 };

/ Alter Routing: This should be invoked as a callback after obtaining the new context source (newCS),
/ which could take some time to build. When canary is omitted (::), the operation is one of:
/ applying an abrut change (no phase in), or of finishing or canceling a previous canary.
/ In this case, the canary settings and backups will be cleared. Otherwize a new canary is being
/ started, and this can only happen when no previous canary is in effect.
alterRouting:{[canary; newRT; newCS]
  -1 "received context source" ;
  $[canary~(::); [cn_backupRT::(::); cn_backupCS::(::)]; [cn_backupRT::routingTable; cn_backupCS::contextSource]];

  update route:` from `queries where location=`master ; fallbackPos::(::) ; /invalidate previous routing symbols
  routingTable::newRT; contextSource::newCS;                                /install new routing table and context source
  hclose each abs drophandles (key h) except routingTable `h ;              /disconnect servants not present in new routing table

  if[canary~(::); canary:([increment:0N;interval:0N]) ];
  cn_start::0Np; cn_cnterr::0;
  cn_increment:: canary `increment; cn_interval:: canary `interval; 
  cn_phasein:: $[`phasein in key canary; canary `phasein; (count routingTable)#0b ];
  cn_phaseout:: $[`phaseout in key canary; canary `phaseout; (count routingTable)#0b ] ; 
  clearChanges[] ;
  `ok 
 };
drophandles:{ h::h _/ x; h2addr::h2addr _/ x; h2route::h2route _/ x; h2idle::h2idle _/ x; x} ;


/******** Utilities **********
fields: (cols routingTable) except `h ;
allow:{[s;f] 
  na:(key s) except f ;
  if[0<count na; :"ERROR: Not Allowed: ", " " sv string na] ;
  if[`address in key s; if[not `ok~t:validaddress s `address; :t]] ;
  `ok  
 };
require:{[s;f]
  if[0>type f; f:enlist f] ;
  ns:where isblank each (s f) ;
  if[0<count ns; '"ERROR: Not Specified: ", " " sv string f ns] ;
  `ok
 } ;

validaddress:{
  t: ":" vs str x ;
  if[2<>count t ; :"ERROR address must be of form: 'host:port'"] ;
  if[not ("J"$ t 1) within (loport;hiport); :"ERROR port must be  between ", " " sv string (loport;hiport)];
  `ok
 };


str:{$[10=type x; x; string x]} ;
isblank:{$[0>type x; null x; 10=type x; 0=count trim x; 0=count x]} ;
moveItemInList:{[data;fr;to] 
  fr:0|fr-1; to:0|to-1; /one based
  en:count data; fr&:en-1; to&:en-1; if[fr=to; :data];
  a:til fr&to; b:fr&to; d:fr|to; c:1+b+til d-b+1; e:1+d+til en-d+1;
  data raze $[fr<to; (a;c;d;b;e); (a;d;b;c;e)]
 };  

interval2ms:{u:last x; x: -1_ x; ("J"$x)* $[u="m"; 60000; u="h"; 60*60000; u="d"; 24*60*60000; 0N]} ;
ms2interval:{{t:last where x>0; (string x t),t} "mhd"!(x div 60000; x div 60*60000; x div 24*60*60000)} ;

updaterow:{[r;d] updatefield[r] .' {(y;x[y])}[d] each key d ;};
updatefield:{[r;c;v] ed_buffer[r-1;c]:v ;} ;

addressByCriteria:{[d]
  if[99<>type d; :"ERROR: dictionary expected"] ;
  w:{[d;k] 
    v: d k;
    if[k=`host; :(like; `address; $[10=type v; v; string v],":*")];
    if[10=type v; :(like; k; v)];
    if[-11=type v;  :(=; k; enlist v)];
    if[(type v) within (-7;-5); :(=; k; v)];
    :"ERROR: unexpected criterion, value type=", string type v, " pair ", .Q.s1 (k;v) ;
  }[d] each key d ;
  ?[pos ed_buffer; w; 0b; ([address:`address])] `address
 } ;

unusedPort:{[addr]
  host: first ":" vs str addr ;
  used: asc "J"$ (ssr[; host,":"; ""] each) string exec address from ed_buffer where address like (host, ":*") ;
  gaps: where 1< used-prev used ;
  port: $[0=count gaps; 1+loport|max used; last gaps] ;
  if[port>hiport; '"no available port on ", host] ;
  `$ host,":", string port  
 };

saveConfiguration:{ 
  if[not null cn_increment; '"Cannot save; Phase-in in progress "+(string cn_percentage)+"%. Use finishPhaseIn or cancelPhaseIn first."]; 
  (`$":",afile,"1") 0: "," 0: delete h from routingTable ;      /write csv file, appending "1" to original file name 
  "OK"
 } ; 

-1 "edconfig.q loaded" ;
