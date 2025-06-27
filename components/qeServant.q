/simulate opening database upon load by just creating random data
trade:([] time:`timestamp$();sym:`symbol$();price:`float$();size:`int$()) ;
n:3000000 ;
ed: .z.d ;
sd: ed-600 ;
st:09:00:00.000 ;
et:16:00:00.000 ;
portfolio:`GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS ;
`trade insert ((sd+n?ed-sd)+(st+n?et-st); n?portfolio; .01 xbar n?100f; n?10000) ;
`time xasc `trade ;
\c 10 133
-1 "trades" ;
show trade ;

bs:60000 ;            /bucket size in milliseconds.
onems: `int$ 1e6 ;    /ms->ns to round timestamp
agg:{[w;tbl] 
 select agtrades:count i, agsize: sum size, vwap: size wavg price, twap: avg price 
 by sym, (w*onems) xbar time from tbl
 };

-1 "\nbuckets" ;
buckets: agg[bs; trade] ;
show buckets ;


/api endpoints
.api.echo:{x} ;

/append vwap and qe=(price-vwap)/vwap to trades
.api.qeVwap:{[beg;end;syms;win]
  if[(type beg) within (-19;-17); beg: beg+ .z.d] ;      /if only time specified for beg, use current date
  if[(type end) within (-19;-17); end: end+`date$beg] ;  /if only time specified for end, use beg date
  if[-18=type win; win: 1000* `int$ win] ;               /window specified as second -> convert to ms.
  if[-17=type win; win:60000* `int$ win] ;               /window specified as minute -> convert to ms.
  0N!(beg;end;win) ;
  select vwapT[00:05;time;syms] from trade where time within (beg;end)
 }

/append twap and qe=(price-twap)/twap to trades
.api.qeTwap:{[beg;end;syms;win]
  if[(type beg) within (-19;-17); beg: beg+ .z.d] ;      /if only time specified for beg, use current date
  if[(type end) within (-19;-17); end: end+`date$beg] ;  /if only time specified for end, use beg date
  if[-18=type win; win: 1000* `int$ win] ;               /window specified as second -> convert to ms.
  if[-17=type win; win:60000* `int$ win] ;               /window specified as minute -> convert to ms.
  0N!(beg;end;win) ;
  twap[win;] select from trade where time within (beg;end), sym in syms
 }

test:{[win;beg;end;syms]
  if[(type beg) within (-19;-17); beg: beg+ .z.d] ;      /if only time specified for beg, use current date
  if[(type end) within (-19;-17); end: end+`date$beg] ;  /if only time specified for end, use beg date
  if[-18=type win; win: 1000* `int$ win] ;               /window specified as second -> convert to ms.
  if[-17=type win; win:60000* `int$ win] ;               /window specified as minute -> convert to ms.
  tbl: select from trade where time within (beg;end), sym in syms ;
  wend: tbl `time ;
  wbeg: wend- onems*win ;
  wj[(wbeg; wend); `sym`time; tbl; (0!buckets; (sum;`agtrades); (sum;`agsize); (wavg;`agsize;`vwap))]
 };

/---------
vwapT:{[w;t;s] select trades:count price, sum size, vwap:size wavg price from window[w;t;s;trade]} ;
vwapB:{[w;t;s] select sum trades, sum size, size wavg vwap from window[w;t;s;buckets]} ;

twapT:{[w;t;s] select trades:count price, twap:avg price from window[w;t;s;trade]} ;
twapB:{[w;t;s] select sum trades, avg twap from window[w;t;s;buckets]} ;

window:{[w;t;syms;tbl] 
  w:w2ms w;  t:`timestamp$ t; 
  select from tbl where time within (t-w*onems;t), sym in syms
 };
w2ms:{[w] 
  n:type w; w:`long$ w; 
  if[n within (-7;-5); :w]; if[n=-18; :1000*w]; if[n=-17; :60000*w]; 
  '"window size type error: expect integer (ms), second (h:m:s), or minute (h:m)"; 
 };





/simulate closing database upon exit by just issuing a message
.z.exit:{-1 "servant closed"} ;

/ provide "secure invocation" protocol
\l secure_invocation.q                   /load the module
.z.pg:{"USE ASYNC"} ;                    /disallow synchronous
.z.ps:validateAndRunAsync;               /use async protocol from secure_invocation.q

0N!"qeServant loaded" ;
