/Replay the tick.q logs for a given date/time range, list of tables, list of symbols.
/Usage: q tick/tplog.q  schema log   (same as tick.q but no port or timer).

/Replay all logs from "fr" to "to" days prior to most recent log on file
rep:{[fr;to]
  fr: abs fr; to: abs to;
  if[fr<to; a:fr; fr:to; to:a] ;

  ls: (.z.x 1),"/", (.z.x 0), "*" ; 
  -1 "log files: ", ls;
  list: desc system "ls ", ls ;
  if[0=count list; '"No logs found"] ;
  if[fr>=count list; fr:-1+ count list; if[fr<to; '"No logs prior to ",(string to), "days before most recent log"]] ;

  list: reverse list to+ til 1+fr-to ;
  dates: 0N! "D"$ (-1+ count ls)_/: list ;
  if[not all 1= 1_ dates - prev dates; '"Error: log dates not contiguous (missing days)"] ;
  rep2 each `$":",/: list ;
 };

rep2:{[logfile] 
  0N!(type logfile; logfile) ;
  @[-11! ; logfile; repError] ;
 };

repError:{[e]
  -2 "Error replaying log: ", e ;
  if[not e like "badtail"; :(::)] ;
  i: -11!(-2;logfile);                                /replay log file, initializing "i" to its current length.
  (`logfile; logfile; i) ;
  if[0<=type i;                                       /if -11! returns a list, log file is corrupt, second item is
    -2 (string logfile)," is a corrupt log. Truncate to length ",(string last i)," and retry"; /position of first invalid rec.
  ];
 };

upd:{[t;x] -2 "replay '", (string t), "' last ts= ", (string last x 1), " ", (string last x 2), "  count=", (string count first x) } ;

 
