
Here’s the current state of the diagram (feel free to regenerate or modify it):

```mermaid
sequenceDiagram
    participant A015 as 015 User
    participant A025 as 025 Client
    participant A035 as 035 Timer
    participant A045 as 045 mserve
    participant A055 as 055 CSV File
    participant A065 as 065 Servant: Symbol Set 1
    participant A075 as 075 Servant: Symbol Set 2
    participant A085 as 085 Servant: Symbol Set 3
    participant A095 as 095 Servant: Other Symbols

    A015 ->> A045: 020 🛠 Start mserve with "Scripted Dispatch" + CSV
    A045 ->> A055: 030 🧠 Read dispatch rules from CSV

    alt 040 🧠 For each symbol set
        A045 ->> A065: 050 🛠 Spawn servant for Symbol Set 1
        A045 ->> A075: 060 🛠 Spawn servant for Symbol Set 2
        A045 ->> A085: 070 🛠 Spawn servant for Symbol Set 3
    end
    A045 ->> A095: 080 🛠 Spawn fallback servant

    A015 ->> A045: 090 📤 Request routing table
    A045 ->> A015: 100 📥 Return routing table

    A015 ->> A025: 110 🛠 Start client
    A015 ->> A025: 120 🛠 Set timer parameters
    A025 ->> A035: 130 🛠 Initialize periodic trigger

