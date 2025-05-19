\l authent.q
\l edconfig.q
\l qre2.q

/***** Synchronous Api for administrator commands *****.
.z.pg:{[c] @[invoke; c; {[x] "ERROR ", x}] } ;

invalid:"Admin commands must be lists of strings" ;
invoke:{[x] 0N!x; 
  if[0<=type x; if[(type x 0) in (-5 -6 -7h); :"USE ASYNC"]] ;
  if[0<>type x; :invalid]; if[any 10<>abs type each x; :invalid] ;
  if[(x 0)~"search"; :search vWhere each 1_ x] ;
  if[(x 0)~"browse"; n:count x; :$[n<=1; browse (1 5); n=2; browse (vPos x 1; 5);
    n=3; browse (vPos x 1; vPos x 2); browse (vPos x 1; vPos x 2; vInt x 3) ]] ;
  if[(x 0)~"editServer"; :editServer[vAddr x 1; vPos x 2; vSettings x 3]] ;
  if[(x 0)~"addServer"; :addServer[vAddr x 1; vPos x 2; vSettings x 3]] ;
  if[(x 0)~"copyServer"; :copyServer[vAddr x 1; vPos x 2; vSettings x 3; vRep x 4]] ;
  if[(x 0)~"upgradeServers"; :upgradeServers[vStyp x 1; vCriteria x 2; vSettings x 3; vRep x 4]] ;
  if[(x 0)~"migrateServers"; :migrateServers[vStyp x 1; vCriteria x 2; vSettings x 3; vRep x 4]] ;
  if[(x 0)~"clearChanges"; :clearChanges[]] ;
  if[(x 0)~"applyChanges"; :applyChanges[vPercent x 1; vInterval x 2]] ;
  if[(x 0)~"saveConfiguration"; :saveConfiguration[]] ;
  if[(x 0)~"cancelPhaseIn"; :cancelPhaseIn[]] ;
  if[(x 0)~"finishPhaseIn"; :finishPhaseIn[]] ;
  0N!"Unexpected admin command: ", x 0  
 } ; 

/ sanitize arguments against code injection
match:{first .qre2.rexm[x;y]} ;
emptydict:(enlist `)!(enlist (::)) ;

vInt:{v:"J"$ x; $[null v; '"integer expected, got ",x; v]} ;
vHost:{if[match[x; "^[a-zA-Z0-9.]+"]; :`$x]; '"host (alphanumerics, period) expected, got ",x} ;
vStyp:{if[match[x; "^[a-zA-Z0-9.:]+$"]; :`$x]; '"stype (alphanumerics, period, colon) expected, got ",x} ;
vAddr:{if[match[x; "^`?[a-zA-Z0-9.]+:[0-9]+$"]; :$["`"=first x; `$ 1_ x; `$x]];'"servant address (host:port)} expected, got ", x} ;
vFile:{if[match[x; "^`?[a-zA-Z0-9./]+$"]; :$["`"=first x; `$ 1_ x; `$x]];'"qfile (path) expected, got ", x} ;
vPos:{if[""~x; :0N]; if[match[x;"^-?[0-9]+$"]; :"J"$x]; if[match[x;"^`?[a-zA-Z0-9.]+:[0-9]+$"]; :$["`"=first x;`$ 1_ x;`$x]];
  '"routing table position (int) or servant address (host:port) expected, got ", x} ; 
vRep:{$[""~x; 1b; "REP"~x; 1b; '"replace flag expected (omit to copy; 'REP' to replace), got ",x]} ;
vPercent:{if[match[x; "^[0-9]{1,2}%$"] or x in ("";"100%"); :x]; '"percent increment (e.g. 25%) for phase-in expected, got ",x};
vInterval:{if[match[x; "^[0-9]+[mhd]$"] or x~""; :x]; '"time interval (e.g 20x where x is m=minutes h=hours d=days) expected got ",x}; 

vWhere:{if[match[x; "^([a-zA-Z0-9_]+)[ \t]*(>|<|=|>=|<=|like|in|within)[ \t]*(-?[0-9]+|\"[^\"]*\"|[`a-zA-Z0-9_/:;\\.]+)$"]; :x];
 '"variable to literal comparison expected, got ", x} ;

vCriteria:{ `_ emptydict vOneCriterion/ flip "S=," 0: x} ;
vOneCriterion:{[D;p] 
  if[not (p 0) in `address`stype`sversion`condition`qfile;  /for host, use address:"hostname*" 
  '"key name for each criterion must be one of: address, stype, sversion, condition, qfile"] ;
  if[(p 0)=`sversion; D[p 0]: vInt p 1; :D] ;  /sversion compares using "=" an integer
  if["`"= first p 1; D[p 0]:`$ 1_ p 1; :D] ;   /anything else compares using "=" a symbol (when value begins with `)
  D[p 0]: p 1;                                 /otherwize using "like" a string.
  D
 } ;

vSettings:{ `_ emptydict vOneSetting/ flip "S=," 0: x};
vOneSetting:{[D;p]
  if[(p 0)=`host;      D[p 0]:vHost p 1; :D] ;  /note: "host" setting only suppored by "migrateServers".
  if[(p 0)=`address;   D[p 0]:vAddr p 1; :D] ;
  if[(p 0)=`stype;     D[p 0]:vStyp p 1; :D] ;
  if[(p 0)=`sversion;  D[p 0]:vInt  p 1; :D] ;
  if[(p 0)=`condition; D[p 0]:vCond p 1; :D] ;
  if[(p 0)=`qfile;     D[p 0]:vFile p 1; :D] ;
  '"key name for each setting must be one of: address, host, stype, sversion, condition, qfile, got ", str p 0 ;
 };
vCond:{[expr] 
  if[("\""=first expr) and "\""=last expr;                          /if expression is quoted, 
    expr: ssr[; "\\\""; "\""] 1_ -1_ expr ;                         /  unquote, and unescape embedded quotes
  ];
  skel: ssr[;"(";" "] ssr[;")";" "] expr ;                          /changing grouping cannot inject anthing
  skel: ssr[;"&";"|"] ssr[;" and ";"|"] ssr[;" or ";"|"] skel;      /changing conjunctions cannot inject anything
  skel: ssr[;" not ";" "] skel ;                                    /negation cannot inject anything
  vWhere each "|" vs trim skel ;                                    /each remaining fragment should be a comparison                             
  expr
 };



/***** extras ******

/this sanitizes a comparison expression after calling "parse"
/1. allow only comparison operators: note <= >= parse as composites "not>" and "not<".
/2. first operand must be a symbol atom (meaning variable name - literal symbols parse enlisted).
/3. second operand must be a literal.
/3.1 when a general list starts with an "enlist" command, drop it to obtain its result.
/3.2 for a general list, allow only list of strings or enlisted list of symbols.
/3.3 disallow symbol atom (meaning variable name)
/3.4allow atom or list with type <20 (no enum, table, dict, function etc.)
isComp:{x in $[1=count x; (=; <; >; like; in; within); ((';~:;=); (';~:;>); (';~:;<))]} ;
isLitt:{n:type x; if[n=0; if[enlist~x 0; x:1_ x; n:type x]]; $[n=0; all (type each x) in\: (10 11h); n=-11; 0b; (abs n)<20]} ; 
okwhere:{(isComp x 0) and (-11=type x 1) and isLitt x 2} ; 

/alternate authetication for admin interface - without maintaining a password.
/Allow access to anyone with write access to a particular directory in the mserve home.
/1. The shell scripts will write a file containing a random number into this directory.
/2. The q program invoked by the shell script will issue an hopen for the "admin" user with this random number as the password.
/3. The .z.pw handler in the admincli.q will check that the password submitted matches what is in the file.
/4. The file is deleted by admincli.q after invoking "applyChanges".
/5. That directory will have chmod 600 (rw) and the file with the random number will have chmod 500 (r-x)
/6. This should allow (only) the mserve user account to create or delete such a file, but not overwrite it.
/   That allows the file to also serve as a lock, to warn against two admins editing the configuation at the same time.

-1 "admincli.q loaded" ;

