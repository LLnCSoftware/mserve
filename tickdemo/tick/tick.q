/tick.q functionality deconstructed. 
/comments and whitespace added, no code changes
"kdb+tick 2.8 2014.03.12 modified since 2025.07.15 Eric Lazarus"

/q tick.q schmea-file log-directory [-p 5001] [-o h]  
system "l tick/",(src:first .z.x,enlist"schema"),".q"; /default schema file changed sym -> schema  
if[not system"p";system"p 5001"] ;                     /default port changed 5010 -> 5001

\l tick/u.q                                            /extend the .u namespace from u.q (pub-sub)
\d .u                                                  

/Create or rotate log file
i:j:0 ;
ld:{[x]                                               /input parameter is the current date
  L::`$(-10_string L),string x;                       /replace date suffix on log file with input parameter x
  if[not type key L; .[L;();:;()]; i::j::0];          /if file does not exist, use "amend" to create an empty file                                     
  hopen L                                             /Open log file; return handle
 }

/Initialization
d:0Nd; L:""; l:0i ;                                   /Current date according to incoming data; current log file path; current log handle 
tick:{[x;y]                                           /Input paramters are the schema file and log directory from cmd line
  init[];                                                       /initialize u.q
  if[not min(`id`date`time`sym~4#key flip value@) each .u.t; '"iddatetimesym"]; /Require first 4 cols of each table named: id date time sym
  @[;`sym;`g#] each .u.t;                                       /Apply the "g" attribute to the sym column of each table
  if[0<count y; L::`$":",y,"/",x,10#"." ];                      /If log directory specified, provide log file name w placeholder for date
 };

/ end of day processing
/ 1. x will be current date according to input data. Global date "d" is initially null.
/ 2. Except of startup (d=0Nd), call .u.end in u.q to invoke .u.end (end of day) in each subscriber
/ 2. Set global date "d" to received value "x".
/ 3. If logging, close log file, and reopen by sending ".u.ld d" command to handle 0.
endofday:{if[d<>0Nd; end d]; d::x; if[0<l; hclose l]; if[0<count L; l::0(`.u.ld; d)]};  

/ validate date sequence. Input parameters are first and last date in current burst of data.
/ Each burst must contain only a single date, which must increase in increments of one day.
/ Upon change of date, call "endofday" to rotate log file.
ts:{[x;y]
  /if[x<>y; '"more than one day in burst"] ;
  if[d>x;  '"reversal in date sequence"] ;
  if[d<x; if[(d<>0Nd)& d<x-1; '"gap in date sequence"]; endofday x]
 };

/ When timer frequency set on command line
/ Will accumulate records in temporay tables, and publish on timer
if[system"t";
  .z.ts:{                       /on timer: here "t" is global .u.t from u.q, containing all table names from schema
    /-2 "pub" ;
    pub'[t;value each t] ;         /publish content of each table listed in "t".
    @[`.; t; @[;`sym;`g#] 0#] ;    /Drop all rows from each tale listed in "t" and reapply the "g" attribute.
    i::j                           /set log record count to received record count
  };
 
  upd:{[t;x]                       /set upd function to receive: table name, rows to append from feed
    /-2 "delay '", (string t), "' last ts= ", (string last x 1), " ", (string last x 2), "  count=", (string count first x) ;
    /0N!(t; count first x; last x[1]; last x[2]); /debug
    ts[first x 1; last x 1] ;         /check for end of day
    t insert x;                       /save received rows in table t (to be published on next timer tick)
    if[l;l enlist (`upd;t;x);j+:1];   /if logging, write upd command to log, increment received record count
 }];

/When timer frequency not set on command line
/Timer should not run. Will publish received rows immediately.
if[not system"t";                           
  upd:{[t;x]                                   /Set upd function to receive: table name, rows to append from feed.
    /-2 "immed '", (string t), "' last ts= ", (string last x 1), " ", (string last x 2), "  count=", (string count first x) ;
    /0N!(t; count first x; last x 1; last x 2) ;     /debug
    ts[first x 1; last x 1] ;                       /check for end of date
    f:key flip value t;                             /get column names for table name "t".
    pub[t;$[0>type first x; enlist f!x; flip f!x]]; /publish data for "t" after applying column names
    if[l;l enlist (`upd;t;x);i+:1];                 /if logging, write upd command to log, increment log record count.
 }];
 
\d .                       /back to main namespace
.u.tick[src;.z.x 1];       /run initialization

\
 globals used
 .u.w - dictionary of tables->(handle;syms)
 .u.i - msg count in log file
 .u.j - total msg count (log file plus those held in buffer)
 .u.t - table names
 .u.L - tp log filename, e.g. `:./sym2008.09.11
 .u.l - handle to tp log file
 .u.d - date

/test
>q tick.q
>q tick/ssl.q

/run
>q tick.q sym  .  -p 5010	/tick
>q tick/r.q :5010 -p 5011	/rdb
>q sym            -p 5012	/hdb
>q tick/ssl.q sym :5010		/feed
