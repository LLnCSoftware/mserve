# 01quickstart

This example contains a simple client and servant to be run with mserve\_np.q

## Demo Instructions

You will need 2 terminals, for the server and client, both cd into the 01quickstart directory.

**Step 1 - start the load balancing server:**  

```
$ q mserve_np.q 1 servant.q -p 5000
```

The first argument to mserve\_np.q, shown here as "1", is the number of copies of the servant.q code to start.
In this case just one copy on localhost.


**Step 2 - start the client:**  

```
$ q qs.q 5000
```

## The client qs.q

The client is assumed to be running on the same host as mserve\_np.q
It gets the port number from a command line argument which defaults to 5000.
It provides a "send" method, which generates a query id, and sends the id and query as expected.
It provides a .z.ps handler which just displays the received response.
It also provides a .z.ts handler to run a series of queries with random inputs on the timer.

## The servant servant.q

### Secure Invocation

The servant is configured to use "secure invocation" which means that it does
not allow execution of arbitrary code. Rather it only allows execution of 
functions in the main namespace, with no recursive evaluation in the arguments.

This means that if the query is a string we parse it.
If its not a string we assume it is already parsed.
From the parsed query we obtain the function name and first argument.

We invoke the function on its argument explictly, without using eval.
So if the argument is a parse tree, it will not be evaluated, but will likely cause a type error.

### Terminate on Close

The servant is also configured to terminate when it loses its connection to mserve.
This has to be coded in the servant itself because "secure invocation" will not allow
mserve to run an expression to set the .z.pc handler.

In development you would probably want to allow additional connections dirctly to the servant
(not thru mserve) for debugging, but in production you will probably want to allow only a single connection, 
which can be accomplished by setting .z.pw to always return 0b. 

This happens in the .z.po handler, because if .z.pc is set to exit before a connection is made,
The q instance will terminate immediately after loading.

## Annoying Details Glossed Over

### The parse command is really degined for use with eval

The problem is that "parse" mangles arguments which are symbols, lists of symbols, or general lists.
It "enlists" symbols and lists of symbols, and encodes a general list as an "enlist" command.

Most likely it does this so that "eval" can distiguish symbols used as variable names from those used as literals,
and so that general lists used as literals are not mistaken for commands.

Instead of explicitly unmangling the argument (which is a symbol) I just changed the where clause
in the queries to use "in" instead of "=" to match the argument.

A more sophisticated server could unmangle the arguments using the following function:

```
fixarg:{$[11=type x; $[1=count x; x 0; x]; 0=type x; $[(1=count x)&11=type x 0; x 0; (100>type x 0); x; enlist~x 0; 1_ x; `invalid]; x]};
```

Here "invalid" is returned when we encounter a function other than "enlist" as the first item of a general list.
This can be used to reject commands that include built-in but not user-defined functions.
Nested user-defined functions will not be executed but will appear in the argument as a parse tree.
Type checking in the individual functions may be needed to invalidate them.

### Exit on close is really done by a plugin.

When you run this example you will see that an environment variable is set when launching the servant.
Specifically: *KDBQ\_PLUGINS="exitOnClose.q"*

This environment variable is intended to supply a list of "q-files" to be loaded after the main servant module.
The content of the "exitOnClose.q" plugin is just the line *.z.po:{ .z.pc:{exit 0} }* we use in servant.q
to implement this functionlity.

So in this case the environment variable is being ignored, just to avoid the complexity of loading the plugins.
We have additonal plugins to implement authentication and authorization, as you will see in the next example.

