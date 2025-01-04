# 01quickstart

## About This Example

This is a simple example of a client interacting with a servant through mserve\_np.q loadbalancer, all on one host. 
This example is insecure; it allows anyone to execute any "q" expression on a servant.

TODO: GET THE RIGHT PHRASE FROM JOHN. "Anyone on the same network as the host machine who is not stopped by a firewall rule..." 

In the next example we will demonstrate the use of our "secure\_invocation.q" module to allow
execution of only the functions defined in an ".api" namespace, preventing evaluation arguments,
and optionally implementing authentication and authorization. That example implements "secure invocation"
(See Glossary in readme.md) which is generally **very** important. 

## About the Files

**qs.q**: Simple client used for examples 1-3 ("quickstart client").  
**qsvr.q**: Simple servant used for this demo ("quick server").  
**mserve_np.q**: Symlink to the mserve load balancer at the root of the repo.

## To Do and Observe

**Step 1 - start mserve with one copy of the servant:**  

Open two terminals, one each for the servant and client, and ``cd`` into the examples/01quickstart directory.

Launch mserve as follows:

```
$ q mserve_np.q 1 qsvr.q -p 5000
```

The above starts q on port 5000, loads mserve and instructs it to start one instance of qsrv.q on localhost.

**Step 2 - start the client:**  

cd into examples/01quickstart directory then type:

```
$ q qs.q localhost 5000
```

This launches a client, qs.q, and tells it to send its requests to the load balancer on localhost port 5000.

## How it Works

### The client qs.q

* Client gets the hostname and port number for mserve from command line arguments.
* Client (qs.q) provides a "send" method, which generates a query id, and sends the id and query as a general list.
* qs.q provides a [.z.ps](https://code.kx.com/q/ref/dotz/#zps-set) handler which displays the received response.
* qs.q also provides a [.z.ts](https://code.kx.com/q/ref/dotz/#zts-timer) handler to run a series of queries with random inputs on the timer. (If you type ``\t 1000`` then this code will run one query per second.)

## The servant qsvr.q

The servant provides a sample api that has two functions "proc1" and "proc2".
They each run the same query multiple times in order increase elapsed time.
The "proc2" function has more repetitions and so is slower.

The servant code is complicated by two features.

1. Calling convention: Allow only async requests of the form (id; query), returning the same id in the response (id; result).
2. Exit on Close - Expect only one connection (to mserve). Exit when it closes.

### details

* qs.q begins by creating a "trade" table to be used as test data, on load. 
* .z.exit is configured to output a message when the servant closes.
* The api functions are provided in the main namespace.
* .z.pg is configured to disallow synchronous requests, by always returning "USE ASYNC".
* .z.po is configured to set .z.pc:{exit 0} to implement exit upon close.
    * Note: this sets .z.pc when the first connection is opened, and will cause exit when any connection closes. 
    * If .z.pc was set while the servant was still loading, it would exit immediately after loading.
* .z.ps is configured to implement the calling convention
    * The query id expected as the first item of the request is returned as the first item of the response.
    * The query is evaluated in an error trap. Upon error the message is returned in place of the result.

Note: This example is simple and **very insecure** as described at the start of this file. See examples/02quickauth
for a much more practical example of how to use this load balancer. 
