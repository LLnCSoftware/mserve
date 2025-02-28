# 04dispatch

## About this Example

We show how to implement a dispatch algorithm as a plugin.  

The current default dispatch algorithm is "match" which attempts to provide 
[Locality of reference](https://en.wikipedia.org/wiki/Locality_of_reference)) 
by using the first argument to pack a servant. The match algo is both the default and the algo
discussed in this example because Locality of Reference is a very powerful optimization for
many KDB applications. 

To pick a built in dispatch algo, see
"MServe Glossary" entry on **Dispatch Algorithm** in readme.md. 

If you don't like any of the included dispatch algorithms ('orig', 'even', 'match')
you could implement you own, as suggested in this example.

This example uses the same client and servant as the examples 02quickauth and 03multihost,
including secure\_invocation.q but without the authentication and authorization plugins.

## New/Modified Files

match.q - An mserve plugin implementing a dispatch algorithm (actually the same as the included "match" algorithm,
but displays the name "match-plugin" on startup).  

## How it Works

To provide a dispatch plugin you would:

- Write a new "q-file" (in our example "match.q") which defines two global variables
  - check: function implementing your new dispatch algorithm
  - algo:  provides a name for your algorithm which is displayed on the console at startup

- Include your filename in the MSERVE\_PLUGINS environment variable when starting mserve\_np.q
  - for example:  'MSERVE\_PLUGINS="match.q" q mserve\_np.q 2 servant.q'

### The "check" function

- The check function takes no arguments and returns no value. 
- The check function examines the enqueued queries, and attempts to match some query with an available server.
- If successful, it calls the "send\_query" function, providing the server handle and query id as arguments. 

### Resources available in mserve\_np.q

- **getArguments** - function which parses specified command, which must be the invocation of a user-defined function,
   always interpreting symbols in arguments as literals, not variables; and rejecting function evaluation in the arguments.
   (In match.q, used to obtain the routing string as the first argument to the command).
- **h**            - dictionary which maps each servant handle to the list of queries pending on that handle.
                     (In match.q, used to determin if a particular servant is busy.) 
- **hroute**       - dictionary which maps each servant handle to its last routing symbol.
                     (In match.q, used to determine which queries a particular servant may accept.)
- **hidle**        - dictionary which maps each servant handle to its idle timestamp, i.e. when last query finished.
                     (In match.q, used to reset the "hroute" value of a servant to "allow any query" after a period of inactivity.
- **addMs**        - function which adds milliseconds to a timestamp.
- **nextCheck**    - timestamp which schedules a call to "check" at the specified time (+infinity 0Wp to surpress)
                     (In match.q, schedules a call on the timer when "check" fails to dispatch a request although
                      the queue is not empty. Normally the check function is called when a new query or response 
                      is received. However it may happen that none of the enqueued queries are eligable for any servant,
                      and no servants are busy. In that case, without a call on the timer, the remaining queries could
                      not run until a new query is received, which might not happen).

### Understanding the example "match.q"

The algorithm may be briefly described as follows:
1. Compute a routing symbol for any queries for which "route" is null in the queries table.  
2. Find all queries whose routing symbol is also held by some not-busy servant handle
3. If any found, dispatch the first such query to the first such handle, and return.
4. Otherwise, find all queries whose routing symbol is NOT held by any servant (busy or not).
5. Also, find all handles which are not busy and whose routing symbol is unset or expired
6. If both found, dispatch the first such query to the first such handle, and return.
7. Otherwise, If the queue is not empty, request a call on the timer.


## How to test match.q: To Do and Observe

**start the server**

We run with 8 servants on localhost. 
We use 8 servants because the client submits queries for 8 distinct symbols on the timer, 
and we want each symbol to be routed to its own servant.

```
MSERVE\_PLUGINS='match.q' q mserve\_np.q 8 servant.q -p 5000
```

Make sure to wait for the end of the startup messages and be sure it says at the bottom: 

```
Connect to servants
OK
Using dispatch algorithm: 'match-plugin'
"mserve_np.q loaded"
```

**start the client**

```
 q qs.q localhost 5000    /start the client
 \t 2000                  /start the timer
```
Let it run about 60 queries then stop the timer and let the backlog clear,
a few minutes in general. 

**Check results using the mserve console**

To check results we use the fact that mserve\_np.q does not purge queries
from its internal table until 30 minutes after they finish. So after running
the test you can query this internal table "queries" to see which servant
processed each request.

After all requests have finished, in the mserve terminal, enter the following query:

```
select route by slave_handle from queries

slave_handle| route                                                                 
------------| ----------------------------------------------------------------------
-13         | `IBM`IBM`IBM`IBM`IBM`IBM`IBM`IBM`IBM                                  
-12         | `UBS`UBS`UBS`UBS`UBS`UBS                                              
-11         | `GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG          
-10         | `VOD`VOD`VOD`VOD                                                      
-9          | `AAPL`AAPL`AAPL`AAPL`AAPL`AAPL`AAPL`AAPL`AAPL`AAPL                    
-8          | `BA`BA`BA`BA`BA`BA`BA`BA`BA`BA`BA`BA`BA                               
-7          | `GS`GS`GS`GS`GS`GS`GS`GS`GS`GS                                        
-6          | `MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT
```

The column in the queries table that identifies the servant process is "slave\_handle",
(that name goes back to the original). We could get the host and port using the dictionary
h2addr, but really we don't care.

The point (with match.q) is just to verify that each servant processed queries for only one route.
If you were testing a more sophisticated algorithm, you would use similar queries to verify that it is behaving as expected.

**Compare to the "even" algorithm**

Repeat the above, changing the command issued in step 1 to:

```
MSERVE_ALGO='even' q mserve\_np.q 8 servant.q -p 5000
```

Make sure to wait for the end of the startup messages and be sure it says at the bottom: 

```
Connect to servants
OK
Using dispatch algorithm: 'even'
"mserve_np.q loaded"
```

Then start the client as above and again let it run for about 60 requests.
Then stop the timer and let the backlog clear.

If you were to do the same query as before "select route by slave\_handle from queries"
You would see a blank result for each "slave\_handle", becuase no routing string is provided 
by the "even" algorithm.

But you can still check which requests ran where by showing the actual query.

```
select query by slave_handle from queries

slave_handle| query                                                                                             ..
------------| --------------------------------------------------------------------------------------------------..
-13         | "proc1 `MSFT" "proc1 `BA"   "proc1 `GS"   "proc1 `GS"   "proc1 `GOOG" "proc1 `BA"   "proc1 `IBM"  ..
-12         | "proc1 `GS"   "proc1 `GOOG" "proc1 `GOOG" "proc1 `AAPL" "proc1 `IBM"  "proc1 `MSFT" "proc1 `GOOG" ..
-11         | "proc1 `BA"   "proc1 `MSFT" "proc1 `BA"   "proc1 `IBM"  "proc1 `AAPL" "proc1 `GOOG" "proc1 `GOOG" ..
-10         | "proc1 `AAPL" "proc1 `UBS"  "proc1 `MSFT" "proc1 `AAPL" "proc1 `BA"   "proc1 `MSFT" "proc1 `GS"   ..
-9          | "proc1 `BA"   "proc1 `GOOG" "proc1 `GOOG" "proc1 `BA"   "proc1 `UBS"  "proc1 `IBM"  "proc1 `IBM"  ..
-8          | "proc1 `AAPL" "proc1 `IBM"  "proc1 `AAPL" "proc1 `AAPL" "proc1 `VOD"  "proc1 `MSFT" "proc1 `GOOG" ..
-7          | "proc1 `BA"   "proc1 `IBM"  "proc1 `BA"   "proc1 `GS"   "proc1 `MSFT" "proc1 `MSFT" "proc1 `UBS"  ..
-6          | "proc1 `VOD"  "proc1 `AAPL" "proc1 `UBS"  "proc1 `GS"   "proc1 `MSFT" "proc1 `BA"   "proc1 `BA"   pro..
```

