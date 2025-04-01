# mserve
Enhanced mserve load balanced solution

Enhanced mserve load balanced solution based on [mserve\_np](https://github.com/nperrem/mserve) 
by Nathan Perrem, formerly of First Derivatives, in tern was based on [LoadBalancing](https://code.kx.com/trac/wiki/Cookbook/LoadBalancing) 

Here we are adding:

* "servants" on multiple remote hosts
* providing for programmable dispatch to allow for such things as improved data locality, and 
* providing benchmarking information for easier tuning. 

### Example Sequence Diagram

The diagram below shows the messages exchanged in the demo above

![Sequence Diagram](img/sequencediagram.png)

* When you run ``send proc1 `IBM`` in the quickstart demo:
    * The message ``(1234; "proc1 `IBM")`` is sent from the client to mserve\_np, which is the 
      client's way of saying to the load balancer "execute the function 'proc1' with argument `IBM and return the result to me with id 1234".
    * mserve\_np sends the query to an internal function (denoted "match dispatcher"). (To see how to 
      select or develop a different method of dispatch, see "examples/04dispatch/04dispatch.md".)
    * which sends back a "routing string" in this case the first argument to the query: `IBM.   

2. When this message is ready to be sent:
    * The routing string is used to select a servant.
    * Prefer to send a query to a servant whose previous query had the same routing string.
    * If preferred servant is not available choose any free (i.e., not busy) servant.
    * The message ``(1234; "proc1 `IBM)`` is forwarded to the selected servant unchanged.

3. When the servant responds with a result table
    * The message ``(1234; <result table>)`` is sent from the servant to mserve\_np.

4. When mserve\_np receives the result
    * msevere\_np notices that the response includes only the id and result, no extra "info".
    * For that reason it provides a default "info dictionary" that reports: 
       * the routing string used
       * which servant ran the request
       * elapsed time (includes time in queue)
       * execution time (excludes time in queue)
    * If the servant had provided its own info dictionary as the 3rd item in the response  
      mserve_np would return that dictionary, with the routing string added to it.
    * The message ``(1234; <result table>; <info dictionary>)`` is sent back to the client

## MServe Glossary  

**API Version:** An API specifies exactly what functions are documented to be supported 
by a server, what arguments they take and what it means to run this function, including what
it returns. A servant could be documented to support more than one API Version which it could support 
by shunting the calls to different name spaces depending on what API version the client 
request says it is expecting to support. 

**Server Type Name:** Say I am at hedge fund named HF and we have some code we use to do RDB computations 
and some to do HDB computations. Mserver could be configured with a plugin to know which queries should be
sent to which servers. Press we realized that it is valuable to keep the data for the last 48 hours in RDB 
and the older information in HDB. This could turn out to be a major performance enhancement. It is powerful to allow 
mserve to rout the query to the right server without having to change the client, just based on
things like start and end date of the query API call. A server type named HF_RDB and another HF_HDB, 
a dispatch alog could know that we expanded what we expanded from 24 hours in the RDB to 48 in the RDB 
at a certain point adn dispatch accordingly. 

**Server Type Version:** We might want to gradually replace one server with another server because any of a number issues:

* A code change that supports a new API, but still supports the old API. 
* A code change that supports a new API, but does not supports the old API. 
* A code change that improves efficiency or fix a bug and does not change any of the operation names, the arguments they take, what they do or what they return, so no need for any client to change and thus no need to have a new API ID.
* A configuration change, such as moving from one EC2 instance type to another or changing an environment var 
  that impacts how much memory the KTV instance is allowed to grow to use. 

When a server administrator deploys a new servant, and wants to do it using canary capability, 
mserver needs a way to know which servant is intended to replace what other servant. 

**Secure Invocation:** The practice of executing q functions or operations in a controlled manner, 
without evaluating arbitrary expressions. This mitigates security risks associated with executing 
client-provided strings, which might contain malicous code. Instead, Secure Invocation only allows 
execution of a limited number pre-defined functions, as in a conventional API call. In addition,
Secure invocation must prevent execution of arbitary expressions which might appear in the
arguments to the functions.

_key characteristics_

- Reduces the risk of code injection attacks.
- Allows execution of only a pre-defined set of commands.
- Arguments are validated or sanitized before command is executed.

See: [Interprocess Communication 101](https://code.kx.com/q4m3/1_Q_Shock_and_Awe/#119-interprocess-communication-101)  

Also for more details about **Secure Invocation** see: "Understanding secure\_invocation.q" in examples/02quickauth/02quickauth.q.

**Servant** An instance of your api server managed my mserve. When used by itself "servant" might refer to either
a "servant process" (an running instance of your api), or a "servant host" (the machine an instance of your api is running on).

**Plugin** A program that provides some optional functionality to a "main" program without modifying the main program's source code.
The "main" program may provide code to load the plugins, but which plugins get loaded is determined at launch time,
in our case by an environment variable. The environment variable Q\_PLUGINS lists the plugins for the servant processes,
while the variable MSERVE\_PLUGINS lists the plugins for mserve\_np.q itself.
 
**Dispatch Algorithm** A means of selecting a servant to run a particular query. In mserve\_np.q, a dispatch algorithm
is selected by copying it to the global variable "check". Currently, there are 3 dispatch algorithms available:
- **orig**: From the original. Always select the first not-busy server from the top of the list.
- **even**: Avoids unused or under-utilized servants. Always select the next not-busy server further down the list from last dispatch. 
- **match**: Attempts to improve performance by keeping similar queries on the same servant so that data will be "warm".

The "match" algorithm is the default.
To use a different one, set the environment variable 'MSERVE\_ALGO' when launching mserve.
For example, to run with 5 instances of "servant.q" using the 'even' algorithm you could type:

```
MSERVE_ALGO="even" q mserve-np.q 5 servant.q -p 5000
```

New dispatch algorithms may be added as plugins, see "examples/04dispatch/04dispatch.md."
   
**Routing String** A string (or symbol) derived from a query expression which is used to help select the best servant 
on which to run that query. Only the "match" dispatch algorithm uses a routing string.

The default routing string is just the first argument to the command. That may be changed by setting the MSERVE_ROUTING 
env variable to "q" function definition which accepts the parsed expression and returns the routing string as a symbol.
You can also override the "getRoutingSymbol" function from a plugin. 

## When do use this Technology?

### Current Performance

- **When you think you are in a situation where spikes of incoming requests cause frequent slowdowns**  
  *Consider option:* Distributing requests across multiple servers using a load balancer to mitigate CPU saturation on any single node.

- **When you think you are in a situation where memory usage on one server is causing bottlenecks**  
  *Consider option:* Splitting data or queries among nodes so each node handles only a subset of the workload.

- **When you think you are in a situation where a single machine can be upgraded but might still struggle under peak load**  
  *Consider option:* A lightweight enhancement like socket sharding on Linux to better utilize multiple CPU cores and reduce queue times.

- **When you think you are in a situation where cache thrashing leads to poor query performance**  
  *Consider option:* Routing queries to servers holding relevant data in memory, improving local cache efficiency.

- **When you think you are in a situation where your team invests too much time tuning one massive server**  
  *Consider option:* Multiple smaller servers with a load balancer to simplify configuration and reduce single-server complexity.

### Scalability and Future-Proofing

- **When you think you are in a situation where traffic or data volume is expected to grow significantly**  
  *Consider option:* Implementing load balancing to easily add more servers horizontally as demands increase.

- **When you think you are in a situation where you want to avoid big “forklift” upgrades**  
  *Consider option:* Incrementally adding mid-range servers behind a load balancer, rather than purchasing a single high-end box.

- **When you think you are in a situation where you anticipate new data distribution patterns (e.g., time-partitioned data)**  
  *Consider option:* Let the load balancer direct queries to nodes specialized in different time ranges or data types.

- **When you think you are in a situation where you might add specialized infrastructure in the future**  
  *Consider option:* Designing a flexible load-balancing layer that can incorporate new hardware without major architectural changes.

- **When you think you are in a situation where you need to adapt quickly to changing traffic patterns**  
  *Consider option:* An auto-scaling approach with a load balancer that spins up or down additional servers based on real-time metrics.

### Improved Availability

- **When you think you are in a situation where high availability SLAs must be met**  
  *Consider option:* A redundant, multi-server setup behind a load balancer for automatic failover when a node goes down.

- **When you think you are in a situation where you must avoid any single point of failure**  
  *Consider option:* Replicating data or services across multiple servers and distributing traffic so that any single node’s failure is non-disruptive.

- **When you think you are in a situation where maintenance windows are disruptive**  
  *Consider option:* Temporarily removing a server from the load balancer while patching or upgrading, keeping the rest online.

- **When you think you are in a situation where you need disaster recovery across different sites**  
  *Consider option:* Geo-distributed servers behind a global load balancer, ensuring continuity if one site fails.

- **When you think you are in a situation where you experience occasional network or server hiccups**  
  *Consider option:* Automatic health checks in a load balancer to route new requests away from misbehaving nodes.

### Use of Special Hardware

- **When you think you are in a situation where some queries need GPU acceleration**  
  *Consider option:* Direct GPU-intensive queries to servers equipped with GPUs, via a specialized load-balancing policy.

- **When you think you are in a situation where certain servers have more RAM or faster SSDs**  
  *Consider option:* Routing memory-bound or I/O-heavy queries to those specific nodes for optimal performance.

- **When you think you are in a situation where certain workloads require FPGA or other hardware accelerators**  
  *Consider option:* A load balancer that tags and dispatches relevant queries to those specialized nodes only.

- **When you think you are in a situation where different nodes run different OS versions or architecture**  
  *Consider option:* A load-balancing layer that hides heterogeneity from clients and routes queries based on compatibility.

- **When you think you are in a situation where new hardware needs to be tested in production**  
  *Consider option:* Gradually shifting some percentage of traffic to the new hardware behind a load balancer, mitigating risk to the main environment.

## Speed of LBT vs Earlier Ways to do Load Balancing of KDB+/q Programmers  

What we see below is that LBT, this version, is very close to the same level of overhead 
that the less general load balancing approaches have.

The following compares the elapsed time overhead in milliseconds for 3 versions of mserve,
to that of invocation via socket sharding (direct invocation with reuse port).
[Socket sharding with kdb+ and Linux](https://code.kx.com/q/wp/socket-sharding/)


| System  |  Min  | Avg   | Max   | trials |  Comment                                 |
|---------|-------|-------|-------|--------|------------------------------------------|
| LBT     | 0.990 | 1.256 | 1.425 | 50     |                                          |
| NP      | 1.014 | 1.209 | 1.316 | 50     |                                          |
| AW      | 0.696 | 0.870 | 0.940 | 50     |                                          |
| SS      | 0.339 | 0.490 | 0.547 | 50     |                                          |

These numbers were obtained by timing a round trip to the servant for an "echo" query
(which just returns its single argument).

The servant is the servant.q used in the examples (to which the "echo" function was added),
except in the case of "NP" (the original mserve\_np.q by Nathan Perrem). That version needed
to use it own servant because it sends a function to be evaluated which is not allowed by
secure invocation.

## Previous Tests

We are calling this version LBT for Load Balancing Technology

| System  | Avg  | Max  | Min | Comment                                |
|---------|------|------|-----|----------------------------------------|
| LBT     | .411 | .515 | NA  | 30 queries and 28 took less than .5 ms |
| NP      | .367 | 1    | NA  | 19 of 30 had zero at ms precision      |
| AW      | .696 | .921 | NA  | All 30 exceeded .5 ms                  |
| SS      |      |      |     |                                        |
| Direct  |      |      |     |                                        |
| Nginx   |      |      |     |                                        |

In the above we attempt to compare the overhead associated with several different load balancing techniques. We estimate the overhead as the round trip elapsed time of an "echo" command that just returns its argument. For each technique we obtain the average and maximum elapsed time, and fraction of the requests taking less than .5 ms.

* LBT - My most recent version of mserve\_np.q using secure invocation.
* NP  - My starting point, the original mserve\_np.q by Nathan Perrem
* AW  - Arthur's original mserve

We plan to add results for:

* SS - [Socket sharding with kdb+ and Linux](https://code.kx.com/q/wp/socket-sharding/)
* Direct - No load balancer at all
* Nginx  - [Use Nginx as a tcp load balancer](https://iceburn.medium.com/nginx-tcp-load-balancing-6f9509b772f2).

In the LBT and NP versions the numbers were obtained from the timestamps in the queries table (time\_returned - time\_received)
The NP version uses the datatype "time" which has millisecond precision, while the LBT version 
uses the datatype "timestamp" with nanosecond precision. I multiply by .000001 to get milliseconds.

The AW version does not have a queries table, and hence no timestamps.
In that case we create a timestamp on the client and send it in the argument to the "echo" command.
When it arrives in .z.ps on the client I subtract this timestamp from the current timestamp.
