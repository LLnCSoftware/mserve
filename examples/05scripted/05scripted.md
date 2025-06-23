# 05scripted

## About this Example

We create a dispatch algorithm which explictly routes each request to a servant based on a configuration file.  

This algorithm also provides the ablilty to modify the configuration without shutting down or suspending operations.
That includes the ability to phase-in a new servant, so that the percentage of queries going to the 
new servant increases over a time interval. If a configurable number of errors occur in the new servant
while the phase in is in effect, the new servant is removed and the original configuration restored.


## New/Modified Files

* scripted.q - An mserve plugin implementing this dispatch algorithm.
* edconfig.q - Allows hot-editing the configuration file.
* scripted.csv - Demo configuration file

## How it Works

Similar to the previous example 04dispatch, which implemented the "even" and  "match" dispatch algorithms as plugins,
This plugin overrides the "check" function which performs dispatch in mserve\_np.q.

However, when this plugin is used, the command line to start mserve\_np.q will NOT contain arguments
for the number of servants and a servant q-file to run in each of them.

Instead it will have single argument which specifies a configuration file, which will explicity 
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

The meaning of each column is as follows:

- **address:** Specifies the host and port of the servant process
- **stype:** Describes the role of this servant process in the system (used only by configuration editor).
- **sversion:** Version number for the stype (used only by configuration editor).
- **condition:** Boolean expression involving the variables output by getRoutingCriteria (is servant qualified for query?).
- **qfile:** q-file to run in this servant process.

The variables in the boolean expression are derived from the arguments to the query, and any "options" included with
the request, by the function "getRoutingCriteria" (similar to getRoutingString in the match algorithm).

In general, a query will be sent to the first servant in the table for which the condition evaluates as true,
and which is not currently busy. However, when a condition is specified as unconditionally true (1b), it is
treated as a "fallback". Fallback servers will be used only when no other server qualifies, not just because
all the other qualified servers are busy. 

**Our example** uses the default "getRoutingCriteria" function which assigns the variable name "symbol" 
to the first argument of the query. 

To use this plugin in another context where other variables are expected, you must write you can write your 
own getRoutingCriteria function as a second plugin, which must preceed scripted.q in the MSERVE\_PLUGINS setting.

In the listing of scripted.csv above you can see that the first 3 servants are designated for symbols within 
the alphabetic ranges, A-F, G-L, and M-T respectively. 

While I could have used (symbol within `U`Z) for the last servant, I want to illustrate the use of (1b) as a 
"fallback" for all queries for which none of the previous conditions evaluate as true.

(Eric: we probably want this example to have overlapping ranges so that more than one server qualifies for some 
requests. We want to demo that the the first qualified non-busy server is used, except fallback are not used
just because all other qualifying servers are busy).

## Scripted Dispatch: To Do and Observe


## Hot Editing the Routing Table 

The edconfig.q module provides for hot editing the routing table. It is loaded along with scripted.q.
so it does not need to be included in the MSERVE\_PLUGINS list.

This provides the following new functions:

- **browse:** - Displays section of routing table around one or two specified entries
- **search:** - Executes a "select" query on the routing table, using a specified list of "where" clauses.
- **editServer:** - Updates and/or moves a particular row in the routing table, except you cannot change "address" or "qfile".
- **addServer:** -  Starts a new server, and adds a row to the routing table for it specifying everything including position.
- **copyServer:** - Starts a new server, optionally replacing an old one, by copying and modifying the row for the old server.
- **upgradeServers:** - Upgrade (all or some) servers of a given "stype" to a new qfile and sversion.
- **migrateServers:** - Migrate (all or some) servers of a given "stype" to a new host.
- **clearChanges:** - Initialize the editor to the current state of the live routing table.
- **applyChanges:** - Apply the changes made in the editor to the live routing table, allowing a optional phase-in period.
- **cancelPhaseIn:** - Aborts a phase-in, restoring the routing table to a backup taken before changes were applied.
- **finishPhaseIn:** - Finalizes a phase in, removing the phased-out servers from the routing table.
- **alterPhaseIn:** - Allows pausing or restarting a phase-in with a new percentage an interval.
- **saveConfiguration:** - Writes the modified routing table out to csv.

To add a new server you use "addServer" or "copyServer" with replace flag 0b.
To replace an old server with a new one, you use "copyServer" with replace flag 1b.
To remove an old server you use "editServer" to set its condition to 0b.

A phase-in (aka canary deployment) will gradualy increase the percentage of queries that added servers 
are qualified for while decreasing the percentage of queries that removed servers are qualified for.
Phase-in may be requested in "applyChanges" via the percent-increment and per-interval arguments.

### editServer[address; position; settings] 

1. Find the row with "address" (host and port) in the edit buffer
2. Update the fields specified in the "settings" dictionary.
3. Move the row to the requested position.

- Note: you cannot change the address or q-file as this would require launching a new server.
- Note: servers can be removed from service by setting their "condition" to (0b).

### addServer[address, position, settings] 

1. Verify that "address" is not already in the buffer.
2. Verify that all the required fields are specified as non-blank in the "settings" dictionary.
3. Add a row with the specified fields at the bottom of the buffer.
4. Move the row to the specified position.
5. Add the new "address" to the phase-in list.

- Note: The new server will be launched in applyChanges. 

### copyServer[address, positon, settings, replaceflag]

1. Verify that "address" is not already in the buffer
2. Add a copy of the row at "position" at the bottom of the buffer.
3. Update the specified fields in the copy, fields left blank will be unchanged.
4. Move the copy immediately above the original "position".
5. Add the "address" to the phase-in list.
6. If "replaceflag" is true, add the "address" from the original "position" to the phase-out list.

### upgradeServers[stype, criteria, settings, replaceflag] 

NOTE: settings should include only the new "qfile", along with any stype and sversion needed to describe it.
NOTE: because stype can depend on a combination of the properties of the qfile, host, and the rule itself,
 any new stype must be manualy determined based on the new qfile, and the old stype (only change qfile info). 

1. Find position of all rows in the buffer having the specified stype, for which
   fields included in the "criteria" dictionary match the values specified there.
   Ignoreing any "criteria" which were specified as blank.
2. For each row found above, 
2.1. Create an address for the new server using an unused port on the same host
2.2. Invoke copyServer specifying the new address, found position,
   the qfile and any stype/sversion from specified settings, and the specified replaceflag

### migrateServers[stype, criteria, settings, replaceflag]

NOTE: Settings should include only the new "host" along with any stype and sversion needed to decribe it.
NOTE: There is no "host" column in the table. The "host" setting is valid only for migrateServers, no other editing functions.
NOTE: Because stype can depend on a combination of the properties of the qfile, host, and the rule itself
 any new stype must be manually determined based on the new host, and the old stype (only change host info).

1. Find position of all rows in the buffer having the specified stype, for which
   fields included in the "criteria" dictionary match the values specified there.
   Ignoreing any "criteria" which were specified as blank.
2. For each row found above, 
2.1. Create an address for the new server using an unused port on the specified host
2.2. Invoke copyServer specifying the new address, found position,
   any stype/sversion from specified settings, and the specified replaceflag

### How we find an unused port on given host

1. The default port range is 5000-5999 but we should make this configurable (need to specify high end).
2. The lowest port in the range is for mserve, the highest for the launcher
 , and second highest for "announcement" callbacks (currently to batchmark).
3. The remainder (5001-5997 by default) is the "available port range".
4. Extract the port number from all addresses in the table on the given host.
5. Choose the lowest number from the available port range, which is NOT in this list.

### Understanding stype and sversion

The "stype" describes the role of the servant in the system, which depends on 
a combination of the properties of the qfile, host, and the condition. 

A given role may evolve over time, with the same "stype" having multiple "sversion"s.

By a "combination of properties" we mean stype might have formats like:
> ec2.t2-2xl.ohio:rdb-vwap:A-M

Here the first segment ec2.t2-2xl.ohio describes relevant properties of the host.
that its an aws ec2 instance type t2-2xl, located in ohio. The second segment identifies
the qfile, its a vwap server acting on an rdb, and the last segment only refers to the
rule which says that this servers is only to be used for symbols in the range A-M.

When using upgradeServers or migrateServers we avoid having to update only parts of the stype,
by acting only on one stype at a time. It is up to the user to assign a new stype based on 
the unchanged portions of the old stype.
 
### Managing q-file versions.

At present the only way be can choose between two q-files is by a file system path.
That means if we want to distinguish between two version of (for example) servant.q
we need to give one a different name (e.g. servantbad.q) or put it in a different directory.

Also there is no guarantee that q-files with the same path on different hosts will be identical.
That must be ensured by the process (maybe manual) which sets up the hosts.

We have not tested accessing q-files and plugins that are not within the mserve directory,
or having a path in the qfile setting or plugin name, there may well be bugs to fix in this area.

The workaround is having a subdirectory of mserve containing symlinks to the available servant q-files. 


### Managing Canary Deployments

A "phase-in" or "canary deployment" gradually increases the percentage of queries which will see
new servers as qualified, while decreasing the percentage of queries will will see removed or replaced
server as qualified. This may be requested when the edited routing table is taken live by "applyChanges".

In "applyChanges" a phase-in will be started when percent-increment is an integer between 0 and 100,
and per-interval is an integer suffixed by one of 'm', 'h', or 'd' (for minutes, hours, days).

To apply the changes without a phase-in (immediately) specify either of these arguments as blank ("" or 0N).

Specifying the increment as 0% will set everything up to start phasing in the new configuration
but hold the percentage of requests going to new servers at 0, until the increment is changed
by a call to "alterPhaseIn".

Except when specifying the interval as 0, there will be no interval where 0% goes to the new server, 
it starts at the percent-increment, and continues though two intervals at 100%. 

During this time, if more errors occur in the phase-in servers than is configured in the environment variable CN\_MAXERR, 
the percentage will be set to "hold at 0%", effectively disabling the new servers, and re-enabling the old ones

When the critial number of errors does not accumulate by the end of the 2nd 100% interval, the percentage
will be set to "hold at 100%", effectively disabling the old servers and enabling the new ones.

Specifying the increment as -1 will set everything up as a phase-in but hold the percentage at 100%.
This allows for an immediate deployment with the option of easily reverting to 0% should you so desire.
This differs from specifying 100% in that there will be no trial period with automatic failback.

To cancel an aborted phase-in by restoring the original routing table from a backup, use cancelPhaseIn[].
To finish a successfull phase-in by removing the phased out servers from the new routing table, use finishPhaseIn[]

### applyChanges[ percent-increment; per-interval]

When either percent-increment or per-interval is specified as blank (a null or a zero length string)
There will be no phase in. The phase out servers will be removed from the edit buffer and the result
set as the live routing table (after precomputing the routing bit vectors if necessary).

How these arguments work for a phase-in is descrived above under "Managing Canary Deployments".

1. The phase-in and phase-out lists were already populated by editing commands.
2. Launch and connect to each of the servers on the phase-in list.
3. When no canary: remove servers on the phase-out list, discard the phase-in and phase-out lists.
4. When canary: set percent-increment, per-interval, and the phase in/out bitvectors for canaryFilter
4. When using precomp; Precompute a new contextSource based on the edit buffer. 
5. Replace the live routingTable and contextSource with the contents of the edit buffer, and new contextSource.

### browse (address; position; size)

The browse command accepts a single argument which may be a one, two, or three item list.
- When there is one argument, 
  - it is the address or position of a row to be centered (if possible) in a 10 row window.
- When there are two arguments, 
  - the first is the address or position of a row and the second is the size of the window.
- When there are three arguments, 
  - the first two are the address or position of rows in the table and the second is the size of the window.
  - the same size window is provided for each row, when the windows overlap their union is used.
  
To plan an edit you often need to see a portion of the table around the rule 
you are editing and a portion around the position you want want to move it to.

Position is important because servants in earlier positions have
priority when more than one servant qualifies for the query.

### search (list of where clauses as strings)

The search command accepts a single argument which is a list of strings.
Each string is interprested as a "where" clause filtering the routing table.

## Hot edit with phase-in: To Do and Observe



