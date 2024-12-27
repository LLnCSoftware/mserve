/synchronous
/ request: query OR (query; options) (options might contain role)
/ response result ;
.z.pg:{[req]  
  if[-11=req 0; req:(req; (::))] ; /when request begins with a symbol assume its a query with no options
  cmd:.[.si.validate; (req 0; req 1); {"Error: ",x}]; if[10=type cmd; :cmd]; /validate command; if string returned its an error.
  .[cmd 0; cmd 1; {[nam;e] "Error: in ",nam, ", ", e}[cmd 2;]];             /run command; return result or error
 };

/asynchronous
/ request: (id; query; [options])
/ response: (id; result) 
.z.ps:{[req] 
  cmd:.[.si.validate; (req 1; req 2); {x}];       /vaidate command
  if[10=type cmd; :send[.z.w;] 0N!(req 0; cmd)];  /if string returned its an error
  res: .[cmd 0; cmd 1; {[nam;e] "Error: in ",nam, ", ", e}[cmd 2;]] ; /invoke command
  .si.send[.z.w;] (req 0; res) ;                      /return result or error
 };
.si.send:{[h;data] if[h=0; -1 "\nresult:"; :show each data]; (neg h) data} ;  /allows testing from console using handle zero.

.si.validate:{[query; options]
  role:getrole options ;
  if[10=type query; query:siparse query];
  fn: allowedfn[role] {$[-11=type x; x; `]} query 0 ;
  if[null fn; '"unknown command: ", .Q.s1 query 0] ;  /not a symbol atom OR not in .api namespace OR not allowed by role
  arg: 1_ query ;
  if[100<=any type each raze/ arg; "nested evaluation"] ; /function type anywhere in any argument
  (fn; arg; query 0)
 };

.si.parse:{  
 cmd: parse x; arg:1_ cmd; cmd:cmd 0;
 arg:fixarg each arg ;
 raze (cmd; arg) 
 };

.si.fixarg:{[x]
  if[-11=type x; '"nested evaluation"];     /symbol atom is global variable
  if[(11=type x) and 1=count x; :x 0];      /enlisted symbol is its content
  if[0<>type x; :x];                        /not general list - ok
  if[(1=count x) and 11=type x 0; :x 0];    /enlisted list of symbols is its content
  if[-11=type x 0; '"nested evaluation"];   /symbol atom at index 0 is global variable (user-defined function)
  if[100> type x 0; :x] ;                   /not a built-in function at index 0 - ok
  if[enlist~ x 0; :1_ x] ;                  /"enlist" function at index 0 ? just drop it.
  '"nested evaluation"                      /you might want to evaluate + - * % etc. but you would need to validate their arguments.                                         
 };

/Defaults for override by plugins
getrole:{[opt] $[99=type opt; opt `role; `]} ;   /overidden in authent.q
allowedfn:{[role] value `.api} ;                 /overidden in authriz.q

/ Environment Options
if[0<count getenv `Q_PLUGINS; {system "l ", x} each "," vs getenv `Q_PLUGINS] ; /When Q_PLUGINS specified, load listed "q-files".                                                                                 /When Q_SERVANTOF specified,
if[0<count getenv `Q_SERVANTOF;                                                 /When Q_SERVANTOF specified:
 .z.pw:{[u;p] (getenv `Q_SERVANTOF)~ "." sv string `int$ 0x0 vs .z.a};          / accept connectinon only from specified IP.
 .z.po:{.z.pw:{[u;p] 0b}; .z.pc:{exit 0}} ;                                     / accept only single connection, terminate on close
 ];
0N!"secure_invocation.q loaded" ;
