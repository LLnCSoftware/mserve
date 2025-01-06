### What is this thing? how does it relate to the versions it derives from.

What is mserve ?
> This repo is a fork of the "mserve" load balancer published by Nathan Perrem of First Derivatives in 2013.
> That original contained one main file 'mserve\_np.q' which is the loadbalancer, along with an example client 
  'client.q' and server 'sevant.q'.
> The improvements we have introduced are:
> 1. Servants running on multiple hosts
> 2. Support for more than one way of assigning queries to hosts.
> 3. A plugin archeteture to support optional features.
> 4. A "secure invoction" toolkit for creating query protocols which disallow
     execution of arbitray code on the servants, with optional support for
     authenication and authorization.
> 5. An example protocol which includes sending and id number and options dictionary
     from client to servant along with each query, and getting the same id number
     and a different "info" dictionary back with the result.

 
### When should people consider using it.

1. When you need to scale up availability of your single instance query server, by running multiple copies.
2. When you need to secure a query server which currently executes its functions using "eval" or "value".
3. When you want to create a new query server having a secure api from the beginning.
4. When you want to assign different types of queries to different servers.



### List ideas without which people will not understand our examples

* load balancing 
* servant
* dispatch algorithm
* authentication must happen in the load balancer (when present).
* authorization/secure-invoction must happen in the servant

Note: Perhaps we should release it with the "original" or "even" dispatch algorithem as the default.
That way new users don't need to know about routing strings, or need to change to use something other
than the first argument as the routing string for their application.

Note also: In general previous testing indicated that the original dispatch algorithm had the best
average elapsed time and throughput, while the "even" algorithm ensured that servants were all 
kept busy. However the better performace came from more queries running on "warm" servant, That
advantage would be diluted in a test that ran a larger number of queries, giving all servants
a chance to warm up. We also have not yet found a case where the routing string helped.


### List ideas without which which the system is not well documented, but which most people will not need to know.

* routing string
* how/why you might want to create an alternate dispatch algorithm
* relationship bet parse and eval
* the options and info dictionaries
* how/why you might want to create an alternate calling convention
* why it is safe to send the user role from mserve to servant in the clear

Note: When trying to create a "secure invocation" protocol the problem is that the "general list format"
of a command normally uses symbol atoms to represent global variables (including user defined functions).
To use a symbol atom or list as a literal (with eval), you must enlist it.

Essentially our secure invocation protocol works by always interpreting symbol atoms and lists
as literals, except for the first item in the command as a general list, which we take to be
the api endpoint. 

### List ideas we do not want to leave undocumented but which seem a bit too detailed.

I think the parse/eval issue described above is what you had in mind for this section.


