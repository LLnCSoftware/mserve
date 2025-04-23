### 🧾 Setup Sequence for Scripted Dispatch Algorithm

The diagram above illustrates the **initial setup process** for the `"Scripted Dispatch"` algorithm used in the `mserve` load balancer system. This setup configures how incoming client requests will be routed based on a pre-defined CSV file that encodes dispatch rules.

#### 🧑‍💻 Actors (Columns):
- **015 User**: The human operator or controlling system that initiates setup and configuration.
- **025 Client**: The application that will later send requests through the load balancer.
- **035 Timer**: A periodic trigger mechanism used to schedule or initiate client activity.
- **045 mserve**: The central load balancing engine that parses configuration and manages routing.
- **055 CSV File**: The input file that defines how different symbol sets are dispatched to servants.
- **065–095 Servants**: Independent processes or threads that handle specific subsets of data ("symbol sets"). The fallback servant (095) handles anything not matched by the earlier ones.

#### 🔄 Step-by-Step Breakdown:
- **🛠 Setup Phase (020–130)**:
  - The User starts the `mserve` process with a dispatch algorithm and routing configuration from a CSV file.
  - `mserve` reads the file and dynamically spawns one **Servant** for each symbol set it finds.
  - A final **fallback servant** is also started to catch unmatched inputs.

- **📤 Request/📥 Response Phase (090–100)**:
  - The User can query `mserve` to inspect the routing table, useful for verifying which servant handles which symbols.

- **🛠 Client Initialization (110–130)**:
  - The Client is started and configured with a timer to control when it sends requests.

#### 🔣 Numbering System:
This documentation uses a **patent-style numbering scheme**:
- Numbers ending in **5** denote **entities** or **components** (columns).
- Numbers ending in **0** represent **actions** or **messages** (arrows).
- Visual cues (e.g., 🛠, 🧠, 📤, 📥) help clarify the **type of action** at a glance.

