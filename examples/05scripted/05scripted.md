# 05scripted

## About this Example

We create a dispatch algorithm which explictly routes each request to a servant based on a configuration file.  

This algorithm also provides the ablilty to modify the configuration without shutting down or suspending operations.
That includes the ability to phase-in a new servant, so that the percentage of queries going to the 
new servant increases over a time interval. If a configurable number of errors occur in the new servant
while the phase in is in effect, the new servant is removed and the original configuration restored.

## The servant type and version

(Eric: this section here is to discuss how the stype and sversion columns in the csv file
should actually be used to reconfigure multiple servers in one operation, which is as close
as I come to understanding what you want them for. -- it is temporary.

Where you can help is to go down to where you see: "But what will users want to accomplish ?"
and maybe add some stuff.)

The stype represents a description of a servant that is present in the routingTable in order to be 
able to replace it with a new version, gradually with canary deployment, or 
suddenly with conventional deployments, for example: 

 * hdb-running-on-ec2-t2.small
 * rdb-running-in-Singapore

The sversion is used to indicate which rows are supposed to replace which other rows, either 
via canary deployment or deletion and replacement, so that an admin can say 
"I'm upgrading the software on the rdb-running-in-Singapore to the new commit" 

### A problem with the current system

The servant type (stype) and version (sversion) are tags applied to rows in the routing table.
The type seems to represent the role of the server in the system in some general way that may include
some mixture of the properties of the host, the q-program, and the rule itself. And the version attempts
to represent the evolution of this role over time.

The exact meaning of the servant type might be different from one installation to another, and even
from one version to another.
 
For example, in scripted.csv, the stype really represents the alphabetic range of symbols handled by 
the servant process - it is sort of a proxy for the boolean condition, and all the rows have sversion=1.

When we do our failover demo, we add a new row with the same stype and boolean condition, but with a 
new servant address and q-program (which has a simulated bug), and sversion=2.

Where as "other v1" identified the fallback in the original table, "other v2" identifies the fallback
with the upgraded (bad) q-program in the new table. This is what I mean by the version representing
the evolution of the role with time.

In this case the phase-in and failover worked as intended because there was only one row in the table
with stype=other. If there had been more than one, when a single new server was phased in, ALL of the
original servers with stype=other would be phased out.

It seems that a user doing this would expect to start a new server with the upgraded q-file for each of
the servers with stype=other.

It gets worse if the user makes a mistake and forgets to increment the version number for the new server.
Then the system will think that it is version 1 that is being phased in. Which means that although a new
sevant will be started, ALL the original servers will also be ignored for most of the queries in the
early portion of the phase in... because they all have version 1.

I am sure we can come up with more unfavorable things that can happen.

### Should we bring back the "old version" spec for phase in ?

Originally, I required the user to specify an "old version" to be phased out when requesting a "new version"
to be phased-in. If the "old version" was omitted or not present in the table, nothing would be phased out.
Maybe that was better approach.

Otherwise, after a phase-in all rows with the given stype will have the same sversion.
However the initial configuration, and updates to the table done without phase in could result in different
rows having different versions; that would likely be intentional, but would be destroyed by a later phase in.
Maybe we should require that all rows with the same stype have the same sversion.

Maybe we should require that all rows with the same stype and version have same q-file and/or condition.

What are the implications of saying: 

* We have stype and sversion to support:
    * Replacing collection of old servants (having specified stype or stype and version) with new ones (one-for-one).
    * Adding a copy of each of a collection of existing servants (having specified stype or stype and sversion) (hscaling or vscaling)
    * Decommisioning an old set of servants (having specified stype or stype and version).    
    * Reducing the number of servants (having speciied stype or stype and version) to a specified maximum.

    * Replacing an old servant with a new one (canary or suddenly)  (singular: no need for stype)
    * Decommissioning a single servant                              (singular: no need for stype)

### A set of routing commands

Rather than editing table rows the user should be able to think in terms of what they want to accomplish
in the system, and we should have a specific command to do that, with good error checking.
 
But what will users want to accomplish ?

* Sudden deploy a new servant (or canary) to replace an old one 
* Delete a servant (including after a canary)
* Add a servant 

**We should develop something that is easy to automate with a react UI eventually.**

## Ways to avoid errors 

* Confirmation string and (Y/N) confirm 


* It is almost like the "stype" is a **"description"** field:
    * hdb-running-on-ec2-t2.small or rdb-running-in-Singapore

* I might want to canary in something that I want to use "gently" even though I'm not
  retiring anything yet. (Accomplishable by having no other row with this 
  stype, or nothing with this stype and any other version number.)

1. Upgrade all servants with a given type to a new version of their q-file, retaining same boolean condition.
    * or retain the same q-file but change some configuration things such as:
        * Put it on a different host, perhaps one with more ram or something
2. Move all servants with a given type on a given host, to a new host with different capabilities or location.
    * yes, not in this demo but sure.
        * I don't think we need to implement something with a where clause 
3. Add a copy of a given rule (same type, version, condition, q-file), started on a given host/port.
    * replicating a capability by Horizontally Scaling 
4. Add a copy of a given rule with a new condition (same type, version, q-file) started on a given specified host/port
5. Add a copy of a given rule with the same condition but a new q-file (require type-version change ?) on given host/port (upgrade)
6. Add a brand new rule specifying everything. (should we require a new stype or sversion?)
    * When I am adding a new capability, say an RDB for the last 3 days.
    * In this case, if I say "newCapablity" it should do nothing if the stype is not new, 
      just return an error msg that the shell script can print out. "Retry with unique stype" 
7. Remove a given rule, closing the servants handle to cause it to shut down (terminate on close). 
    * Def want to be able to support but not essential for this demo. 
8. Modify just the condition in a given rule.
    * Changing what a specific servant is being used to do, like change the date range 
      it serves, for example. 
    * I might want to do this for all the servants with a specific stype 
        * Would I ever want to have different booleans for the same stype? 

...

### Managing q-file versions.

At present the only way be can choose between two q-files is by a file system path.
That means if we want to distinguish between two version of (for example) servant.q
we need to give one a different name (e.g. servantbad.q) or put it in a different directory.
Also there is no guarantee that q-files with the same path on different hosts will be identical.



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

