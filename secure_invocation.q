/secure invocation toolkit
/This module provides functions that may be used to secure a "q" based api.
/ 1. Allow execution only of functions defined in the .api namespace.
/ 2. Reject commands which contain function evaluation in their arguments   
/ 3. Support env variable Q_SERVANTOF - allow only a single connection from specified IP address (load balancer)
/ 4. Support env variable Q_PLUGINS - load optional q-modules, (for example, authentication and authorization)
/ 5. Provide "getrole" stub to be overriden by authentication module.
/ 6. Provide "allowedfn" stub to be overridden by authroization module.

/--- Example protocols ---
/We present examples of synchronous and asynchronous communication for an api server. 
/While these examples could work as-is you might want to modify them  in order to:
/ 1. Use a different calling convention for the request and/or response.
/ 2. Support query options other than "role"
/ 3. Return "info" in addition to the query "result".

/ To access your api functions synchronously use the following as .z.pg
/ request: query OR (query; options) (options might contain role)
/ response result ;
validateAndRunSync:{[req]  
  if[10=type req; req:(req; (::))];     /when request is a string assume its a query with no options
  if[-11=type req 0; req:(req; (::))] ; /when request begins with a symbol assume its a query with no options
  cmd:.[.si.validate; (req 0; req 1); {"Error: ",x}]; if[10=type cmd; :cmd]; /validate command; if string returned its an error.
  .[cmd 0; cmd 1; {[nam;e] "Error: in ",nam, ", ", e}[cmd 2;]];             /run command; return result or error
 };

/ To access your api functions asynchronously use the following as .z.ps
/ request: (id; query; [options])
/ response: (id; result) 
validateAndRunAsync:{[req] 
  cmd:.[.si.validate; (req 1; req 2); {x}];       /validate command
  if[10=type cmd; :.si.send[.z.w;] 0N!(req 0; cmd)];  /if string returned its an error
  res: .[cmd 0; cmd 1; {[nam;e] "Error: in ",nam, ", ", e}[cmd 2;]] ; /invoke command
  .si.send[.z.w;] (req 0; res) ;                      /return result or error
 };

/--utilities--

/This allows testing of an asynchronous protocol from the servant console, using handle zero.
/Given a handle and data, it displays rather than sends the data for handle zero.
.si.send:{[h;data] if[h=0; -1 "\nresult:"; :show each data]; (neg h) data} ;  

/This enforces the restrictions implied by "secure_invocation".
.si.validate:{[query; options]
  role:getrole options ;                                   /get role from options 
  if[10=type query; query:.si.parse query];                /when query is a string, parse it
  fn: allowedfn[role] {$[-11=type x; x; `]} query 0 ;      /Function name is symbol from first item of parsed query; otherwize null.
  if[null fn; '"unknown command: ", .Q.s1 query 0] ;       /Accept only function names in .api namespace, AND allowed by role.
  arg: 1_ query ;                                          /Remaining query items are arguments.
  if[100<=any type each (raze/) arg; "nested evaluation"]; /Reject query with any function type anywhere in any argument
  (fn; arg; query 0)                                       /return: function; arguments; function name
 };

/This parses a query intended to be run without using "eval" - treating all symbols as literals.
/It invokes the usual "q" parse function, and then applies "fixarg" below to each argument.
.si.parse:{  
 cmd: parse x; 
 arg:1_ cmd; cmd:cmd 0;
 arg:.si.fixarg each arg ;
 raze (cmd; arg) 
 };

/This fixes arguments mangled by "parse".
/In order to distinguish symbols representing global variable names from literals,
/the "parse" function represents symbols and lists of symbols as singletons containing the symbol or list.
/That allows it to use symbol atoms to represent undecorated words like "xyz", namely global variables.
/Similary, it must distinguish a literal general list in an argument from a command to be evaluated.
/For that it uses a trick: representing a literal general list as an "enlist" command.
/Normally, this "mangling" is undone by "eval", but since we are avoiding "eval" we do it here.
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

/---- setup ----

/Defaults for override by plugins
getrole:{[opt] $[99=type opt; opt `role; `]} ;   /overridden in authent.q
allowedfn:{[role] value `.api} ;                 /overridden in authriz.q

/ Environment Options
if[0<count getenv `Q_PLUGINS; {system "l ", x} each "," vs getenv `Q_PLUGINS] ; /When Q_PLUGINS specified, load listed "q-files".                                                                                 /When Q_SERVANTOF specified,
if[0<count getenv `Q_SERVANTOF;                                                 /When Q_SERVANTOF specified:
 .z.pw:{[u;p] (getenv `Q_SERVANTOF)~ "." sv string `int$ 0x0 vs .z.a};          / accept connection only from specified IP.
 .z.po:{.z.pw:{[u;p] 0b}; .z.pc:{exit 0}} ;                                     / accept only single connection, terminate on close
 ];
0N!"secure_invocation.q loaded" ;
