/This launch utility accepts a command string of the form: ( env-settings ) q-file-path arguments.
/Where the optional environment settings, if included, must be enclosed in parentheses, and the "q" command itself is omitted.
/The command string is parsed to separate the enviornment settings and parent directory from the command itself.
/This allows a separate "cd" to the parent directory before the launch, and for the absolute path used to invoke "q"
/(available as .z.X 0) to be inserted between the environment settings and the actual command.
/In addition a base path may be specified to resolve the parent directory against, to support ~/ ../ etc.
/and additional env settings may be specified to suppliment any provided in the command string.
launchQ:{[base;env;cmd]
  a:splitEnv cmd; b:splitDir a 1; c:splitCmd b 1;
  if[not c like "*?.q"; '":No q-file in command: '", cmd, "'"] ; 
  dir:abspath[base; b 0]; 
  if[notfound[dir;c]; dir:abspath[""; b 0]; if[notfound[dir;c]; '"file not found: ",c]] ;

  if[0<count dir; sav:first system "pwd"; system 0N!"cd ", dir] ;
  system 0N!trim env, " ", (a 0), " ", (.z.X 0), " ", (b 1), " &" ;   
  if[0<count dir; system "cd ", sav] ;
 };
splitEnv:{a:b:0; if["("=x 0; a:1; b:x?")"]; trim (a _ (b-count x)_ x; (b+a>0)_ x)} ;
splitDir:{t:((count x)^first where x=" ")# x; n:0^last where t="/"; (n # x; (n+n>0) _ x)} ;
splitCmd:{(x?" ")# x} ;

/Convert to absolute using a base path.
abspath:{[base; path] 
  if["/"=first path; :path] ;
  if[ path like "~/*"; :(getenv `HOME), {$[""~x; ""; "/",x]} 2_ path] ;

  if[ base like "~/*"; base:(getenv `HOME), {$[""~x; ""; "/",x]} 2_ base] ;
  if["/"<>first base; base:(first system "pwd"), "/", base] ;
  if["/"<>last base; base:base,"/"] ;

  if[ path like "../*";   :("/" sv -2_ "/" vs base), {$[""~x; ""; "/",x]} 3_ path] ;
  if[ path like "./*";    :("/" sv -1_ "/" vs base), {$[""~x; ""; "/",x]} 2_ path] ;    
  ("/" sv -1_  "/" vs base), {$[""~x; ""; "/",x]} path
 };
relpath:{[path]
  if["/"<>first path; :path] ;
  d: first system "pwd"; if[path like d, "/*"; :(1+count d)_ path] ;
  d: getenv `HOME; if[ path like d, "/*"; :"~/", (1+count d)_ path] ;
  path
 };
notfound:{0=type key `$":", $[x~""; y; x,"/",y]} ;
resolve:{[d;f] 
  file: abspath[d;f];  if[0<count key `$":",file; :file]; 
  file: abspath["";f]; if[0<count key `$":",file; :file]; 
  '"not found: ", f;
 }

