# 02quickauth

## About this Example

This example uses the same client as in 01quickstart (qs.q) but a different servant (servant.q),
which loads the module "secure\_invocation.q" to prevent requests from running arbitrary code
on the servant, and loads plugins to optionally implement authentication and authorization.

The servant will obtain its plugins from the env variable Q\_PLUGINS (for authorization).
The load balancer mserve will obtain its plugins from the env variable MSERVE\_PLUGINS (for authentication).

The Q\_SERVANTOF env variable is automatically set by mserve to its own ip address (from .z.a) when launching a servant.
When this env variable is set, servant.q implements a stronger version of "exit on close" which only accepts connections
from the specified IP address, and ensures that only one such connection is made, in addition to exiting upon disconnect.

When Q\_SERVANTOF is not set, "exit on close" is NOT implemented in servant.q, allowing it to run independently.

## New/Modified Files

secure\_invocation.q - Implements "secure invocation" (preventing execution of arbitrary code) as described in
            the glossary section of README.md. This module is discussed in detail at the bottom of this file.

servant.q - Same API as in qsvr.q, but with client interface implemented using secure\_invocation.q
authent.q - Plugin providing authentication based on the username, password, and role in the file users.csv
authriz.q - Plugin providing the allowed function names for each user role as specified in the file roles.csv

## To Do and Observe

### Demo1- Adding authentication and authorization

**start the server:** 

```
MSERVE\_PLUGINS='authent.q' Q_PLUGINS='authriz.q' q mserve\_np.q 1 servant.q -p 5000
```

Authentication happens when the client connects to mserve, verifying the user's identity and establishing their "role".
Subsequently, mserve will pass role to the servant in the "options dictionary" associated with each request. 
Authorization happens when the servant uses the "role" to determine which api endpoints are allowed for the request. 

Because Authentication happens in mserve, it is requested using the MSERVE\_PLUGINS env variable.
Because Authorization happens in the servant, it is requested using the Q\_PLUGINS env variable.


**Start the client without valid credentials** 

Try each of the following commands:

```
q qs.q localhost 5000                      /no credentials
q qs.q localhost 5000 ken wrongpassword    /invalid credentials
```

In each case you will get an 'access error.  

**Start the client as an ordinary user:**  

In the file users.csv "ken" has password (sha1 of) "ken", and role "user".
In the file roles.csv "user" has "fn" equal to "proc1", which means this role can only run the "proc1" function.

```
q qs.q localhost 5000 ken ken
``` 

You will be able to run "proc1", but "proc2" will give you an "unknown command" error.

**Start the client as a power user:**  

In the file users.csv "arthur" has password (sha1 of) "arthur" and role "poweruser".
In the file roles.csv "poweruser" has "fn" equal to "proc1,proc2", which means this role can run both functions.

```
q qs.q localhost 5000 arthur arthur
```

You will be able to run both "proc1" and "proc2"

## Demo2 - Running without the load balancer

The point here is that the authentication and authorization plugins will work directly on a servant not running under mserve. 
Note that in each case below the servant will stay up when the client disconnects.
That's because the "Q\_SERVANTOF" environment variable is NOT set ! 

**Start the servant with auth/auth:** 

```
Q\_PLUGINS="authent.q,authriz.q"  q servant.q -p 5001
```

* q qs.q localhost 5001  -> no credentials 'access error
* q qs.q localhost 5001 ken ken -> ordinary user, proc1 only.
* q qs.q localhost 5001 arthur arthur -> power user, both proc1 and proc2.

**Start the sevant with authentication only:** 

```
Q\_PLUGINS="authent.q"  q servant.q -p 5001
```

* q qs.q localhost 5001 -> no credentials 'access error
* q.qs.q localhost 5001 ken ken -> ordinary user can run both proc1 and proc2 (no authorization)

**Start the servant with no plugins:** q servant.q -p 5001

* q qs.q localhost 5001 -> can run both proc1 and proc2


## How it Works

### The client qs.q

This is the same client as in 01quickstart.

### The servant servant.q

This servant supports the same api as in 01quickstart, but is built around 
the services provided by secure\_invocation.q, described in detail below.


## Understanding secure\_invocation.q

The following services are provided in secure\_invocation.q:

1. A means of restringing remote execution to only user-defined functions in a ".api" namespace.
2. A means of invoking api commands without using "eval" so as to prevent execution of arbitary code in arguments.
3. A means of restricting access to the api to a single connection, in this case from mserve,
   and terminating the servant when that connection closes.
4. A means of loading "plugins" to provide optional or enhanced functionality. 
5. Stub functions designed to be overridden by plugins providing authentication and authorization.

The module secure\_invocation.q is intended to be used as follows:

1. Start with an ordinary unsecured api which executes whatever comes in using "value" (the default).
2. Provide a ".api" namespace containing exactly those functions you want to expose.
3. Load secure\_invocation.q at the bottom of your api q-file.
4. Provide an invocation protocol
   - Set .z.ps=validateAndRunAsync to use the included asynchronous protocol.
   - Set .z.pg=validateAndRunSync to use the included synchronous protocol.
   - Or use the utilities in the ".si" namespace to create your own protocol.
5. Provide authentication and authorization 
   - Adapt the 'authriz.q' plugin to implement your authentication scheme.
   - Adapt the 'authriz.q' plugin to implement your authorization scheme.

### Invocation Protocol

In the asynchronous protocol, the client supplies an id in the request,
which will be sent back in the response, to identify which request it came from:

  - Requests are sent as a 2 or 3 part general list: (id; query [; options])
  - Responses are sent back as a 2 or 3 part general list: (id; result [; info])

The options and info, when they are included, should be dictionaries.

When authentication has provided a user role, the user name and role will be
added to the options dictionary before forwarding it on to the servant.

When a role has been provided, but the request has no third item, or that third item 
is not a dictionary, a new dictionary will be passed, containing just the user's role.
In this case any original third item is silently lost.

The info dictionary can include anything the servant wishes to send back
in addition to the actual result, such as benchmarking or accounting information.

When the servant does not include a third item in its response, or that third item
is not a dictionary, mserve\_np.q will return its own "info" dictionary, containing
benchmarking information. In this case any original third item is silently lost.

When the servant does include an "info" dictionary in its response, mserve\_np.q
will add the following items to it:
  * route - the routing symbol for the request (null symbol when routing not in effect).
  * backlog - the number queries enqueued ahead of this one.
  * remaining - the number of queries enqueued behind this one.

### Plugins

Plugins are q-files intended to be listed in an environment variable, when launching a 
q-file that is configured look at that variable for a list of additional files to load.

In general we use the variable Q\_PLUGINS, but since we must distinguish plugins intended
for mserve from those intended for the servant, we use the variable MSERVE\_PLUGINS for mserve.

They are typically loaded in at the bottom of the "q" file which wants to "import" them.
The following line of code is used to load the plugins in secure\_invocation.q.

```
if[0<count getenv `Q_PLUGINS; {system "l ",x} "," vs getenv `Q_PLUGINS] ;
```

A similar line is included in mserve\_np.q itself, but using the variable MSERVE\_PLUGINS.

### Stub functions for authentication and authorization

The secure\_invocation.q module provides two functions designed to be overridden by plugins providing
authentication and authorization.

**getrole** - returns "role" from the options dictionary of the request (null when no dictionary).

This default supports the case where authentication is NOT provided in the servant, but might be
provided in mserve\_np.q, with the role passed to the servent in the options dictionary of each request.
When there is no authentication at all the client may assume any role by passing it in the options dictionary. 


- **allowedfn** - returns all functions in the .api namespace.                

This default supports the case where authorization is NOT provided in the servant.
In that case any user who authenticates successfully may run any of the functions in the .api namespace.


### Authentication

To Implement authentication with this model, you need to:

1. Provide a .z.pw handler to validate the username and password.
2. Provide a "getrole" function to obtain the role for each request given the authenticated username in .z.u.

Of course you will need some data source which provides the role and a hash of the password for each username.

In our example, "authent.q" the data is provided by the file users.csv, and "sha1" (-33!) is used for the hash.
The example does not include the capability to add, edit, or remove users.

### Authorization

To implement authorization with this model you need to:

1. Provide an "allowedfn" function to obtain the list of allowed functions for each role.

Of course you will need some data source that provides such data.

In our example "authriz.q" the data is provided by the file roles.csv. (delimited by |)
This is read in as a table with 2 columns, the role, and the list of function names (delimited by ,).
That is converted to a dictionary that maps the role name as a symbol to the function names as a list of symbols.

In the 'allowedfn' function, we filter the dictionary representing the .api namespace to those function names 
allowed by the role. 

### Restricting to a single connection

The Q\_SERVANTOF env variable instructs the "q" program to behave as a servant of the specified IP address.
When launching servants, mserve\_np.q always sets this variable to its own IP address which is the value of ".z.a".
The code implementing this in secure\_invocation.q is shown below:

```
if[0<count getenv `Q_SERVANTOF;                                            /when Q_SERVANTOF specified:
  .z.pw:{[u;p] (getenv `Q_SERVANTOF)~ "." sv string `int$ 0x0 vs .z.a};    / accept connectinon only from specified ip.
  .z.po:{.z.pw:{[u;p] 0b}; .z.pc:{exit 0}} ;                               / accept only single connection, terminate on close
 ];

```

## Appendex: Validation of requests in secure\_invocation.q

The .si.validate function is called with the query and options dictionary as arguments, and will either: 

- throw an error 'unknown function' if the request is not for a permitted function in the .api namespace.
- throw an error 'nested evaluation' if the request contains any function or variable evaluation in its arguments.
- return a triple (fn; arg; nam) including the function to invoke, its arguments, and name. 

The query may have been specified either as a string or as a general list.
If the query is a general list:

- The first element is expected to be the function name as a symbol.
- Additional elements are expected to be argument values containing no variable or function evaluation.
- In particular argument values which are symbols or lists of symbols are always taken as literals not variables.

If the query is a string, we need to parse it to obtain the function name and argument values.

The problem is that the "parse" command mangles arguments which are symbols, lists of symbols, or general lists.
It "enlists" symbols and lists of symbols, and encodes a general list as an "enlist" command.
It uses symbol atoms to represent undecorated words like "abc", i.e. global variable names.

Most likely it does this so that "eval" can distinguish symbols used as variable names from those used as literals,
and so that general lists used as literals are not mistaken for commands.

For this reason .si.validate uses the covering function .si.parse to parse queries received as strings.
What .si.parse does is invoke the standard "parse" command, and then apply the function .si.fixarg 
to unmangle each of the resulting arguments.

```
.si.fixarg:{[x]
  if[-11=type x; '"nested evaluation"];     /symbol atom is global variable
  if[(11=type x) and 1=count x; :x 0];      /enlisted symbol is its content
  if[0<>type x; :x];                        /not general list - ok
  if[(1=count x) and 11=type x 0; :x 0];    /enlisted list of symbols is its content
  if[-11=type x 0; '"nested evaluation"];   /symbol atom at index 0 is global variable (user-defined function)
  if[100> type x 0; :x] ;                   /not a built-in function at index 0 - ok
  if[enlist~ x 0; :1_ x] ;                  /"enlist" function at index 0 ? just drop it.
  '"nested evaluation"                      /you might want to evaluate + - * % etc. but you would need to validate their arguments.     
 };
```

Here we throw a "nested evaluation" error whenever a argument is:
- A symbol atom
- A general list starting with a symbol atom
- A general list starting with a function other than "enlist"

Regardless of whether the command is parsed from a string or provided as a general list,
we disallow function types anywhere in any argument. That is enforced by the following
line in .si.validate:

```
if[100<=any type each (raze/) arg; "nested evaluation"]; 
```

