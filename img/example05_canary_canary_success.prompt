I’m documenting a load balancer using a scripted dispatch algorithm and want to generate a Mermaid `sequenceDiagram` for the **Canary Success Case**, using the following expert conventions:

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

markdown
Copy
Edit

## 📘 Scenario – Canary Success Case (Happy Path):
- The User initiates a canary rollout using `setRule`, which sets globals and backs up the routing table.
- The Client sends a request to `mserve`.
- `mserve` applies `canaryFilter` to probabilistically route the request to either the new or old version of the servant.
- One of the versions receives the request and returns a response.
- `mserve` runs `filterResponse`, but no action is needed because the response was successful.
- The result is returned to the client.
- Over time, `new_percentage` increases until it reaches 100%, after which the canary process is completed and internal state is cleared.

## 📌 Additional Instructions:
- Show routing table backup and cleanup as **internal self-messages** (e.g., `A045 ->> A045`).
- Show **only one servant (A065 or A066)** receiving the request per instance using an `alt` block.
- Do **not** show errors or rollback — this is the **successful canary path only**.
- Keep all other servants visible for continuity, but do not show them receiving any messages.

Now generate the Mermaid diagram that matches this specification.

