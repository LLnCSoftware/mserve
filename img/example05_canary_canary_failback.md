### 🧾 Understanding the Diagram: Canary Failback Scenario

This diagram illustrates how the `mserve` load balancer handles a situation where a newly deployed version of a service (referred to as a "servant") encounters an error during a **canary deployment**. A canary deployment is a strategy where a new version of a service is gradually introduced to a small subset of users to monitor its performance before a full-scale rollout.

In this scenario:

1. **Initiating the Canary Deployment**: The **User** triggers the `setRule` function to start the canary process. This action sets up necessary configurations and creates a backup of the current routing table to allow for easy rollback if needed.

2. **Client Request Handling**: The **Client** sends a request to `mserve`. Using the `canaryFilter` function, `mserve` decides to route this request to the **new version** of the servant (`A066`).

3. **Error Detection**: The new servant processes the request but returns an error. `mserve` detects this error through the `filterResponse` function.

4. **Immediate Rollback**: Since the error threshold (`cn_maxerr`) is set to 1, `mserve` immediately restores the previous routing table from the backup and resets the canary deployment state to prevent further errors.

5. **Response to Client**: Finally, `mserve` returns the error response to the client, completing the failback process.

---

#### 🔍 Key Takeaways:

- **Canary Deployment**: A method to safely test new service versions by exposing them to a limited audience before a full rollout.

- **Immediate Failback**: If the new version fails (even once, in this case), the system quickly reverts to the stable version to maintain reliability.

- **Routing Table Backup**: Keeping a backup allows for swift restoration without complex procedures.

- **Error Monitoring**: Continuous monitoring ensures that any issues with the new version are promptly identified and addressed.

This approach minimizes the risk associated with deploying new service versions, ensuring that any problems are contained and do not affect the broader user base. 
