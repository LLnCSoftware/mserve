# 04routing

## About this Example

We show how to implement a dispatch algorithm as a plugin.  

This example uses the same client and servant as the examples 02quickauth and 03multihost,
including secure\_invocation.q but without the authentication and authorization plugins.

## New/Modified Files

match.q - An mserve plugin implementing a dispatch algorithm (actually the same as the included "match" algorithm,
but displays the name "match-plugin" on startup).  

## How it Works

To provide a dispatch plugin you would:

- Write a new "q-file" (in our example "match.q") which defines two global variables
  - check: function implementing your new dispatch algorithm
  - algo:  provides a name for your algorithm which is displayed on the console at startup

- Include your filename in the MSERVE\_PLUGINS environment variable when starting mserve\_np.q
  - for example:  'MSERVE\_PLUGINS="match.q" q mserve\_np.q 2 servant.q'

### The "check" function

- The check function takes no arguments and returns no value. 
- The check function examines the enqueued queries, and attempts to match some query with an available server.
- If successful, it calls the "send\_query" function, providing the server handle and query id as arguments. 

### Resources available in mserve\_np.q

- **getArguments** - function which parses specified command, which must be the invocation of a user-defined function,
   always interpreting symbols in arguments as literals, not variables; and rejecting function evaluation in the arguments.
- **h**            - dictionary which maps each servant handle to the list of queries pending on that handle.
- **hroute**       - dictionary which maps each servant handle to its last routing symbol.
- **hidle**        - dictionary which maps each servant handle to its idle timestamp (when last query finished).
- **nextCheck**    - timestamp which schedules a call to "check" at the specified time (+infinity 0Wp to surpress)
- **addMs**        - function which adds milliseconds to a timestamp.

### Use of these resources

- **getArguments** - used to create a routing string from the arguments of the command.
- **h**            - used to determine if a particular server is busy.
- **hroute**       - used to determine which queries a particular server is eligable to process
- **hidle**        - used to reset the "hroute" value of a particular server to "allow any query" after a period of inactivity.
- **nextCheck**    - used to request a call to "check" on the timer. Normally the check function is called when a new query
                     or response is received. However, it may be that when a response is received, all the enqueued queries
                     have routes that are not eligable for that server, and so must wait for the route to expire. In this 
                     case, without a call on the timer, the algorithm could hang until the next query is received,
                     which might never happen.
- **addMS**        - used to compute the "nextCheck" timestamp.



### Understanding the example "match.q"

The algorithm may be briefly described as follows:
1. Compute a routing symbol for any queries for which "route" is null in the queries table. TODO: DEFINE SOMEWHERE. 
2. Find all queries whose routing symbol is also held by some not-busy servant handle
3. If any found, dispatch the first such query to the first such handle, and return.
4. Otherwise, find all queries whose routing symbol is NOT held by any servant (busy or not).
5. Also, find all handles which are not busy and whose routing symbol is unset or expired
6. If both found, dispatch the first such query to the first such handle, and return.
7. Otherwise, If the queue is not empty, request a call on the timer.


## How to test match.q: To Do and Observe

**start the server**

```
MSERVE\_PLUGINS='match.q' q mserve\_np.q 8 servant.q -p 5000
```

We run with 8 servants on localhost. 
We use 8 servants because the client submits queries for 8 distinct symbols on the timer, and we want each symbol to be routed to its own servant.

**start the client**

```
 q qs.q localhost 5000    /start the client
 \t 2000                  /start the timer
```

Let it run about 60 queries then stop the timer and let the backlog clear,
a few minutes in general. 

**Check results using the mserve console**

After all requests have finished, in the mserve terminal, enter the following query:

```
select route by slave_handle from queries
```

You are likely to see something like the following.

Note: The first row, for example, means that the server with handle -13 got queries with the symbols which were `gs repeatedly in sequence. 

```
slave_handle| route                                                                 
------------| ----------------------------------------------------------------------
-13         | `GS`GS`GS`GS`GS`GS`GS`GS`GS`GS                                        
-12         | `UBS`UBS`UBS`UBS`UBS`UBS`UBS                                          
-11         | `GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG     
-10         | `VOD`VOD`VOD`VOD`VOD                                                  
-9          | `AAPL`AAPL`AAPL`AAPL`AAPL`AAPL`AAPL`AAPL`AAPL`AAPL                    
-8          | `BA`BA`BA`BA`BA`BA`BA`BA`BA`BA`BA`BA`BA`BA`BA                         
-7          | `GS`IBM`IBM`IBM`IBM`IBM`IBM`IBM`IBM`IBM                               
-6          | `MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT
```

Note that it did a pretty good job of keeping the same symbols on the same slave, but was not perfect.
It misplaced one `GS on the same server with `IBM

Its performance can actually vary quite a bit based on the order of the requests received.

It will generally perform perfectly when:
1. The number of distinct routes is no more than the number of servants.
2. The first requests submitted are for all the distinct routes with no duplicates.

In that case the first requests establish each route on a particular servant and subsequent
requests for that route wait for that servant to be available.

There is also an interaction between the amount of time we allow for a route to expire
and the rate at which requests are submitted.

If you are getting poor results like you see below:

```
slave_handle| route                                                            
------------| -----------------------------------------------------------------
-13         | `MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT`MSFT          
-12         | `IBM`IBM`IBM`IBM`IBM`IBM`IBM                                     
-11         | `UBS`MSFT`VOD`VOD`VOD`VOD                                        
-10         | `VOD`AAPL`AAPL`AAPL`AAPL`AAPL`AAPL`AAPL`AAPL                     
-9          | `AAPL`AAPL`IBM`IBM`UBS`UBS`UBS`UBS`UBS                           
-8          | `BA`BA`BA`BA`GS`GS`GS`GS`GS`GS`GS`GS`GS                          
-7          | `GS`MSFT`BA`BA`BA`BA`BA`BA`BA`BA`BA`BA                           
-6          | `MSFT`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG`GOOG
```

That can generally be corrected by submitting the requests faster so as to build up
a larger backlog, or allowing more time for routing symbols to expire.




