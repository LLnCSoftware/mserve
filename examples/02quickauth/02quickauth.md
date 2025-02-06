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

_secure_invocation.q:_

See "secure invocation" in the Glossary section of readme.md.

* .si.validate - Allow execution only of designated api functions, without function evaluation in their arguments                        
* .si.parse    - Parse a string returning a general list representing a command in which all arguments are taken as literals.                   
* .si.fixarg   - Enables .si.parse by unmangling the arguments returned by the standard "q" parse command.
* getrole      - Stub to be overridden by authentication plugin. Gets user role given authenticated user name. 
* allowedfn    - Stub to be overridden by authorization plugin. Get list of allowed function names from user role.
* Q\_PLUGINS   - Environment variable providing list of plugin "q" files to be loaded.
* Q\_SERVANTOF - Enviornment variable providing the only IP address from which servant may accept a connection. 
                 When present, only one such connection is allowed, and servant terminates upon disconnect.
                 When not present, all connections are allowed and servant stays up when they close.

servant.q - Same API as in qsvr.q, but with client interface implemented using secure\_invocation.q
authent.q - Plugin providing authentication based on the username, password, and role in the file users.csv
authriz.q - Plugin providing the allowed function names for each user role as specified in the file roles.csv

## To Do and Observe

### Demo1- Adding authentication and authorization

**start the server:** 

```
MSERVE\_PLUGINS='authent.q' Q_PLUGINS='authriz.q' q mserve\_np.q 1 servant.q -p 5000
```

Note that mserve\_np.q always provides the Q\_PLUGINS env variable when launching a servant,
If that variable is not set when launching mserve\_np.q, Q\_PLUGINS will be passed as an empty string.

However we want authentication to happen when the client connects to mserve, not when mserve connects
to the servants. To facilitate that, mserve looks for its own plugins in a different env variable,
MSERVE\_PLUGINS.


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
* q.qs.q localhost 5001 dan dan -> ordinary user can run both proc1 and proc2 (no authorization)

**Start the servant with no plugins:** q servant.q -p 5001

* q qs.q localhost 5001 -> can run both proc1 and proc2


## How it Works

### The client qs.q

This is the same client as in 01quickstart.

## The servant servant.q

### Plugins

The servant has modifications which allow it to load and utilize plugins
to optionally implement authentication and authorization.

Plugins are q-files intended to be listed in an environment variable, when launching a 
q-file that is configured look at that variable of a list of additional files to load.

In general we use the variable Q\_PLUGINS, but since we must distinguish plugins intended
for mserve from those intended for the servant, we use the variable MSERVE\_PLUGINS for mserve.

They are typically loaded in at the bottom of the "q" file which wants to "import" them.
The following line of code is used to load the plugins in secure\_invocation.q.

```
if[0<count getenv `Q_PLUGINS; {system "l ",x} "," vs getenv `Q_PLUGINS] ;
```

A similar line is included in mserve\_np.q itself, but using the varible MSERVE\_PLUGINS.

### Adaptations in servant.q

The changes in servant.q to support these plugins are related to the stubs "getrole" and "allowedfn"
provided in secure\_invocation.q

The "getrole" function coded there is a default that is used when authentication is not provided in servant.q
Note that when running with mserve\_np.q, authentication is done there and only authorization is done in servant.q.
In that case we get the role from the options dictionary of the request, returning a null symbol when it is not provided.

The "allowedfn" function coded there is a default that is used when authorization is not provided in servant.q.
While it accepts a "role" argument, it always returns all the functions in the .api namespace.

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

In the 'allowedfn' function, we filter the dictionary representing the .api namespace to the list of functions 
allowed by the role. 

### Exit on close

The Q\_SERVANTOF env variable instructs the "q" program to behave as a servant of the specified IP address.
When launching servants, mserve\_np.q always sets this variable to its own IP address which is the value of ".z.a".
The code implementing this in secure_invocation.q is shown below:

```
if[0<count getenv `Q_SERVANTOF;                                                /when Q_SERVANTOF specified:
  .z.pw:{[u;p] (getenv `Q_SERVANTOF)~ "." sv string `int$ 0x0 vs .z.a};          / accept connectinon only from specified ip.
  .z.po:{.z.pw:{[u;p] 0b}; .z.pc:{exit 0}} ;                                     / accept only single connection, terminate on close
 ];

```

## Understanding secure_invocation.q

## The q parse command is really designed for use with eval

The problem is that "parse" mangles arguments which are symbols, lists of symbols, or general lists.
It "enlists" symbols and lists of symbols, and encodes a general list as an "enlist" command.
It uses symbol atoms to represent undecorated words like "abc", i.e. global variable names.

Most likely it does this so that "eval" can distinguish symbols used as variable names from those used as literals,
and so that general lists used as literals are not mistaken for commands.

In the servant **"qsvr.q" from 01quickstart**, Instead of explictily unmangling the argument (which is a symbol)
I just changed the where clause of each query to use "in" instead of "=" to match what is received from parse.

This also generalized the function to handle queries for more than one symbol.
Note that it does not mess up the case where the command is a general list and all symbols are literals,
because "in" treates a right argument which is an atom as a singleton.  

The rest of the examples use the server **"servant.q" from 02quickauth**. 
This server implements its calling convention using the "validateAndRunAsync" function from **secure_invocation.q**,
which explicitly unmangles the arguments. That is done in the covering function .si.parse, which applies
the following ".si.fixarg" function to each of the arguments obtained from "parse".

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
* A symbol atom
* A general list starting with a symbol atom
* A general list starting with a function other than "enlist"

Regardless of whether the command is parsed from a string or provided as a general list,
we disallow function types anywhere in any argument. That is enforced by the following
line in .si.validate:

```
if[100<=any type each (raze/) arg; "nested evaluation"]; 
```

### PLUGINS and SERVANTOF

When you run the examples you will see that two environment variables are set when launching the servant.
Specifically: *Q_SERVANTOF='an ip address'; Q_PLUGINS='list of q-files*

For simplicity these environment variables are ignored in the simple servant "qsvr.q".

The environment variable Q\_PLUGINS is supplies a list of "q-files" to be loaded after the main servant module.
We have plugins to implement authentication and authorization, as you will see in the next example.

The environment variable Q\_SERVANTOF provides the known IP address of the mserve machine.
This is used to provide a stronger variant of "exit on close" which only allows a single
connection from this IP address to each servant.



