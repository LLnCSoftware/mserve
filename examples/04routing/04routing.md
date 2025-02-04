# 04routing

## About this Example

We show how to implement a dispatch algorithm as a plugin.  

TODO: dispatch seems a better word than routing. Is there a good reason to use two words for this one idea?
TODO: Put in a section that says, in general, to write a dispatching plugin, you should do the following: 
 1-Add a file to the xyx directory that starts with "dispatch-"
 2-Add a function to that file that will be called with the following arguments... make it a step-by-step process, ok? Or is this in there already? 

This example uses the same client and servant as the examples 02quickauth and 03multihost,
including secure\_invocation.q but without the authentication and authorization plugins.

## New/Modified Files

match.q - An mserve plugin implementing a dispatch algorithm (actually the same as the included "match" algorithm,
but displays the name "match-plugin" on startup).  
TODO: But it is not, it uses sysmbols insgtead of dates? 

## How it Works

### Plugin Environment  

 - A given plugin can generally only be used by a program that has been specifically designed to accommodate it. TODO: What do you mean by this? Why would you say this? I could have a catchall servant and a special servant for queries that are entirely about year 2025, another for 2024, etc. What would need to be specifically designed to accommodate what? 
 - Accommodation is usually provided as particular global variables that are intended to be overwritten by the plugin. TODO: Not clear to me. Perhaps say "see section X for an example of accommodating a foo to a bar so that baz will happen. 
 - Accommodation may also include particular global variables intended to be used by the plugin. TODO: to permiatierizer the behvaior of the routing / dispatching? Add a "for example"? 

In the case of match.q and mserve\_np.q:

 - The following global variables are intended to be overwritten:
   - **string "algo"**     - provides the name of the dispatch algorithm displayed on startup
   - **function "check"**  - provides the algorithm itself

 - The following global variables are intended to be used: 
   - **function "getArguments"** - parses specified command, always interpreting symbols as literals, not variables
     and rejecting expressions that contain functions or function evaluation in their arguments.
   - **dictionary "h"**        - maps each handle to the list of queries pending on that handle.
   - **dictionary "hroute"**   - maps each handle to its last routing symbol.
   - **dictionary "hidle"**    - maps each handle to its idle timestamp (when last query finished).
   - **timestamp "nextCheck"** - schedules a call to "check" at the specified time (+infinity 0Wp to surpress)
   - **function "addMs"**      - adds milliseconds to a timestamp.

TODO: 1: **used** by whom to do what? 2: Are these vars about this one specific plugin or vars that all plugins will need to use? No idea. (Perhaps I'm reading too fast?)

### Understanding match.q

The algorithm can be briefly described as follows:
1. Attempt to send query to a servant with the same routing symbol. 
2. If some servant has the same routing symbol but is busy, do nothing (wait for it to finish).
3. Otherwise, attempt to send query to a servant without a routing symbol (or expired routing symbol.)
4. Otherwise, set "nextCheck" to request a call on the timer (wait for some routing symbol to expire).

The algorithm is installed as the "check" function of mserve\_np.q which is called:
1. When a query is received from a client
2. When a response is received from a servant
3. On a timer tick that finds the "nextCheck" timestamp in the past.

This algorithm attempts to keep api requests with the same routing symbol on the same server.
In order to do that it may:
1. Not dispatch requests in the order they are received.
2. Make requests wait for a server with their route even when another server is available.
3. Once all servers have been assigned a route, make any requests for additional routes,
   wait some server's route to expire.

It still finishes each batch of requests in about 1/3 the time of the "even" algorithm,
because most requests run with a warm cache.

## To Do and Observe

**start the server**

```
MSERVE\_PLUGINS='match.q' q mserve\_np.q 8 servant.q -p 5000
```

We run with 8 servants on localhost. 
We use 8 servants because the client submits queries for 8 distinct symbols on the timer,
and we want each symbol to be routed to its own servant.

**start the client**

```
 q qs.q localhost 5000    /start the client
 \t 2000                  /start the timer
```

Let it run about 60 queries then stop the timer and let the backlog clear.

**Check results using the mserve console**

After all requests have finished, in the mserve terminal, enter the following query:

```
select route by slave_handle from queries
```

You are likely to see something like the below. 

The first row, for example, means that the server with handle -13 got quires with the symbols which were `gs repeatedly in sequence. 

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
TODO: THIS IS NOT A POINT ABOUT HOW TO WRITE A DISPATCHING PLUGIN SO I AM NOT SURE IT BELONGS. 
TODO: NOW YOU ARE TALKING ABOUT THIS SPEICFIC PLUGIN? BUT THAT IS OFF TOPIC. 

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

TODO: THE BELOW DOES NOT MAKE SENSE AS THE APPLICATION PROGRAMMER DOES NOT CONTROL WHEN THE REQUESTS WILL HAPPEN. 

That can generally be corrected by submitting the requests faster so as to build up
a larger backlog, or allowing more time for routing symbols to expire.




