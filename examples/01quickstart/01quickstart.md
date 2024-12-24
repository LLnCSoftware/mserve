# 01quickstart

## About This Example

This is a simple example of a client interacting with a servant through mserve\_np.q, all 
on one host. 

## About the Files

**qs.q**: Simple client used for examples 1-3 ("quickstart client").
**qsvr.q**: Simple servant used for this demo ("quick server").
mserve\_np.q  - Symlink to the mserve load balancer at the root of the repo.

## To Do and Observe

**Step 1 - start mserve with one copy of the servant:**  

Open two terminals, one each for the servant and client, and ``cd`` into the examples/01quickstart directory.

Launch mserve as follows:

```
$ q mserve_np.q 1 qsvr.q -p 5000
```

The above starts q on port 5000, loads mserve and instructs it to start one instance of qsrv.q on localhost.

DELETE: -The first argument to mserve\_np.q, shown here as "1", is the number of copies of the servant code to start. In this case just one copy of "qsvr.q" on localhost.-


**Step 2 - start the client:**  

From the examples/01quickstart directory, type:

```
$ q qs.q localhost 5000
```

This launches a client, qs.q, and tells it to send its requests to the loadbalancer on localhost port 5000.

## How it Works

### The client qs.q

* Client gets the hostname and port number for mserve from command line arguments.
* Client (qs.q) provides a "send" method, which generates a query id, and sends the id and query as expected. ????????????? WHAT DOES THAT MEAN ?????????????????
* qs.q provides a [.z.ps](https://code.kx.com/q/ref/dotz/#zps-set) handler which just displays the received response.
* It also provides a [.z.ts](https://code.kx.com/q/ref/dotz/#zts-timer) handler to run a series of queries with random inputs on the timer.

## The servant qsvr.q

The servant provides a sample api that has two functions "proc1" and "proc2".
They each run the same query multiple times in order increase elapsed time.
The "proc2" function has more repetitions and so is more expensive.

The servant code is complicated by two features.

1. Secure invocation - Invoke only functions in the ".api" namespace, with no recursive evaluation in their arguments.
2. Exit on Close - Expect only one connection (to mserve). Exit when it closes.

In the next example "exit on close" will be made optional, so that the servant can run independent of mserve.
We will also extend "secure invocation" to optionally provide authorization based on a user role.

### details

TODO: Secure invocation MUST REFERENCE A GLOSSARY ENTRY AS MENTIONED IN THE TICKET. 

* The file begins by creating a "trade" table to be used as test data, on load. 
* We disallow synchronous requests. TODO: HOW??? 

* Exit on close is implemented by: .z.po:{ .z.pc:{exit 0} }.
    * After first connection made, set to terminate when any connection closes
    * Note: if setting ".z.pc" was not delayed until after the file has loaded, the new "q" session would terminate immediately.

* Secure invocation is implemented in the .z.ps handler (for async requests)
    * Expect a request to be a general list of the form (id; query).
    * If the query is a string parse it.
    * Obtain the function name as a symbol from first item in the parsed query.
    * Obtain the function by this name from the .api namespace.
    * Reject anything else, returning an "unknown command" error to the client.
    * Invoke the function on the 2nd item in the parsed query, its argument, without using "eval".
    * Return the result or error message to the client.

## Annoying Details Glossed Over

### The parse command is really designed for use with eval

The problem is that "parse" mangles arguments which are symbols, lists of symbols, or general lists.
It "enlists" symbols and lists of symbols, and encodes a general list as an "enlist" command.

Most likely it does this so that "eval" can distinguish symbols used as variable names from those used as literals,
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
The content of the "exitOnClose.q" plugin is just the line *.z.po:{ .z.pc:{exit 0} }* we use in qsvr.q
to implement this functionality.

So in this case the environment variable is being ignored, just to avoid the complexity of loading the plugins.
We have additional plugins to implement authentication and authorization, as you will see in the next example.

