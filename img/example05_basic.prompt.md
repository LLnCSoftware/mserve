I’m documenting a scripted dispatch load balancer and want to generate a Mermaid `sequenceDiagram` for the **Basic Case (happy path)** interaction, using the following expert conventions:

## ✅ Style Rules:
- Use `->>` arrows to indicate **active message passing**.
- Use **patent-style participant IDs**, each prefixed with `A` and ending in `5` (e.g., `A015`, `A025`). Display the ID and role in the alias, e.g., `A045 as 045 mserve`.
- Embed **step numbers ending in 0** inside each message label (e.g., `030 🧠 Check routing table`).
- Use **emoji visual cues** at the beginning of each message label to make it easier to understand:
  - 🛠 = setup/init/internal step
  - 🧠 = logic or decision-making
  - 📤 = request sent
  - 📥 = response received

## 🧑‍🤝‍🧑 Participants (in this exact order):
A015 as 015 User
A025 as 025 Client
A035 as 035 Timer
A045 as 045 mserve
A055 as 055 CSV File
A065 as 065 Servant: Symbol Set 1
A075 as 075 Servant: Symbol Set 2
A085 as 085 Servant: Symbol Set 3
A095 as 095 Servant: Other Symbols

markdown
Copy
Edit

## 📘 Scenario – Basic Case (Happy Path):
- The **Client** sends a new request to `mserve`.
- `mserve` checks its **routing table** to determine which servants are qualified to handle the query.
- It then checks its **handle dictionary (h)** to see which servants are currently available (not busy).
- `mserve` selects the **first servant** in routing table order who is both qualified and available.
- The task is dispatched to that servant.
- The servant does the computation and returns a response to `mserve`.
- `mserve` passes the response through `filterResponse` — but since a canary is not active, the function is a no-op.
- `mserve` then returns the result to the client.

## 📌 Additional Instructions:
- This is the **happy path** only. Do **not** show failure cases or branching logic.
- Show **only A065** (Servant for Symbol Set 1) receiving and responding.
- Keep **all servants visible** to preserve visual continuity, but **do not show** any interactions for A075, A085, or A095.
- Show `filterResponse` as a **self-call inside mserve** (e.g., `A045 ->> A045`) to indicate it's an internal logic step, not a separate module.

Now generate the Mermaid diagram that matches this description.

