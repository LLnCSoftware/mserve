# 05scripted

## About this Example

We create a dispatch algorithm which explictly routes each request to a servant based on a configuration file.  

This algorithm also provides the ablilty to modify the configuration without shutting down or suspending operations.
That includes the ability to phase-in a new servant, so that the percentage of queries going to the 
new servant increases over a time interval. If a configurable number of errors occur in the new servant
while the phase in is in effect, the new servant is removed and the original configuration restored.

## New/Modified Files

* scripted.q - An mserve plugin implementing this dispatch algorithm.
* scripted.csv - The configuration file

### Admin Scripts

* getrule "like-pattern"
    * Invokes the "getRule" method in scripted.q.
    * Will return all rules from the current routing table which match the pattern, as csv-lines
    * Takes 1 argument, a quoted string ($pattern).
    * Gets the host and port for mserve\_np.q from an env variable MSERVE\_ADDR, defaulting to localhost:5000
    * Pipes a line of code into a new q-session to send a 'getRule "$pattern"' command to mserve on the synchronous interface.

* setrule position "csv-line" "phase-in spec"  
    * Invokes the "setRule" method in scripted.q
    * Will place the specified csv-line in the routing table at the specified (zero-based) position.
    * When address in csv-line matches a rule already in the table, that rule will be replaced (and moved if necessary).
    * When address in csv-line does not match, the rule will be added at the bottom of the table and then be moved if necessary.
    * Takes 3 arguments, a numeric string ($pos) and two quoted strings ($rule and $phasein).
    * Gets the host and port for mserve\_np.q from an enx variable MSERVE\_ADDR, defaulting to localhost:5000
    * Pipes a line of code into a new q-session to send 'setRule[$pos; $rule; $phasein]' command to mserve on the sync interface.

Note: When used without authentication (as it is here), this synchronous interface is highly insecure.
To fix that you can add authentication, in particular for an "admin" role, that grants usage of the interface.
Alternatively, you could remove the synchronous interface (.z.pg), and invoke these functions from the mserve q-console.

## How it Works

Similar to the previous example 04dispatch, which implemented the "match" dispatch algorithm in a plug in,
This plugin overrides the "check" function which performs dispatch in mserve\_np.q.

However, when this plugin is used, the command line to start mserve\_np.q will NOT contain arguments
for the number of servants and a servant q-file to run in each of them.

Instead it will have single argument which specifies a configuration csv file, which will explicity 
list the host and port for each servant, and the q-file to run there. In particular, there can 
be more than one distinct q-file in the configuration.

For this example the command to launch mserve will look like:

```
MSERVE_PLUGINS='scripted.q' q mserve_np.q scripted.csv -p 5000
```

### The configuration file

A complete listing of scripted.csv is shown below:

```
address,stype,sversion,condition,qfile
localhost:5001,low,1,(symbol within `A`F),servant.q
localhost:5002,mid,1,(symbol within `G`L),servant.q
localhost:5003,high,1,(symbol within `M`T),servant.q
localhost:5004,other,1,(1b),servant.q
```

Here, "address" specifies the host and port for the servant process, and "q-file" the program to run there.

The "stype" and "sversion" columns are only used to phase-in new servants.
When a new servant is added while mserve is running you can specify a percentage and a time interval.
Each interval the probablity that a qualifying query goes to the new server will increase by the specified
percentage, until it has held at 100% for a full interval. 



The "condition" is a "q" boolean expression which determines whether this servant is qualified for a particular query.
The variables in the boolean expression are derived from the arguments to the query, and any "options" included with
the request by the function "getRoutingCriteria" (similar to getRoutingString in the match algorithm).

In general, a query will be sent to the first servant in the table for which the condition evaluates as true,
and which is not currently busy. 


In this case there is only one variable "symbol" which comes from the first (and only) argument to the query.
To use this plugin in another context where other variables are required, you can write your own
getRoutingCriteria function as a second plugin, which should follow scripted.q in the MSERVE\_PLUGINS setting.

In the above you can see that the first 3 servants are designated for symbols within the alphabetic ranges,
A-F, G-L, and M-T respectively. 

While I could have used (symbol within `U`Z) for the last servant, I want to illustrate the use of (1b) as a 
"fallback" or "catch all" for all queries for which none of the previous conditions evaluate as true.

In general, a query will be sent to the FIRST servant in the table for which the condition evaluates as true.

That allows a servant at the bottom of the file with condition (1b) to serve as a fallback.
If a fallback is not provided, and none of the conditions evaluate as true, the query cannot be dispatched 
and will return an "ERROR: No Qualified Server" message.

Similarly, if the alphabetic ranges above were not disjoint, but had some overlap, a query whos symbol is in 
the overlap would be qualified for more than one server. In that case it would be sent to the first qualifying 
server WHICH IS NOT BUSY.

However a query will not be sent to a fallback just because its qualifying servers are busy, only when there
are no qualifying servers at all.

 


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

