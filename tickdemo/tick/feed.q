if[0=count .z.w; '"Usage: q tick/tick.q sendto timer msPerSimDay maxTradesPerDay[/avgQuotesPerTrade] hiwDirectory [startdate]"];

/utilities needed to ingest command line arguments
onems: `long$ 1e6; msPerDay:24*60*60000 ;
inter2ms:{t:last x; v:"J"$ -1_ x; $[t="s";1000*v; t="m";60000*v; t="h";60*60000*v; t="d";24*60*60000*v; "J"$x]} ;
writeHiwFile:{ hiw 0: ("start=",string start; "stop=", string stop; "quoteid=",string quoteid; "tradeid=",string tradeid)};
readHiwFile:{a: flip "=" vs/: read0 hiw; (`$ a 0) set' parse each a 1} ;

/ Ingest command line arguments
sendto: "J"$ $[0<count .z.x 0; .z.x 0; "5001"] ;                /sendto port number 
timer: "J"$ $[0<count .z.x 1; .z.x 1; "3000"] ;                 /ms per timer tick.
msSimDay: inter2ms $[0< count .z.x 2; .z.x 2; "1d"] ;           /time allowed to generate one simulated day of activity (default real time).
interval: "j"$ timer * msPerDay % msSimDay ;                    /simulated time covered by activity generated per timer tick
maxn: "J"$ {$[0<count x; x; "50"]} ("/" vs .z.x 3) 0;           /maximum thousands of trades per simulated day
maxn: "j"$ 1000 * maxn * interval % msPerDay ;                  /maximum trades per timer tick
qpt:  "J"$ {$[0<count x; x; "2"]} ("/" vs .z.x 3) 1;            /average quotes per trade
hiw: `$":", $[0<count .z.x 4; .z.x 4; "data/log"], "/feed.hiw"; /highwater file (starting timestamp, trade id, and quote id) 
start: "P"$ $[0< count .z.x 5; .z.x 5; ""] ;                    /starting timestamp
stop: "P"$ $[0< count .z.x 6; .z.x 6; ""] ;                     /ending timestamp

/Starting and ending timestamp should be specified ONLY when creating a NEW database
/Otherwise they will come from the highwater file which also contains the starting
/sequence numbers for all tables (ie. quotes and trades) to be generated.
/This ensures that regardless of the system being started and stopped
/an unbroken sequence of timestamps and unique identifiers is generated.
/Ending timestamp allows scheduling a stop before disk fills up.
if[not null start; 
  if[0<count key hiw;
   -2 "Specifying start date would invalidate date/time sequence in existing data" ;
   -2 "To create a new database, delete feed.hiw and all log files for current database" ;
   '"feed.hiw"
  ] ;
  quoteid:1; tradeid:1; writeHiwFile[];
 ] ;
if[null start; readHiwFile[]] ; 
if[null stop; stop:0Np] ;
 
-1 "Starting feed.q... will send to port ", (string sendto), " every ", (string timer), " ms." ;
-1 "Speed: ",(string `long$ msPerDay%msSimDay), "x;   Ms covered per send: ", (string interval)
  , ";  Max trades per send: ",(string maxn), ";  Avg quotes per trade: ", (string qpt) 
  , ";  Highwater file: ", (string hiw) ;

/ get symbols with company name from symbolMaster./csv
sn: flip ("S  *"; ";") 0: 1 _  read0 `:symbolMaster.csv ;
cnt:count sn
s:first each sn
n:last each sn

/ generate data for rdb demo (tick.q unchanged except for the above)
p:cnt # (33 27 84 12 20 72 36 51 42 29) / price
m:cnt # " ABHILNORYZ" / mode
c:cnt # " 89ABCEGJKLNOPRTWZ" / cond
e:cnt # "NONNONONNN" / ex

/ init.q

pi:acos -1
gen:{exp 0.001 * normalrand x}
normalrand:{(cos 2 * pi * x ? 1f) * sqrt neg 2 * log x ? 1f}
randomize:{value "\\S ",string "i"$0.8*.z.p%1000000000}
rnd:{0.01*floor 0.5+x*100}
vol:{10+`int$x?90}

/ randomize[]
\S 235721

/ =========================================================
/ generate a batch of prices
/ qx index, qb/qa margins, qp price, qn position
batch:{
 d:gen x;
 qx::x?cnt;
 qb::rnd x?1.0;
 qa::rnd x?1.0;
 n:where each qx=/:til cnt;
 s:p*prds each d n;
 qp::x#0.0;
 (qp raze n):rnd raze s;
 p::last each s;
 qn::0}

len:10000
batch len

/ =========================================================
t:{ 
 if[not (qn+x)<count qx;batch len];
 i:qx n:(qn+til x) mod len; qn+:x;
 (s i;qp n;`int$x?99;1=x?20;x?c;e i)}

q:{ 
 if[not (qn+x)<count qx;batch len];
 i:qx n:(qn+til x) mod len;  p:qp n;  qn+:x;
 (s i;p-qb n;p+qa n;vol x;vol x;x?m;e i)}

dt:{n:neg count first x; 
 t: start+ onems* asc n ? interval;
 (enlist `date$ t), (enlist `time$ t), x
 } ;                     

tid:{n:count first x; 
 id: tradeid+ til n; tradeid::(last id)+1; (enlist id), x};

qid:{n:count first x; 
 id: quoteid+ til n; quoteid::(last id)+1; (enlist id), x};

feed:{ 
  if[(not null stop) and start>=stop; -1 "stop: ", (string start), " >= ", (string stop); exit 0] ;
  h (".u.upd";`trade; tid dt t 1+ rand maxn);
  h (".u.upd";`quote; qid dt q 1+ rand qpt*maxn); 
  start+::interval*onems ;
  0N!(start; quoteid; tradeid) ;
  writeHiwFile[] ;
 } ;

h:0Ni ;
.z.ts:{if[null h; h::@[hopen; sendto; 0Ni]; if[null h; :(::)]]; feed x} ;
.z.pc:{-1 "connection lost"; h::0Ni} ;

system "t ", string timer ;
"feed.q running"
