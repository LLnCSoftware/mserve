# mserve

## Document Revision Notes
This document has been enhanced with TODOs to highlight areas needing clarification or improvement:

1. Terminology
   - API vs API Version distinction ([→ todo-t1](#todo-t1))
   - Cache thrashing explanation ([→ todo-t3](#todo-t3))
   - Infrastructure terms ([→ todo-t4](#todo-t4))
   - Servant terminology ([→ todo-t5](#todo-t5))

2. Technical Details
   - Dispatch algorithm implementation ([→ todo-t2](#todo-t2))
   - Routing string mechanics ([→ todo-e1](#todo-e1))
   - Plugin examples ([→ todo-t6](#todo-t6))
   - Global variable usage ([→ todo-t7](#todo-t7))
   - Data locality concepts ([→ todo-t8](#todo-t8))
   - Error handling strategy ([→ todo-t9](#todo-t9))
   - Message protocol details ([→ todo-t10](#todo-t10))

3. Performance
   - Benchmark methodology ([→ todo-p1](#todo-p1))
   - Test comparisons ([→ todo-p2](#todo-p2))
   - System terminology ([→ todo-p3](#todo-p3))
   - Scaling limits ([→ todo-p4](#todo-p4))
   - Network overhead ([→ todo-p5](#todo-p5))

4. Examples
   - Memory bottlenecks ([→ todo-e2](#todo-e2))
   - Routing patterns ([→ todo-e1](#todo-e1))
   - Migration guide ([→ todo-e3](#todo-e3))
   - Configuration patterns ([→ todo-e4](#todo-e4))

Each TODO is linked to its location in the document and includes specific action items for improvement.

## Document Symbols Guide
This document uses the following symbols to highlight areas needing attention:

| Symbol | Meaning | How to Search |
|--------|----------|---------------|
| ⚠️ | Indicates spelling, grammar, or consistency issues | Search for `⚠️` |

Example: `word ⚠️[correction]` indicates that 'word' should be 'correction'

---

# mserve
Enhanced mserve load balanced solution

Enhanced mserve load balanced solution based on [mserve\_np](https://github.com/nperrem/mserve) 
by Nathan Perrem, formerly of First Derivatives, in turn was based on [LoadBalancing](https://code.kx.com/trac/wiki/Cookbook/LoadBalancing) 

Here we are adding:

* "servants" on multiple remote hosts
* providing for programmable dispatch to allow for such things as improved data locality, and 
* providing benchmarking information for easier tuning. 

### Example Sequence Diagram.

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

## todo-t9
[Define error handling strategy]
QUESTION: We need to clarify our error handling approach:
1. What happens if all servants are busy?
2. How do we handle servant failures?
3. Is there retry logic?
This impacts system reliability and debugging.

3. When the servant responds with a result table
    * The message ``(1234; <result table>)`` is sent from the servant to mserve\_np.

4. When mserve\_np receives the result
    * msevere\_np ⚠️[mserve\_np] notices that the response includes only the id and result, no extra "info".
    * For that reason it provides a default "info dictionary" that reports: 
       * the routing string used
       * which servant ran the request
       * elapsed time (includes time in queue)
       * execution time (excludes time in queue)
    * If the servant had provided its own info dictionary as the 3rd item in the response  
      mserve\_np would return that dictionary, with the routing string added to it.
    * The message ``(1234; <result table>; <info dictionary>)`` is sent back to the client

## todo-t10
[Document message protocol]
QUESTION: We should document our message protocol more thoroughly:
1. What are all possible message formats?
2. How do we handle malformed messages?
3. Is there a size limit on messages?
This would help teams implement reliable client integrations.

## MServe Glossary  

**API Version:** An API specifies exactly what functions are documented to be supported 
by a server, what arguments they take and what it means to run this function, including what
it returns. A servant could be documented to support more than one API Version which it could support 
by shunting the calls to different name spaces depending on what API version the client 
request says it is expecting to support. 

## todo-t1
[Review and clarify API versioning model]
QUESTION: We should clarify the relationship between API documentation and version support. Currently, the text discusses API versions but doesn't fully explain:
1. What constitutes our API (the interface itself)
2. How version changes are determined
3. How API documentation relates to version support
This distinction is important for maintainers and users of the system.

**Server Type Name:** Say I am at hedge fund named HF and we have some code we use to do RDB computations 
and some to do HDB computations. Mserver could be configured with a plugin to know which queries should be
sent to which servers because we realized that it is valuable to keep the data for the last 48 hours in RDB 
and the older information in HDB. This could turn out to be a major performance enhancement. It is powerful to allow 
mserve to ⚠️[route] the query to the right server without having to change the client, just based on
things like start and end date of the query API call. A server type named HF_RDB and another HF_HDB, 
a dispatch ⚠️[algo] could know that we expanded what we expanded from 24 hours in the RDB to 48 in the RDB 
at a certain point ⚠️[and] dispatch accordingly. 

**Server Type Version:** We might want to gradually replace one server with another
server because any of a number issues:

* A code change that supports a new API, but still supports the old API. 
* A code change that supports a new API, but does not ⚠️[support] the old API. 
* A code change that improves efficiency or ⚠️[fixes] a bug and does not change any of the operation names, the arguments they take, what they do or what they return, so no need for any client to change and thus no need to have a new API ID.

## todo-p4
[Document scaling characteristics]
QUESTION: We should specify our scaling boundaries:
1. What's the max number of servants we've tested?
2. Are there message size limits?
3. What resource constraints should teams plan for?
This helps teams plan capacity effectively.
* A configuration change, such as moving from one EC2 instance type to another or changing an environment var 
  that impacts how much memory the KTV instance is allowed to grow to use. 

When a server administrator deploys a new servant, and wants to do it using canary capability, 
mserver needs a way to know which servant is intended to replace what other servant. 


**Secure Invocation:** The practice of executing q functions or operations in a controlled manner, 
without evaluating arbitrary expressions. This mitigates security risks associated with executing 
client-provided strings, which might contain malicious code. Instead, Secure Invocation only allows 
execution of a limited number ⚠️[of] pre-defined functions, as in a conventional API call. In addition,
Secure invocation must prevent execution of arbitrary expressions which might appear in the
arguments to the functions.

_key characteristics_

- Reduces the risk of code injection attacks.
- Allows execution of only a pre-defined set of commands.
- Arguments are validated or sanitized before command is executed.

See: [Interprocess Communication 101](https://code.kx.com/q4m3/1_Q_Shock_and_Awe/#119-interprocess-communication-101)  

Also for more details about **Secure Invocation** see: "Understanding secure\_invocation.q" in examples/02quickauth/02quickauth.q.

-----------
REWRITE:  
#### Secure Invocation: 

Secure Invocation:
The practice of executing only a limited set of pre-defined q functions in a ?? controlled manner, disallowing arbitrary string evaluation. This reduces security risks such as code injection, which can arise from evaluating client-provided strings containing potentially malicious code. Like conventional API calls, Secure Invocation ensures that only registered and explicitly permitted functions can be executed, and that their arguments are properly validated (and potentially sanitized.) It also prevents the execution of arbitrary expressions passed as arguments.

_Security Guarantees_ ??? (need to rethink this part maybe)

- Prevents code injection by disallowing arbitrary q code evaluation.

- Limits execution to a pre-defined, registered set of safe functions.

- Ensures arguments are validated or sanitized before invocation.

For an introduction to interprocess communication, see [Interprocess Communication 101](https://code.kx.com/q4m3/1_Q_Shock_and_Awe/#119-interprocess-communication-101)  

For implementation details on **Secure Invocation** see: "Understanding secure\_invocation.q" in examples/02quickauth/02quickauth.q.

⚠️[MISSING REFERENCE] For implementation details on **Secure Invocation** see: "Understanding secure\_invocation.q"

-----------

**Servant** An instance of your api server managed ⚠️[by] mserve. When used by itself "servant" might refer to either
a "servant process" (⚠️[a] running instance of your api), or a "servant host" (the machine an instance of your api is running on).

-------
## todo-t5
[Clarify servant terminology]
QUESTION: We need to establish clear terminology guidelines:
1. What exactly is a "servant" in our system?
2. How does our usage differ from other contexts?
3. What are the key responsibilities of a servant?
This will help prevent confusion in technical discussions.

------

**Plugin** A program that provides some optional functionality to a "main" program without modifying the main program's source code.
The "main" program may provide code to load the plugins, but which plugins get loaded is determined at launch time,
in our case by an environment variable. The environment variable Q\_PLUGINS lists the plugins for the servant processes,
while the variable MSERVE\_PLUGINS lists the plugins for mserve\_np.q itself.

-------

## todo-t6
[Document plugin system]
QUESTION: We need to document the plugin architecture:
1. What types of plugins are supported?
2. What are common use cases for plugins?
3. How can teams develop custom plugins?
This will help teams extend the system effectively.

-----
 
**Dispatch Algorithm** A means of selecting a servant to run a particular query. In mserve\_np.q, a dispatch algorithm
is selected by copying it to the global variable "check". Currently, there are 3 dispatch algorithms available:

- **orig**: From the original. Always select the first not-busy server from the top of the list.
- **even**: Avoids unused or under-utilized servants. Always select the next not-busy server ⚠️[farther] down the list from last dispatch. 
- **match**: Attempts to improve performance by keeping similar queries on the same servant so that data will be "warm".

The "match" algorithm is the default.
To use a different one, set the environment variable 'MSERVE\_ALGO' when launching mserve.
For example, to run with 5 instances of "servant.q" using the 'even' algorithm you could type:

```
MSERVE_ALGO="even" q mserve-np.q 5 servant.q -p 5000
```

New dispatch algorithms may be added as plugins, see "examples/04dispatch/04dispatch.md."

## todo-e3
[Create migration guide]
QUESTION: We need a practical migration guide:
1. How do teams transition from monolithic to distributed?
2. What are common migration pitfalls?
3. Can we provide a phased approach?
This would help teams adopt the technology safely.

## todo-e4
[Document configuration patterns]
QUESTION: We should document real-world configurations:
1. What are typical production setups?
2. How do different team sizes affect configuration?
3. What environment variables matter most?
This helps teams choose appropriate configurations.


----

## todo-t2
[Document dispatch algorithm implementation details]
## todo-t7
[Explain global state management]
QUESTION: We need to clarify our state management:
1. How is the global 'check' variable used?
2. What are the implications of this design?
3. Are there thread-safety considerations?
This will help developers understand our state management approach.



## todo-t8
[Explain data locality principles]
QUESTION: We need to explain our data locality strategy:
1. What do we mean by "warm" data?
2. How does data locality affect performance?
3. What are the benefits of our approach?
This will help teams optimize their data access patterns.

   
**Routing String** A string (or symbol) derived from a query expression which is used to help select the best servant 
on which to run that query. Only the "match" dispatch algorithm uses a routing string.

The default routing string is just the first argument to the command. That may be changed by setting the MSERVE_ROUTING 
env variable to a "q" function definition which accepts the parsed expression and returns the routing string as a symbol.
You can also override the "getRoutingSymbol" function from a plugin. 

----
## todo-e1
[Add examples of routing string patterns and usage]
QUESTION: What does the routing string actually look like? An example and explanation of the mechanics might be useful. This is broadly confusing to me. It is used to help select the best servant but apparently is only used in only ONE of the algorithms. Why? What is used in the other cases? 

----

## When do ⚠️[should you] use this Technology?



### Current Performance

- **When you think you are in a situation where spikes of incoming requests cause frequent slowdowns**  
  *Consider option:* Distributing requests across multiple servers using a load balancer to mitigate CPU saturation on any single node.


## todo-p3
[Define system terminology]
QUESTION: We need to define key system concepts:
1. What constitutes CPU saturation?
2. What defines a node in our architecture?
3. How do these concepts affect scaling decisions?
This will help teams understand system behavior and limitations.



- **When you think you are in a situation where memory usage on one server is causing bottlenecks**  
  *Consider option:* Splitting data or queries among nodes so each node handles only a subset of the workload.


## todo-e2
[Document memory bottleneck scenarios]
QUESTION: We need concrete examples of memory bottlenecks:
1. What are typical scenarios that create memory pressure?
2. How do these manifest in production?
3. What resolution strategies have worked?
Real-world examples would help teams identify and address similar issues.


- **When you think you are in a situation where a single machine can be upgraded but might still struggle under peak load**  
  *Consider option:* A lightweight enhancement like socket sharding on Linux to better utilize multiple CPU cores and reduce queue times.







- **When you think you are in a situation where cache thrashing leads to poor query performance**  
  *Consider option:* Routing queries to servers holding relevant data in memory, improving local cache efficiency.

## todo-t3
[Document cache behavior and optimization]
QUESTION: We need to explain cache thrashing in our context:
1. What specific conditions trigger cache thrashing in our system?
2. How does it impact query performance?
3. What are our recommended mitigation strategies?
This will help teams diagnose and prevent performance issues. 

- **When you think you are in a situation where your team invests too much time tuning one massive server**  
  *Consider option:* Multiple smaller servers with a load balancer to simplify configuration and reduce single-server complexity.

## todo-p5
[Analyze network overhead]
QUESTION: We should quantify our network impact:
1. What's the message overhead per request?
2. How does network latency affect performance?
3. Are there bandwidth considerations?
This helps teams optimize their network architecture.



### Scalability and Future-Proofing

- **When you think you are in a situation where traffic or data volume is expected to grow significantly**  
  *Consider option:* Implementing load balancing to easily add more servers horizontally as demands increase.

- **When you think you are in a situation where you want to avoid big “forklift” upgrades**  
  *Consider option:* Incrementally adding mid-range servers behind a load balancer, rather than purchasing a single high-end box.

## todo-t4
[Document infrastructure evolution strategies]
QUESTION: We should clarify our infrastructure terminology, specifically:
1. What exactly constitutes a "forklift" upgrade in our context?
2. Why is our incremental approach with load balancing preferable?
3. What are the cost/benefit tradeoffs?
This will help teams make informed infrastructure decisions.

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

## todo-p1
[Document complete benchmark methodology and environment]

These numbers were obtained by timing a round trip to the servant for an "echo" query
(which just returns its single argument).

The servant is the servant.q used in the examples (to which the "echo" function was added),
except in the case of "NP" (the original mserve\_np.q by Nathan Perrem). That version needed
to use it own servant because it sends a function to be evaluated which is not allowed by
secure invocation.

## todo-p2
[Add comparative analysis between test iterations]

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
