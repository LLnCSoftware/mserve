### 🧾 What This Diagram Shows: Basic Case – Scripted Dispatch (Happy Path)

This diagram illustrates the **normal flow of operations** in the `mserve` load balancer when a client sends a request 
and everything works as intended — i.e., the "happy path."

It demonstrates how `mserve` handles incoming requests using a scripted dispatch algorithm that selects 
the right worker (or "servant") based on a predefined routing table and the availability of processing resources.

---
Need to explain:
This shows the operation of mserve when the "scripted.q" plugin is present.
The "symbol sets" are defined by boolean expressions in the scripted.csv file.
There is a function "getRoutingCritera" that provides the variables used in the boolean expressions,
from the arguments to the function evaluated by the query. In this case there is only one such variable,
"symbol" which is just the first argument. In general you will need to write a getRoutingCriteia function
for each application using scripted.q. You would load your override to getRoutingCriteria as a second plugin.

---

#### 💡 Key Concepts:
- **Routing Table (Qualifications):** The routing table determines *which servants are eligible* to handle each type of query. 
   This is based on pre-configured symbol sets.
- **Handle Dictionary (Availability):** The handle dictionary (`h`) tracks which servants are currently free to handle 
   a new request.
- **First Match Wins:** `mserve` selects the **first servant** in routing table order that is both *qualified* and *available*.
- **filterResponse Step:** After receiving a response, `mserve` runs it through a post-processing function called `filterResponse`. 
   In this basic case, it is a no-op (it does nothing), since no "canary" safety mechanism is in effect.

---

#### 🧩 What to Notice in the Diagram:
- Only **Servant A065** is selected to handle the request — athough other servants exist, they are either not qualified or busy. 
- The **client only talks to mserve** — it is mserve that handles all internal decisions and delegation.
- The **filterResponse function is shown as an internal logic step** (A045 → A045), highlighting that it is part of mserve, 
   not a separate system component.
- All other servants (A075, A085, A095) are **present but inactive**, which emphasizes that they are part of the pool but 
   are not selected for this particular request.

---
(Not sure what to do with the below)

#### 🛠 Why This Matters:
Understanding the basic case sets the foundation for:
- Debugging why a request was or wasn't routed to a given servant
- Extending the system to handle failure scenarios (e.g., all servants busy)
- Introducing advanced features like **canary mode**, **load-aware dispatch**, or **multi-request batching**



