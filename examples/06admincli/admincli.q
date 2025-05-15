\l authent.q
\l scripted.q
\l edconfig.q

/***** Synchronous Api for administrator commands *****.
.z.pg:{ @[invoke; x; {[e] :"ERROR ", x}} ;

invalid:"Admin commands must be lists of strings" ;
invoke:{[x]
  if[0<>type x; :invalid]; if[any 10<>abs type each x; :invalid] ;
  if[(x 0)~"search"; :search vWhere each 1_ x] ;
  if[(x 0)~"browse"; :browse (vPos x 1; vPos x 2; vInt x 3)] ;
  if[(x 0)~"editServer"; :editServer[vAddr x 1; vPos x 2; vSettings x 3]] ;
  if[(x 0)~"addServer"; :addServer[vAddr x 1; vPos x 2; vSettings x 3]] ;
  if[(x 0)~"copyServer"; :copyServer[vAddr x 1; vPos x 2; vSettings x 3; vRep x 4]] ;
  if[(x 0)~"upgradeServers"; :upgradeServers[vSymb x 1; vCriteria x 2; vSettings x 3; vRep x 4]] ;
  if[(x 0)~"migrateServers"; :migrateServerse[vSymb x 1; vCriteria x 2; vSettings x 3; vRep x 4]] ;
  if[(x 0)~"clearChanges"; :clearChanges[]] ;
  if[(x 0)~"ApplyChanges"; :applyChanges[vPercent x 1; vInterval x 2]] ;
  if[(x 0)~"saveConfiguration"; :saveConfiguration[]] ;
  if[(x 0)~"cancelPhaseIn"; :cancelPhaseIn[]] ;
  if[(x 0)~"finishPhaseIn"; :finishPhaseIn[]] ;
  0N!"Unexpected routing command: ", x 0 ; 
 } ; 

vInt:{}
vSymb:{}
vAddr:{}
vPos:{}
vRep:{}
vWhere:{} ;
vSettings:{}
vCriteria:{}
vPercent:{}
vInterval:{} 



isComp:{x in  $[1=count x; (=; <; >); ((';~:;=);  (';~:;>); (';~:;<))]} ;
okwhere:{(isComp x 0) and (-11=type x 1) and (type x 2) in (11 10 -5 -6 -7h)} ; 





