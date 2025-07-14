/ launch from directory containing symbolMaster.csv
/ get sendto port number (always on localhost)

// sendto -> parses command line arguments for port number
// if the first arg is not nothing, it makes the port it. Otherwise, defaults to localhost:5001
// timer -> parses command line arguments for timer
// if the second arg is not nothing, it makes the timer it. Otherwise, defaults to 3000 ms = 3s.
//
// The print statement implies the purpose here. These are the port to and frequency at which feed.q will send the feed to.
// sendto: "J"$ $[0<count .z.x 0; .z.x 0; "5001"] ; // ✅
// timer: "J"$ $[0<count .z.x 1; .z.x 1; "3000"] ; // ✅
// 0N!"Starting feed.q... will send to port ", (string sendto), " every ", (string timer), " ms" ; // ✅


/ get symbols with company name from symbolMaster.csv
// symbolMaster contains 4 columns. Only the first and last matter. i.e. sym and company = symbol and company name.
// sn -> implies just a two column table. Symbol | CompanyName
// cnt -> the count, the number of symbols
// s -> just the symbol.
// n -> just the comapny name
sn: flip ("S  *"; ";") 0: 1 _  read0 `:symbolMaster.csv ; 
cnt:count sn 
s:first each sn 
n:last each sn 
//
//
// # in this context is the 'take' operator. for n # list, it produces a list of n items using the lists items, cyclically.
// p (price) ->  a list of prices equal in number to the list of symbols in SymbolMaster. 
// m (mode) -> a list of modes, same as above
// c (cond) -> a list of conditions, same as above
// e (ex) ❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗❗
/ generate data for rdb demo (tick.q unchanged except for the above)
p:cnt # (33 27 84 12 20 72 36 51 42 29) / price 
m:cnt # " ABHILNORYZ" / mode ✅
c:cnt # " 89ABCEGJKLNOPRTWZ" / cond ✅
e:cnt # "NONNONONNN" / ex  ⚠️

/ init.q

pi:acos -1 // calc pi = 3.141592... ✅
gen:{exp 0.001 * normalrand x} // generates random numbers according to scaled normal distribution using normalrand (defined next). Just gens and rescales. ✅
normalrand:{(cos 2 * pi * x ? 1f) * sqrt neg 2 * log x ? 1f} // generates x random, normally distributed numbers ✅
// randomize -> sets a random seed for sim 
// concats "\\S " with an integer representing the number of seconds since BoT scaled by 80% using the comma operator. 
// value <-- extracts and executes command \S, setting a random seed this way.
randomize:{value "\\S ",string "i"$0.8*.z.p%1000000000} 
// rnd -> rounds number to 2 decimal points
rnd:{0.01*floor 0.5+x*100} // scales by 100, adds 0.5 (to get last digit to carry if > 5), floors to chop dec bit, scales back original scale. ✅
vol:{10+`int$x?90} // randomly select x nums from the range 10 - 99 and casts them to ints (instead of long) ✅

/ randomize[] // setting random seed (commented out) ✅
// setting random seed manually here:
\S 235721

/ =========================================================
/ generate a batch of prices
/ qx index, qb/qa margins, qp price, qn position ✅
batch:{
    // inference: x = size of batch
    // likely initializing sim
 d:gen x; // d -> x rand nums acc. to exp. scaled norm. dist. ✅
 // globals being set here::
 qx::x?cnt; // qx -> index of symbol, x symbols indices chosen at random. ✅
 // qb, qa -> x nums chosen frm (0, 1), elmts rounded using rnd (round, line64)
 // they are lists of x elements
 qb::rnd x?1.0; // quantity bid ✅
 qa::rnd x?1.0; // quantity ask ✅
 // n -> list of llists where each list gives the indices of elmts of qx qx which are equal to 1, 2, etc.
 // cnt = num symbols
 // e.g. n = n0;n1;n2;n3;... where n0 = (), n1 = 1 3, n2 = 2 5, n3 = 4 6, n4 = 0 for qx = 7 1 2 1 3 2 3
 // useful if you want to look up symbols in qx via val... n[val] -> locations of val in qx
 n:where each qx=/:til cnt; // creates n, a list of locations of vals, using index as val key (inverted index by value)
 // reminder: list*list is element wise multiplication -> result is same length as input, lists must match in length
 s: p*prds each d n; // (prices)*[ (straight products over d: x random nums); ('stacking' products over n) ]
 qp::x#0.0; // 
 (qp raze n):rnd raze s;
 p::last each s;
 qn::0
 }
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

