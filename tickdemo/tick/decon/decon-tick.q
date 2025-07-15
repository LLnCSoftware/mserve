/tick.q functionality deconstructed. 
/comments and whitespace added, no code changes
"kdb+tick 2.8 2014.03.12"

/q tick.q schmea-file log-directory [-p 5001] [-o h]  
system "l tick/",(src:first .z.x,enlist"schema"),".q"; /default schema file changed sym -> schema  
if[not system"p";system"p 5001"] ;                     /default port changed 5010 -> 5001

\l tick/u.q                                            /extend the .u namespace from u.q (pub-sub)
\d .u                                                  

/Create or rotate log file
ld:{[x]                                               /input parameter is the current date
  L::`$(-10_string L),string x;                       /replace date suffix on log file with input parameter x
  if[not type key L; .[L;();:;()]];                   /if file does not exist, use "amend" to create an empty file                                     
  i::j::-11!(-2;L);                                   /replay log file, initializing "i" and "j" to its current length.
  if[0<=type i;                                       /if -11! returns a list, log file is corrupt, second item is
    -2 (string L)," is a corrupt log. Truncate to length ",(string last i)," and restart"; /position of first invalid rec.
    exit 1
  ];
  hopen L                                             /Open log file; return handle
 };

/Initialization
tick:{[x;y]                                           /Input paramters are the schema file and log directory from cmd line
  init[];                                                       /initialize u.q
  if[not min(`time`sym~2#key flip value@) each t; '`timesym];   /Require that first 2 cols of each table are time and sym
  @[;`sym;`g#] each t;                                          /Apply the "g" attribute to the sym column of each table
  d::.z.D;                                                      /set global "d" to the current date
  if[l::count y;                                                /if log directory specified,
    L::`$":",y,"/",x,10#".";                                    / set log file path a with placeholder for date
    l::ld d                                                     / open log file for current date, set global "l" to its handle.
  ]
 };

/ end of day processing
/ 1. call .u.end in u.q to invoke .u.end (end of day) in each subscriber
/ 2. increment the current day
/ 3. If logging, close log file, and reopen by sending ".u.ld d" command to handle 0.
endofday:{ end d; d+:1; if[l; hclose l; l::0(`.u.ld;d)]};  

/ detect end of day
/ input parameter is current day. If greater than global "g"  invoke "endofday" above
ts:{if[d<x; if[d<x-1; system"t 0";'"more than one day?"]; endofday[]]};

/ When timer frequency set on command line
/ Will accumulate records in temporay tables, and publish on timer
if[system"t";
  .z.ts:{                       /on timer: here "t" is global .u.t from u.q, containing all table names from schema
    pub'[t;value each t];          /publish content of each table listed in "t".
    @[`.; t; @[;`sym;`g#] 0#];     /Drop all rows from each tale listed in "t" and reapply the "g" attribute.
    i::j;ts .z.D                   /set log record count to received record count
  };

  upd:{[t;x]                       /set upd function to receive: table name, rows to append from feed
    if[not -16=type first first x;     /if type of first column of received data is not "timespan"
      if[d<"d"$ a:.z.P;.z.ts[]];                            /if end of day, call .z.ts to publish accumulated values in tables
      a:"n"$a;                                               /convert current timestamp to timespan
      x:$[0>type first x;a,x;(enlist(count first x)#a), x]   /prepend column of current timespan to x ? (makes no sense)
    ];             
    t insert x;                       /save received rows in table t (to be published on next timer tick)
    if[l;l enlist (`upd;t;x);j+:1];   /if logging, write upd command to log, increment received record count
 }];

/When timer frequency not set on command line
/Will run timer every second to check for end of day, but publish received rows immediately.
if[not system"t";                           
  system"t 1000";                              /Default timer fequency to one second
  .z.ts:{ts .z.D};                             /Check for end of day using current date.                                            
  upd:{[t;x]                                   /Set upd function to receive: table name, rows to append from feed.
    a:.z.P; ts "d"$a ;                              /Get current timestame, use date portion to check for end of day
    if[not -16=type first first x;                  /If first column of rows to append is not a timespan
      a:"n"$a;                                                /convert current timestamp to timespan
      x:$[0>type first x; a,x; (enlist(count first x)#a), x]  /prepend column of current timespan to x ? (makes no sense)
    ];
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
