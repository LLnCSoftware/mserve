# 05scripted

## About this Example

We create a dispatch algorithm which explictly routes each request to a servant based on a configuration file.  

This algorithm also provides the ablilty to modify the configuration without shutting down or suspending operations.
That includes the ability to phase-in a new servant, so that the percentage of queries going to the 
new servant increases over a time interval. If a configurable number of errors occur in the new servant
while the phase in is in effect, the new servant is removed and the original configuration restored.


## Changes to Canary Filter

We need to ensure that only newly started servers are "phased in",
and no server is "phased out" unless that is explictly requested.

To make that happen, instead of canaryFilter operating on a servant type, new-version
and optional old-version, it will have a list of servants to phase-in and a list of
servants to phase-out. These lists will be populated by the routing commands, which
might select servants individually (by address), or by type and version.

## Routing Command Interface

We need to allow the user to enter several routing commands before applying them
by updating the routing table. We also need to allow the user to preview the
changes before applying them.

This means we will need 5 new functions:

- editChanges      - Creates a copy of the routing table in which to make changes.
- previewChanges   - Displays a "diff" of the edited copy to the live routing table.
- applyChanges     - Updates the routing table from the copy, and optionally starts a canary.
- cancelChanges    - Discards the copy of the routing table and any associated data structures.
- saveConfiguation - Writes the live routing table out to csv.

A canary may be requested in "applyChanges" via arguments for the percent increment and per-interval.

## Routing Command Set

### editServer function (with args:) address, position, stype, sversion, condition

1. Find the row with "address" (host and port) in the edit buffer
2. Update the specified fields, fields specified as blank will be unchanged.
3. Move the row to the requested position.

* Note: you cannot change the q-file as this would require launching a new server.
* Note: servers can be removed from service by setting their "condition" to (0b).
  but they cannot be removed from the table until they are no longer busy,
  and are disconnected. That might be done in saveConfiguration. 

### addServer function (with args:) address, position, stype, sversion, condition, q-file 

1. Verify that "address" is not already in the buffer.
2. Verify that none of the specified fields are blank.
3. Add a row with the specified fields at the bottom of the buffer.
4. Move the row to the specified position.
5. Add the "address" to the phase-in list.

The new server will be launched in applyChanges. 

### copyServer function (with args:) address, position, stype, sversion, condition, q-file

1. Verify that "address" is not already in the buffer
2. Add a copy of the row at "position" at the bottom of the buffer.
3. Update the specified fields in the copy, fields left blank will be unchanged.
4. Move the copy immediately above the original "position".
5. Add the "address" to the phase-in list.

### replaceServer function (with args:) address, position, stype, sversion, condition, q-file

Same as copyServer but add:
6. Add the "address" from the original "position" to the phase-out list.

### upgradeServers function (with args:) stype, sversion, host, qfile, new-qfile, new-sversion

Upgrade a collection of servers to a new qfile, matching those old servers by the 
"and" of supplied stype, sversion, host, qfile. 

1. Find position of all rows in the buffer having the specified stype, sversion, host, and qfile
   Ignoring any of the above which were entered as blank.
2. For each row found above, find an unused port on the same host
3. Combine into a list of tuples: (address=host:unused-port; position; new-qfile; new-sversion).
4. Perform replaceServer on each tuple, updating only qfile and sversion for 
   each address and position.
   Leave sversion unchanged when new-sversion is blank.

### duplicateServers stype sversion, host, qfile, new-qfile, new-sversion

Same as upgradeServers, but don't phase out the old servers.
Use "copyServer" in 4. above instead of "replaceServer".

### migrateServers function (with args:) stype, sversion, host, new-host, new-stype, new-sversion

Replacing any number of servers with the same number of servers on a different host by matching stype, sversion, host 

1. Find position of all rows in the buffer having specified stype, sversion, and host,
   Ignoring any  of the above which were entered as blank.
2. For each row found above, find an unused port on new-host.
3. Combine into a list of tuples: (address=new-host:unused-port; position, new-stype, new-sversion)
4. Because the stype may carry information about the q-file and/or condition as well as the host,
   we probably want "new-stype" to be an edit pattern which is applied to the old stype,
   so we can change only the part referring to the host.
5. For example "t2small-taiwan:myserver:A-M", "d4xlarge-singapore:=", "d4xlarge-singapore:myserver:A-M" 
6. Perform replaceServer on each tuple, updating only stype and sversion, 
   but only when new settings are not blank.

### Find an unused port on given host

1. The default port range is 5000-5999 but we should make this configurable.
2. The lowest port in the range is for mserve, the highest for the launcher
 , and second highest for "announcement" callbacks (currently to batchmark).
3. The remainder (5001-5997 by default) is the "available port range".
4. Extract the port number from all addresses in the table on the given host.
5. Choose the lowest number from the available port range, which is NOT in this list.

### applyChanges percent-increment per-interval

Note: a canary will be started when percent-increment is an integer between 0 and 100,
and per-interval is an integer suffixed by one of 'm', 'h', or 'd' (for minutes, hours, days).
Specifying the increment as 0% will set everything up to start phasing in the new configuration
but hold the percentage of requests going to new servers at 0, until the increment is changed
by another call to applyChanges.
Otherwise, there is no interval where 0% goes to the new server, it starts at the percent-increment,
and continues though 100%. Specifying 100% sends everything to the new server all at once,
but allows for rollback durring the specified interval.
Otherwize no canary, which means no phase in and no roll back.

1. The phase-in and phase-out lists were already populated by the commands above.
2. Launch and connect to each of the servers on the phase-in list.
3. When no canary, discard the phase-in and phase-out lists.
4. When canary, set percent-increment, per-interval, and start-time for canaryFilter. 
5. Replace the live routingTable with the contents of the edit buffer (and discard the buffer).

### previewChanges





## **OLD** The servant type and version

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

### commands for above use-cases

Canary: To phase out everything except new-version - use null (0N) as old version.
        To phase out nothing - use zero (or any version not in table)  as old version.

We need to require sversion to change whenever we might want a canary.
That means whenever starting a new servant on a new host, with a new q-file, or with a new condition.
But then the same thing running on each distinct host might would end up with a different sversion

Also we need a new stype  whenever starting a new servant on a new host with different characteristics,
which we really can't tell (as we only have a name or ip address) and has to be tracked manually.

The way we want sversion to work with conditions is more subtle.
In the initial configuration from the csv file all rows for a given stype should have the same sversion (likely 1).
Maybe when any condition is changed, all of them should go to the next sversion, because the routing scheme has changed.
Maybe we should just allow changing the condition without changing the sversion, but then we could not do a canary.


1. Upgrade all servants with a given type to a new version of their q-file, retaining same boolean condition.
  upgradeByType stype [sversion] new-q-file new-sversion
  1. Find all routing table rows with stype (and sversion when specified)
  1.1 Verify that at least one row is selected.
  1.2 Verify that none of the selected rows has sversion=new-sversion.  !??
  (would like to leave rows already at new-sversion alone, but canary will treat them as being phased in.)
  2. For each selected row
  2.1. Find an available port on the same host
  2.2. Copy the selected row to a position immediately above itself
  2.3. Replace the port, sversion, and q-file with the new values
  2.4. Launch the new-q-file at the new host:port.
  3. If canary requested, set:
  3.1. cn\_increment, cn\_interval as requested;
  3.2. cn\_server\_type= stype; cn\_old\_version=sversion; cn\_new\_version=new-sversion
  4. If no canary requested
  4.1. update condition in the originally selected rows to (0b) to take them out out of service 
     Affected servers are not disconnected until saveRoutingTable is called - and they are not busy.

2. Move all servants with a given type on a given host, to a new host with different capabilities or location.
  relocateByType host stype sversion new-host new-stype new-sversion
  1. Find all routing table rows with host, sversion, stype(when specified)
  1.1. Verify that at least one row is selected
  1.2. Verify that none of the selected rows has sversion= new version !?? (see above)
  1.3. Verify that none of the selected rows has host= new host
  (stype may have to change to reflect the capabilities and location of the new host.
   will need to rewrite canary to allow changing the stype...) 
  2. For each selected row
  2.1. Select a new host (round robbin: host1 host2...) 
  2.2. Find an available port on this host.
  2.3. Copy the selected row to a position immediately above itself.
  2.4. Replace the host, port, stype and sversion, but keep the condition and q-file 
  2.5. Launch the same q-file on the new host:port.
  3. If canary requested, set:
  3.1.  cn\_increment, cn\_interval as requested
  3.2.  cn\_server\_type=stype, cn\_old\_version=sversion, cn\_new\_stype=new-stype, cn\_new\_version=new-sversion
  4. If no canary requested
  4.1 update condition in the originally selected rows to (0b) to take them out of service.

3. Add a copy of a given rule (same type, version, condition, q-file), started on a given host/port.
4. Add a copy of a given rule with a new condition (same type, version, q-file) started on a given host/port
  newCopyByAddress from-address to-address [new-condition]  (when new-condition omitted will be unchanged)  
   1. find row with from-address
   1.1. Verify that row exists.
   2. Copy selected row to a position immediately above itself
   2.1. Replace address with to-address and condition with new-condition (if specified)
   2.2. Launch the same q-file at the new address
   3. If canary specified set
   3.1 increment and interval as requested
   3.2 cnServerType=current stype cnOldVersion=0 (no phase out) cnNewVersion=(increment until value unique for this stype)
   (canary not possible unless sversion is set to something unique for this svalue.)
   4. If no canary - nothing to do (not replacing)

5. Add a copy of a given rule with the same condition but a new q-file on given host/port 
  newUpgradeByAddress from-address to-address q-file new-sversion 
  1. Find routing table rows with from-address 
  1.1 Verify that the row exists
  1.2 Verify that no row with this stype has new-sversion.
  (would like to leave rows already at new-sversion alone, but canary will treat them as being phased in.)
  2. For selected row
  2.1. Find an available port on the same host
  2.2. Copy the selected row to a position immediately above itself
  2.3. Replace the port, sversion, and q-file with the new values
  2.4. Launch the new-q-file at the new host:port.
  3. If canary requested, set:
  3.1. cn-increment, cn-interval as requested;
  3.2. cn-server-type= stype; cn-old-version=0 (no phase out); cn-new-version=new-sversion
  4. If no canary requested - nothing to do (not replacing)

6. Add a brand new rule specifying everything for new servant. (admin must pick stype and sversion wrt what is already defined)
  addServer position address stype sversion condition q-file
  1. Verify that address is not in routing table
  2. Verify that all settings are provided.
  3. Add row with all settings at specified position
  4. Launch q-file at specified address
  5. If canary requested, set:
  5.1. cn-increment, cn-interval as requested;
  5.2. cn-server-type= stype; cn-old-version=0 (no phase out); cn-new-version=sversion
  6. If no canary requested - nothing to do (not replacing)

7. Modify just the condition in a given rule.
  updateCondition address condition  (no canary allowed)
  1. Verify that address is in the table
  2. Find row for that address
  3. update condition in that row.


8. Remove all rules with given stype and sversion, closing the servants handle to cause it to shut down (terminate on close). 
  removeByType stype sversion
  1. Find all rows corresponding to "stype" and optional "sversion"
  1.1. Verify that at least on row is selected.
  2. If canary specified, set:
  2.1. cn-increment, cn-interval as requested
  2.2. cn-server-type=stype, cn-old-version=sversion, cn-new-version=0 (no phase in)
  3. If no canary specified, update condition to (0b) in each selected row.

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

