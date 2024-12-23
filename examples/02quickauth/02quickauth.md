# 02quickauth

## About this Example

This example uses the same client as in 01quickstart (qs.q) but a different servant (servant.q)

The servant here has modifications which allow it to load and utilize plugins
to optionally implement authentication, authorization, and exit on close.

## New/Modified Files

servant.q - contains new functions (getrole, allowedfn) designed to be overriden to provide authentication and authorization.
authent.q - provides authentication based on the username, password, and role in the file users.csv
authriz.q - provides the allowed function names for each user role as specified in the file roles.csv
exitOnClose.q - provides the line: .z.po:{ .z.pc:{exit 0}} to cause "terminate on lost connection".

## To Do and Observe

### Demo1- Adding authentication and authorization

**start the server:** 

```
KDBQ\_PLUGINS="authent.q"  q mserve\_np.q 1 servant.q -p 5000
```

Note that mserve\_np.q always provides the KDBQ\_PLUGINS env variable when launching a servant,
because it needs to provide "exitOnClose", and also because it needs to clear out any plugins
intended only for mserve\_np.q itself.

However this makes it difficult to specify additional plugins (such as authrize.q) for the servant. 
The solution chosen was for mserve\_np.q to automatically provide the authrize.q plugin
(for authorization) to the servant, whenever it loads the "authent.q" plugin for authentication.

A more flexible solution would use separate environment variables for mserve\_np.q and its servants.
The advantage of the chosen solution is that it is simpler for the user, results in a shorter command
line, and at this point we do not anticipate wanting any additional plugins on the servant.


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
That's because the "exitOnClose" plugin is omitted ! 

**Start the servant with auth/auth:** 

```
 KDBQ\_PLUGINS="authent.q,authriz.q"  q servant.q -p 5001
```

* q qs.q localhost 5001  -> no credentials 'access error
* q qs.q localhost 5001 ken ken -> ordinary user, proc1 only.
* q qs.q localhost 5001 arthur arthur -> power user, both proc1 and proc2.

**Start the sevant with authentication only:** 

```
KDBQ\_PLUGINS="authent.q"  q servant.q -p 5001
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
to optionally implement authentication, authorization, and exit on close.

Plugins are q-files intended to be listed in the KDBQ\_PLUGINS environment variable.
In this example we have 3 of them: authent.q, authrize.q, exitOnClose.q

They are typically loaded in at the bottom of the "q" file which wants to "import" them.
The following line of code is used to load the plugins in servant.q.

```
{system "l ",x} each {$[0=count x; (); "," vs x]} getenv `KDBQ_PLUGINS
```

The strange piece in the middle returns a empty list when getenv returns a null string.
Otherwise you would get a singleton containing an empty list from ("," vs x).

This same line is included in mserve\_np.q itself, to allow it to use plugins.


### Adaptations in servant.q

The changes in servant.q to support these plugins are related to the 3 new functions
found below the .z.ps handler: "send", "getrole", and "allowedfn".

The "send" function is actually not related to the plugins at all.
It just allows testing from the servant console using handle zero, 
in which case it displays the result, rather than trying to send it.

The "getrole" function coded here is a default that is used when authentication is not provided in servant.q
Note that when running with mserve\_np.q, authentication is done there and only authorization is done in servant.q.
In that case we get the role from the options dictionary of the request, returning a null symbol when it is not provided.

The "allowedfn" function coded here is a default that is used when authorization is not provided in servant.q.
While it accepts a "role" argument, it always returns all the functions in the .api namespace.

### Authentication

To Implement authentication with this model, you need to:

1. Provide a .z.pw handler to validate the username and password.
2. Provide a "getrole" function to obtain the role for each request given the authenticated username in .z.u.

Of course you will need some data source which provides the role and a hash of the password for each username.

In our example, "authent.q" the data is provided by the file users.csv, and "sha1" (-33!) is used for the hash.
The example does not include the capability to add, edit, or remove users.

#### Note: When authentication is specified for mserve\_np, it will automatically specify authorization for its servants.

To allow authentication in mserve\_np.q, it needs to obtain the role for each request and send it along to
the servant in the options dictionary of the request. A default "getrole" is provided for this which always
returns the null symbol. The authent.q plugin will override this function. 
 
When a plugin with the name "authent.q" is loaded by mserve\_np.q it will automatically add a plugin with the
name "authrize.q" to the servants it launches. (this is because there is currently no convenient way to specify
plugins for servants launched by mserve\_np.q, but maybe we could use a second environmnt variable).

However, this is not really much of a limitation, because you will generally want both "auth"s when you want either.
If you should want authentication without authorization that can be accomplished by providing an "authriz.q" file
which just contains the default function: 'allowedfn:{[role] value `.api}', including all functions in the .api namespace.

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

We want servant.q to exit on a lost connection when running under mserve, but not when running independently.
To that end mserve\_np.q always provides "exitOnClose.q" in the environment variable KDBQ_PLUGINS when launching
the servants.

This file just contains one line: '.z.po:{ .z.pc:{exit 0} }'

To enhance security you could:
1. add .z.pw:{[h;pw] 0b} within the .z.po handler, to allow only the first connection.
2. add .z.pw alongside the .z.po handler to validate ip address in .z.a against the known ip address of mserve.

The setting of .z.pc must be done after the file has loaded successfully, otherwise it will terminate immediately,
so it is convienient to do it when the first connection is made.


