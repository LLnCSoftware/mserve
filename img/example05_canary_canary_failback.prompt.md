I’m documenting a load balancer that uses a scripted dispatch algorithm and want to generate a Mermaid `sequenceDiagram` for the **Canary Failback Case**, using the following expert conventions:

## ✅ Style Rules:
- Use `->>` arrows for **active message passing**.
- Use **patent-style participant IDs**, prefixed with `A` and ending in `5` (e.g., A015, A025). Display both the number and name, e.g., `A045 as 045 mserve`.
- Embed **step numbers ending in 0** at the start of each message label (e.g., `030 🧠 Backup routing table`).
- Use emoji visual cues at the beginning of each message to make actions easier to understand:
  - 🛠 = setup/init step
  - 🧠 = internal logic, state change, decision
  - 📤 = request sent
  - 📥 = response received

## 🧑‍🤝‍🧑 Participants (must appear in this exact order):
```
A015 as 015 User  
A025 as 025 Client  
A035 as 035 Timer  
A045 as 045 mserve  
A055 as 055 CSV File  
A065 as 065 Servant: Symbol Set 1 (Old)  
A066 as 066 Servant: Symbol Set 1 (New)  
A075 as 075 Servant: Symbol Set 2  
A085 as 085 Servant: Symbol Set 3  
A095 as 095 Servant: Other Symbols
```

## 📘 Scenario – Canary Failback Case (Immediate Rollback):
- The User initiates a canary rollout using `setRule`, which sets globals and backs up the routing table.
- The Client sends a request to `mserve`.
- `mserve` applies `canaryFilter` to route the request to the **new version** of the servant.
- The new servant processes the request and returns a response containing an error.
- `mserve` runs `filterResponse`, detects the error, and since `cn_maxerr = 1`, it immediately triggers a failback:
  - Restores the routing table from the backup.
  - Resets canary-specific global variables.
- The error response is returned to the client.

## 📌 Additional Instructions:
- Show routing table backup and restoration as **internal self-messages** (e.g., `A045 ->> A045`).
- Show **only the new servant (A066)** receiving the request and returning an error.
- Do **not** include any branching logic or alternative paths — this is a **single-request failure leading to immediate rollback**.
- Keep all other servants visible for continuity, but do not show them receiving any messages.

Now generate the Mermaid diagram that matches this specification.

