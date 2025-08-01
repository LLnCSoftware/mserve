/Replay the tick.q logs for a given date/time range, list of tables, list of symbols.
/Usage: q tick/tplog.q  schema log   (same as tick.q but no port or timer).

/Replay all logs from "fr" to "to" days prior to most recent log on file
rep:{[fr;to]
  ls: (.z.x 1),"/", (.z.x 0), "*" ; 
  -1 "log files: ", ls;
  list: desc @[system; "ls ", ls, " 2>/dev/null"; ()] ;
  if[0=count list; -2 "No logs found (new database)"; :(::)] ;

  dates: "D"$ -10#/: list ;
  if[-14h= type fr; n:dates?fr; if[n>=count dates; '"No log for date ", string fr]; fr:n] ; 
  if[-14h= type to; n:dates?to; if[n>=count dates; '"No log for date ", string to]; to:n] ;
  
  fr: abs fr; to: abs to;
  /0N!(fr; to; count list) ;
  if[fr>=count list; fr:-1+ count list] ; 
  if[fr<to; -2 "Already up to date. (earliest requested ", (string fr), " day prior, latest ", (string to), ")"; :(::)] ;

  list: reverse list to+ til 1+fr-to ;
  dates: dates: 0N! "D"$ -10#/: list ;
  if[not all 1= 1_ dates - prev dates; '"Error: log dates not contiguous (missing days)"] ;
  rep2 each `$":",/: list ;
 };

rep2:{[logfile] 
  0N!(logfile) ;
  @[-11! ; logfile; repError] ;
  repDayEnd "D"$ -10# string logfile ;
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

repDayEnd:{[date] -2 "endofday: ", string date; } ; /Override to process data after replaying each log file
upd:{[t;x] 
 /-2 "replay '", (string t), "' last ts= ", (string last x 1), " ", (string last x 2), "  count=", (string count first x) 
 } ;

 
