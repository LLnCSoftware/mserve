## For Eric

Nearly all the text of this has been copied into the bottom of examples/04dispatch/04dispatch.md

-------------

TODO: WHEN DO PEOPLE NEED TO UNDERSTAND THIS? WHEN WRITING A SERVANT? IF SO, HAVE A SECTION
CALLED COMPLEXITIES OF WRITING A SERVANT. OR GIVE THEM A COVERING FUNCTION SO THEY DONT NEED T
UNDERSTAND THIS. 

They might not need to understand it because I give them a covering function ".si.parse" in secure\_invocation.q

One way to think about is that we are introducing a new protocol for sending a command as a general list
in which symbols are always interpreted as literals, never as variable names; and creating a wrapper
for the parse command to provide equivilant semantics for strings.

You might want to change the following heading:

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

