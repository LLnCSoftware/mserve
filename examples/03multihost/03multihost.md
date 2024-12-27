# 03multihost

## About this Example

This example uses the same client, servant, and plugins as 02quickauth.
The added functionality is starting the servants on multiple remote hosts.

## New/Modified Files

launcher.q - Listens on port 5999 for requests to start servant processes as directed by mserve\_np.q.

## To Do and Observe

**Step 1 - Prepare the hosts**

You will need 3 machines that are accessible to each other over the network;
2 as servants and one for both mserve\_np.q and the client. 

The way I did it was with 3 AWS EC2 instances each containing the mserve repo.

1. Determine the IP address of the "mserve machine".
2. Ensure that the "mserve machine" can reach the 2 servant machines on ports 5999 and 5001.
3. Run 'Q\_SERVANTOF='ip address' q launcher.q -p 5999' from the mserve/examples/03multihost directory on each servant machine.

The logic for Q\_SERVANTOF is different in launcher.q than in servant.q.
It ONLY restricts access to the specified IP address (.z.pw) 
It accepts multiple connections and does not terminate automatically (no .z.po). 

**Step 2 - Start the server in a terminal on the mserve machine**

Assuming the IP addresses of the servant AWS instances are 172.30.0.20 and 172.30.0.207, start mserve as follows.
You may enable authentication/authorization by provideing the KDBQ\_PLUGINS env variable as in 02quickauth.

```
q mserve_np.q 2 servant.q 172.30.0.20 172.30.0.207 -p 5000   /no authentication or authorization
MSERVE_PLUGINS='authent.q' Q_PLUGINS='authriz.q' q mserve_np.q 2 servant.q 172.30.0.20 172.30.0.207 -p 5000  /with auth-auth
```

This runs mserve\_np.q on the mserve machine, listening on port 5000,
with one instance of servant.q running as 172.30.0.20:5001 and another as 172.30.0.207:5001
  
If the number of servants was greater than the number of IP addresses, additional servant processes
would be started using successive port numbers.

For example, if the number of servants was 3, you would get servant processes running as:
172.30.0.20:5001, 172.30.0.20:5002, and 172.30.0.207:5001

  
**Step 3 - Start the demo client in another terminal on the mserve machine**

Try each of the same commands as in the 02quickauth demo:

```
q qs.q localhost 5000                 /'access error                (unless no authentication on server)
q qs.q localhost 5000 ken ken         /ordinary user - proc1 only   (unless no authentication on server)
q qs.q localhost 5000 arthur arthur   /power user - proc1 and proc2 (full control)
```

**Step 4 - Try some test queries** 

Try each of the same queries as in the 02quickauth demo

```
send "proc1 `IBM"
send "proc2 `IBM"
```

Note that "proc1" should work whenever the client started without an 'access error,
but "proc2" should produce an "unknown command" error, unless you started the client as "authur",
or did not specify the plugins when starting mserve.

This is the same behavior as in 02quickauth (ie. all servants on localhost).

**Step 5 - Check the info to see which servant the query ran on**

The response displayed on the client for each request should look sort of like:

```
ID:23
--info--
qsvr     | `:172.30.0.207:5001
elapsed  | 5892
execution| 5892
route    | `IBM
backlog  | 0
remaining| 1
--result--
SYM MAX      MIN          OPEN    CLOSE    AVG      VWAP     DEV      VAR    
------------------------------------------------------------------------------
IBM 99.99956 5.739275e-05 1.89879 58.87289 50.04816 50.04443 28.84313 831.9261
```

* **qsvr** shows the host/port of the servant that ran the query.
* **route** shows the routing string used to help select this servant (or null symbol for "no routing").
* **elapsed** shows elapsed time including time spent in queue.
* **execution** shows elapsed time excluding time spent in queue.
* **backlog** shows number of queries enqueued BEFORE this one.
* **remaining** shows number of queries enqueued AFTER this one.

**Step 6 - Run a series of queries, and check how they were distributed accoss the servants**

Set the timer to a little more than half of the execution time you tend to see in the above tests.
This will build up a backlog, but not a huge backlog. After around 30 seconds stop the timer,
and watch the backlog clear. You know its finished when "remaining" is zero.

Now you can scroll back and see which servant each query ran on... But, thats kind of tedious.

**Step 7 - Check the status of recent queries using the mserve_np console**

On the terminal that is running mserve\_np.q, enter the following query:

```
q) select client_qid, query, route, slave_handle, location from queries

client_qid query         route slave_handle location
----------------------------------------------------
1          "proc1 `MSFT" MSFT  -7           client  
2          "proc1 `GS"   GS    -6           client  
3          "proc1 `BA"   BA    -7           client  
4          "proc1 `AAPL" AAPL  -6           client  
5          "proc1 `BA"   BA    -7           client  
..
```

The queries table is where mserve\_np keeps track of the queries it is currently processing
or has recently completed. Its not really a "queue" because its not FIFO, but we often call it
that because its where queries wait to be dispatched to a servant.

The "location" field tells the status of the query:

* master - enqueued
* servant - running
* client - finished

The servant used is recorded as "slave\_handle".
The host and port corresponding to each "slave handle" is stored in a dictionary "d" as a pair of strings.
So you can convert this to a socket address symbol using the function:

```
{[handle] `$ ":", ":" sv d handle}
```

To check how the queries were distributed to the servants you can use the following. 

```
select n:count i, distinct route by servant: {`$ ":", ":" sv d x} each slave_handle from queries where location=`client
servant            | n  route                        
-------------------| --------------------------------
:172.30.0.20:5001  | 10 `GOOG`MSFT`AAPL`UBS`GS`IBM`BA
:172.03.0.207:5001 | 11 `GS`BA`GOOG`IBM`AAPL`UBS     
```

This shows the number of queries handled by each servant, and the distinct routing strings among them. 

