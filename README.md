# mserve
Enhanced mserve load balanced solution

Enhanced mserve load balanced solution based on [mserve_np](https://github.com/nperrem/mserve) which was based on [LoadBalancing](https://code.kx.com/trac/wiki/Cookbook/LoadBalancing) adding "servants" on multiple remote hosts, and providing for query locality. Also designed to provide benchmarking information.

### Example Sequence Diagram

The diagram below shows the messages exchanged in the demo above

![Sequence Diagram](img/sequencediagram.png)

* When you run ``send proc1 `IBM`` in the quickstart demo:
    * The message ``(1234; "proc1 `IBM")`` is sent from the client to mserve\_np.
    * mserve\_np sends the query to an internal function (denoted "match dispatcher")
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

**Servant** An instance of your api server managed my mserve. When used by itself "servant" might refer to either
a "servant process" (an running instance of your api), or a "servant host" (the machine an instance of your api is running on).

**Plugin** A program that provides some optional functionality to a "main" program without modifying the main program's source code.
The "main" program may provide code to load the plugins, but which plugins get loaded is determined at launch time,
in our case by an environment variable. The environment variable Q_PLUGINS lists the plugins for the servant processes,
while the variable MSERVE_PLUGINS lists the plugins for mserve_np.q itself.
 
**Dispatch Algorithm** A means of selecting a servant to run a particular query. In mserve_np.q, a dispatch algorithm
is selected by copying it to the global variable "check". Currently, there are 3 dispatch algorithms available:
- **orig**: From the original. Always select the first not-busy server from the top of the list.
- **even**: Avoids unused or under-utilized servants. Always select the next not-busy server futher down the list from last dispatch. 
- **match**: Attempts to improve performance by keeping similar queries on the same servant so that data will be "warm".

The "match" algorithm is the default, which may be changed by setting the MSERVE_ALGO env variable to "orig" or "even".
New dispatch algorithms may be added as plugins.
   
**Routing String** A string (or symbol) derived from a query expression which is used to help select the best servant 
on which to run that query. Only the "match" dispatch algorithm uses a routing string.

The default routing string is just the first argument to the command. That may be changed by setting the MSERVE_ROUTING 
env variable to "q" function definition which accepts the parsed expression and returns the routing string as a symbol.



