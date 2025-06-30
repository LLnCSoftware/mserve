/ launch from directory containing symbolMaster.csv
/ get sendto port number (always on localhost)
sendto: "J"$ $[0<count .z.x 0; .z.x 0; "5010"] ;
timer: "J"$ $[0<count .z.x 1; .z.x 1; "3000"] ;
0N!"Starting feed.q... will send to port ", (string sendto), " every ", (string timer), " ms" ;

/ get symbols with company name from symbolMaster.csv
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
/ gen feed for ticker plant

len:10000
batch len

maxn:15 / max trades per tick
qpt:2   / avg quotes per trade

/ =========================================================
t:{
 if[not (qn+x)<count qx;batch len];
 i:qx n:qn+til x;qn+:x;
 (s i;qp n;`int$x?99;1=x?20;x?c;e i)}

q:{
 if[not (qn+x)<count qx;batch len];
 i:qx n:qn+til x;p:qp n;qn+:x;
 (s i;p-qb n;p+qa n;vol x;vol x;x?m;e i)}

feed:{h$[rand 2;
 (".u.upd";`trade;t 1+rand maxn);
 (".u.upd";`quote;q 1+rand qpt*maxn)];}

feedm:{h$[rand 2;
 (".u.upd";`trade;(enlist a#x),t a:1+rand maxn);
 (".u.upd";`quote;(enlist a#x),q a:1+rand qpt*maxn)];}

init:{
 o:"t"$9e5*floor (.z.T-3600000)%9e5;
 d:.z.T-o;
 len:floor d%113;
 feedm each `timespan$o+asc len?d;}

h:neg hopen sendto
/ h(".u.upd";`quote;q 15);
/ h(".u.upd";`trade;t 5);

init 0
.z.ts:feed
.z.pc:{-1 "destination lost"; exit 0}

"feed.q ready"
system "t ", string timer ;

