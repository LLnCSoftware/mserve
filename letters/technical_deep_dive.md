# Technical Deep Dive: 24/7 KDB Operations with mserve Load Balancing

## Executive Summary

This document provides technical details on load-balancing architecture for KDB+ systems operating in 24/7 trading environments. The technology addresses the fundamental incompatibility between continuous trading and traditional end-of-day batch processing through coordinated servant management, intelligent dispatch algorithms, and zero-downtime deployment capabilities.

## 1. The 24/7 End-of-Day Challenge

### Traditional KDB Tick Architecture

Standard KDB tick architectures follow this pattern:

```
Feed → tick.q → RDB (in-memory current day)
                  ↓ (EOD flush)
                HDB (on-disk historical partitions)
```

**End-of-Day Sequence (Traditional)**:

1. tick.q writes transaction log to disk throughout the day
2. At EOD, tick.q signals RDB to flush current day's data
3. RDB writes new partition to HDB directory
4. HDB processes restart to memory-map the new partition
5. RDB purges old data and resets for the next day

**The Problem**: Steps 3-5 require the system to be unavailable. HDB servants must disconnect, restart, and reconnect. During this window (typically 2-10 minutes depending on data volume), queries fail.

With 24-hour trading, this maintenance window disappears.

### Additional Complications for Extended Trading

**Multi-Day Canary Deployments**: A bug fix deployed via canary on Monday may still be rolling out on Tuesday. The canary mechanism must not interfere with the daily EOD cycle.

**Multi-Host Synchronization**: In distributed deployments, tick logs on remote hosts must be synced before HDB ingestion begins. Log files may be 2+ days old and scattered across multiple machines.

**Query Routing During Transitions**: A query for data spanning "last 48 hours" must route correctly even while HDB servants are restarting. The system must understand which servants are serving which date ranges at any moment.

## 2. Architectural Solution: Independent EOD Processing

### Component Overview

```
                    ┌─────────────────────────────────────┐
                    │   mserve (load balancer + router)   │
                    │   - Dispatch algorithms              │
                    │   - Routing table management         │
Client Queries ────→│   - EOD orchestration               │───→ Responses
                    │   - Canary management                │
                    └─────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ↓               ↓               ↓
              ┌─────────┐     ┌─────────┐     ┌─────────┐
              │ RDB     │     │ HDB-A   │     │ HDB-B   │
              │ (live)  │     │ (pool1) │     │ (pool2) │
              └─────────┘     └─────────┘     └─────────┘
```

### Core Mechanism: Double-Buffered HDB Pools

**Concept**: Maintain two independent HDB servant pools (hdbA and hdbB). At any time, one pool is "active" (serving queries) while the other is "standby" (can be restarted safely).

**Implementation** (`tickdemo/tickdemo.q:51-68`):

```q
restart:{[suffix]
  A: select from routingTable where stype like ("hdb", suffix);
  restarting::count A;
  hclose each abs A `h;                      / close connections
  system "sleep 1";                          / wait for drops
  h:: h _/ A `h;                             / remove from handle dicts
  h2addr:: h2addr _/ A `h;
  h2route:: h2route _/ A `h;
  h2idle:: h2idle _/ A `h;
  update h:0Ni from `routingTable where address in (A `address);
  launchAll A;                               / launch new servants
  hdl: connectServant each A;                / reconnect
  update h:hdl from `routingTable where address in (A `address);
}
```

**EOD Cycle Day 1**:

1. hdbA is active, serving queries for all historical data
2. EOD trigger arrives from RDB
3. mserve calls `restart["B"]` - restarts hdbB pool
4. hdbB servants ingest new partition while hdbA continues serving
5. When hdbB ready, mserve marks hdbB active
6. Queries now route to hdbB

**EOD Cycle Day 2**:

1. hdbB is active, serving queries
2. EOD trigger arrives
3. mserve calls `restart["A"]` - restarts hdbA pool
4. hdbA ingests new partition while hdbB continues serving
5. Cycle repeats

**Key Insight**: Queries never stop. One pool is always available while the other restarts.

### Separation of Canary and EOD Mechanisms

**Previous Design Problem**: Canary deployments modified the routing table by adding phase-in servants and marking phase-out servants. EOD processing also modified the routing table to restart HDB servants. These two mechanisms interfered with each other.

**Solution** (commit 105b213):

Canary state is now maintained separately:
- `cn_phasein` and `cn_phaseout` - bit vectors marking which servants are being phased in/out
- `canaryFilter` function - applies canary percentage logic without modifying routing table
- EOD processing operates on `stype` field only (`hdbA` vs `hdbB`)

This allows:
- A canary deployment started Monday can continue through Tuesday's EOD cycle
- EOD restarts don't interfere with canary percentages
- Both mechanisms operate independently on the same routing table

### Multi-Host Log Synchronization

**Problem**: In distributed deployments, HDB servants on remote hosts need up-to-date tick logs before restarting. If Host B's tick log is 5 minutes behind, the new HDB partition will be missing recent data.

**Solution** (`tickdemo/tickdemo.q:43-48`):

```q
requestSync:{[]
  remotes: exec address from routingTable
    where (stype like "hdb*"), not address like "localhost*";
  remotes: {x!(count x)#0Ni} `$ ":",/:
    (distinct {(x?":")#x} each string remotes),\: ":5999";
  if[0=count remotes; :restart "A"];
  {remotes[x]:h: hopen 0N!x; (neg h) (`requestSync; 0); (neg h)[]}
    each key remotes;
}
```

**Flow**:

1. EOD trigger arrives at mserve
2. mserve sends `requestSync` message to launcher.q on each remote HDB host
3. Each launcher.q runs rsync to pull latest tick logs
4. Each launcher.q responds with `finishSync` message
5. Only after all responses arrive does mserve call `restart["A"]` or `restart["B"]`
6. Now HDB servants restart with complete, synchronized data

**Design Note**: RDB servants are NOT included in sync because they don't ingest logs at EOD - they ingest at startup from their initial launch.

### Date-Aware Routing During Transitions

**Problem**: A query arrives for data spanning "yesterday and today". HDB servants are currently restarting. Where should this query go?

**Solution**: Scripted dispatch with date-aware routing criteria (`tickdemo/tickdemo.q:4-12`):

```q
getRoutingCriteria:{[arg;opt]
  d:arg 1;
  if[null currentdate; '"rdb.q not ready"];
  / Route based on offset from current date
  if[(abs type d) within (6 7); :([loday:first d; hiday:last d])];
  if[14<>abs type d; :([hiday:0N; loday:0N])];
  ([loday:(first d)-currentdate; hiday:(last d)-currentdate])
}
```

**Routing Table Entry Example** (`tickdemo/nextdemo.csv`):

```csv
address,stype,sversion,condition,qfile
localhost:5001,rdb,1,(loday >= -2),rdb.q
localhost:5002,hdbA,1,(hiday <= -2)&(hiday > -220),hdb.q
localhost:5003,hdbB,1,(hiday <= -2)&(hiday > -160),hdb.q
```

**Logic**:

- Query for date range [2024-01-15, 2024-01-16], current date is 2024-01-17
- `loday = 2024-01-15 - 2024-01-17 = -2`
- `hiday = 2024-01-16 - 2024-01-17 = -1`
- Condition: `loday >= -2` evaluates TRUE → route to RDB
- RDB serves recent data, even if HDB is restarting

**Transition Handling**:

- If both RDB and HDB qualify, routing table order determines precedence (RDB first)
- If HDB handle is marked unavailable during restart, query waits or uses fallback servant
- When HDB restarts complete, their handles reconnect and routing resumes

### Implementation: servantMessage Handler

Servants send messages back to mserve for EOD coordination (`tickdemo/tickdemo.q:14-28`):

```q
servantMessage:{[id;cmd;arg]
  if[cmd~`initdate; currentdate::arg; :(::)];
  if[cmd~`endofday;
    if[null currentdate; currentdate::arg];
    if[nextdate<arg+1; nextdate::arg+1; requestSync[]; :(::)]
  ];
  if[cmd~`finishSync;
    hclose remotes[arg];
    remotes::remotes _ arg;
    if[0=count remotes; restart "A"];
    :(::)
  ];
  if[cmd~`hdbAready; if[0=0|restarting-::1; restart "B"]; :(::)];
  if[cmd~`hdbBready;
    if[0=0|restarting-::1;
      currentdate::nextdate;
      {x (`startofday; y)}[;currentdate] each
        where h2addr[;2] like "rdb.q *";
      / Clean up old log files (>2 days old)
      ls: @[system; "ls data/log/schema* 2>/dev/null"; ()];
      ls: ls where ("D"$ -10#/:ls)< -2+ currentdate;
      {system "mv ", x, " data/archive"} each ls;
    ]
  ];
}
```

**Message Flow**:

1. RDB sends `(endofday; date)` when flush completes
2. mserve calls `requestSync[]` to synchronize remote hosts
3. Remote launchers send `(finishSync; address)` when sync completes
4. mserve calls `restart["A"]` when all syncs complete
5. New hdbA servants send `(hdbAready; ::)` after startup
6. mserve calls `restart["B"]` when all hdbA ready
7. Process completes, both pools now have latest partition

**Result**: Complete EOD cycle with zero query downtime.

## 3. Canary Deployment for Zero-Downtime Updates

### The Canary Problem for 24/7 Systems

Bug fixes and feature updates can't wait for maintenance windows in 24/7 trading. Canary deployment (gradual rollout with automatic failback) is essential.

### Canary State Management

**Key Data Structures** (`examples/05scripted/scripted.q`):

```q
cn_phasein: boolean vector marking servants being phased in
cn_phaseout: boolean vector marking servants being phased out
cn_pct: current percentage (0-100) of queries routed to new servants
cn_inc: percentage increment per interval
cn_interval: time interval between increments
cn_maxerr: error threshold triggering automatic failback
```

### Canary Filter Function

**Core Logic**:

```q
canaryFilter:{[qid; route; handles]
  / If no canary active, return all handles
  if[null cn_pct; :handles];

  / Compute random value 0-99 for this query
  pct: mod[qid; 100];

  / If below threshold, prefer phase-in servants
  if[pct < cn_pct;
    preferred: handles where cn_phasein handles;
    if[count preferred; :preferred];
  ];

  / Otherwise prefer phase-out servants (or non-canary)
  preferred: handles where not cn_phasein handles;
  if[count preferred; :preferred];

  / Return all if no preference available
  :handles
}
```

**Integration with Match Dispatch**:

The match algorithm normally selects servants with matching route. Canary filter narrows this selection:

1. Match algorithm finds handles with route `IBM: [-13, -14, -17]
2. Canary filter applied: `-13` is phase-in, `-14` and `-17` are phase-out
3. If `cn_pct = 30`, query IDs 0-29 prefer `-13`, IDs 30-99 prefer `-14` or `-17`
4. First available handle from preferred set is selected

### Automatic Failback

**Error Detection** (`examples/05scripted/scripted.q`):

```q
filterResponse:{[qid; result; info]
  / Check if response is an error from phase-in servant
  if[not null cn_pct;
    hdl: queries[qid; `slave_handle];
    if[cn_phasein[hdl];
      if[-128h = type result;  / error type
        cn_errcnt+::1;
        if[cn_errcnt >= cn_maxerr;
          / Trigger failback
          cn_pct::0;
          cn_state::"hold at 0%";
          -2 "*****\n failover - hold at 0%\n*****";
        ];
      ];
    ];
  ];
  (result; info)
}
```

**Failback Flow**:

1. New servant (phase-in) returns error
2. Error count increments
3. When `cn_errcnt >= cn_maxerr` (e.g., 3 errors)
4. System sets `cn_pct := 0` immediately
5. All subsequent queries route to old servants (phase-out)
6. New servant remains connected but receives no queries
7. Administrator can investigate, fix, and retry or cancel

**Graceful Success**:

1. Canary starts at `cn_pct = 0`, increments by `cn_inc` every `cn_interval`
2. If no errors accumulate, `cn_pct` reaches 100
3. System holds at 100 for two intervals to confirm stability
4. If still no errors, canary state becomes "hold at 100%"
5. Administrator calls `finishPhaseIn[]` to remove old servants permanently

### Hot Editing API

**upgradeServers Function** (`examples/05scripted/edconfig.q`):

```q
upgradeServers:{[stype; criteria; settings; replaceflag]
  / Find all servants matching stype and criteria
  rows: select from editBuffer where stype=stype, ...;

  / For each matching servant
  {[row; settings; replace]
    newaddr: findUnusedPort[host row];      / allocate new port
    copyServer[newaddr; row; settings; replace];  / launch new servant
  }[; settings; replaceflag] each rows;

  / Changes applied via applyChanges with optional canary
}
```

**Example Usage**:

```q
/ Upgrade all "rdb" servants to new version with 25%/minute canary
upgradeServers[`rdb; ([]); ([qfile:`rdb_v2.q; sversion:2]); 1b]
applyChanges["25%"; "1m"]

/ If errors occur, automatic failback to old version
/ If successful, finalize:
finishPhaseIn[]
```

### Multi-Day Canary Support

**Why This Matters**: A canary deployment started Monday at 9am with increment "10%/hour" would complete after 10 hours at 7pm. But EOD processing happens at 5pm.

**Previous Behavior**: EOD restart would disrupt canary state, potentially breaking the rollout.

**Current Behavior** (commit 105b213):
- EOD processing restarts HDB servants using `stype` field
- Canary state (`cn_phasein`, `cn_phaseout`, `cn_pct`) remains unchanged
- After HDB restart, canary continues incrementing
- New servants and old servants both receive updated HDB partition
- Canary percentage continues to 100% over multiple days if needed

## 4. Locality-Aware Dispatch for Performance

### The Cache Warmth Problem

**Scenario**: 8 servants, 1000 symbols, queries arrive randomly distributed across symbols.

**Without Locality** (even dispatch):
- Each servant sees ~125 different symbols
- Each query may be first time this servant has seen this symbol
- Data must be loaded from disk or remote memory
- Cache hit rate: low

**With Locality** (match dispatch):
- Queries for `IBM` always route to servant #3
- Servant #3's cache fills with IBM-related data
- Subsequent IBM queries hit warm cache
- Cache hit rate: high

### Match Algorithm Implementation

**Core Function** (`components/match.q`):

```q
check:{
  / Step 1: Compute routing symbols for new queries
  update route: getRoutingSymbol each query from `queries where null route;

  / Step 2: Match warm servants
  / Find queries whose route matches a not-busy servant's h2route value
  matches: select from queries where
    route in exec h2route hdl from ([] hdl:key h) where 0=count each h hdl;

  if[count matches;
    qid: first matches `id;
    route: matches[0; `route];
    hdl: first exec hdl from ([] hdl:key h) where
      (h2route hdl)=route, 0=count h hdl;
    send_query[hdl; qid];
    :();
  ];

  / Step 3: Assign new routes to cold servants
  / Find queries with routes not held by ANY servant
  unrouted: select from queries where
    route in exec route from queries except exec h2route from ([] h2route:value h2route);

  / Find servants that are idle and have no route (or expired route)
  cold: exec hdl from ([] hdl:key h) where
    0=count each h hdl,
    (h2idle hdl) < .z.P - 0D00:05;  / 5 minute expiry

  if[(count unrouted) and count cold;
    qid: first unrouted `id;
    hdl: first cold;
    h2route[hdl]: unrouted[0; `route];
    send_query[hdl; qid];
    :();
  ];

  / Step 4: If queue not empty but no match, schedule timer check
  if[count select from queries where null time_sent;
    nextCheck:: .z.P + 0D00:00:00.100;  / check again in 100ms
  ];
}
```

**Key Data Structures**:

- `h2route[handle]` - routing symbol currently "owned" by this servant
- `h2idle[handle]` - timestamp when servant last completed a query
- Route expires after 5 minutes idle, allowing reassignment

**Performance Impact**:

Consider a query for VWAP on `IBM` requiring:
1. Read tick data from disk: 50ms (cold) vs 0ms (warm - in page cache)
2. Decompress data: 20ms (cold) vs 5ms (warm - already decompressed)
3. Filter to IBM rows: 10ms (cold) vs 2ms (warm - index cached)
4. Compute VWAP: 5ms

**Total**: 85ms (cold) vs 7ms (warm) = **12x improvement**

For systems processing 1000s of queries/second across 100s of symbols, this locality effect dominates load balancer overhead (~1.2ms).

### Routing String Customization

**Default Routing** (first argument):

```q
getRoutingSymbol:{[query]
  args: getArguments query;
  first args
}
```

**Date Range Routing** (useful for partitioned HDB):

```q
getRoutingSymbol:{[query]
  args: getArguments query;
  dates: args 1;  / assume second argument is date range
  `$string first dates
}
```

**Combined Routing**:

```q
getRoutingSymbol:{[query]
  args: getArguments query;
  sym: first args;
  dates: args 1;
  `$"_" sv string (sym; first dates)
}
```

This creates routing strings like `IBM_2024.01.15`, allowing queries for IBM on a specific date to route together.

## 5. Performance Characteristics

### Overhead Benchmarking

**Test Setup**:

- Echo query (returns argument immediately, no processing)
- 50 round trips per configuration
- Single client, 8 servants on localhost
- Measured: time_returned - time_received (includes queue time)

**Results**:

| System | Min (ms) | Avg (ms) | Max (ms) | Notes |
|--------|----------|----------|----------|-------|
| LBT (mserve + secure invocation) | 0.990 | 1.256 | 1.425 | This implementation |
| NP (original mserve) | 1.014 | 1.209 | 1.316 | Nathan Perrem's version |
| AW (Arthur's mserve) | 0.696 | 0.870 | 0.940 | Earlier implementation |
| SS (socket sharding) | 0.339 | 0.490 | 0.547 | Linux SO_REUSEPORT |
| Direct | ~0.200 | ~0.250 | ~0.300 | No load balancer |

**Analysis**:

1. **LBT overhead**: ~1.0ms additional latency vs direct connection
2. **LBT vs Socket Sharding**: 2.5x overhead, but provides routing/failover/security not available in SS
3. **LBT vs original mserve**: Comparable (slightly higher due to secure invocation parsing)

**When Overhead Matters**:

- Ultra-low-latency systems (<10ms target): consider socket sharding + application-level routing
- Typical trading systems (10-100ms queries): 1ms overhead is negligible (1-10% impact)
- Analytics systems (100ms-10s queries): overhead is insignificant

**When Locality Matters More**:

- Queries accessing large data sets (>10MB)
- Queries with complex processing (aggregations, joins)
- Systems with high query volume and many distinct routing keys
- In these cases, cache warmth gains (10-100ms) far exceed 1ms overhead

### Scalability Characteristics

**Servant Scaling**:

- Tested: 1-32 servants per mserve instance
- Overhead: constant (~1.2ms) regardless of servant count
- Bottleneck: single-threaded mserve dispatch loop

**Throughput Scaling**:

- Single mserve: ~1000 queries/second sustained
- Limitation: q is single-threaded, dispatch loop processes one query at a time
- Workaround: partition by symbol at client, route to multiple mserve instances
- Alternative: use socket sharding for servants, application-level routing for different server types

**Multi-Host Scaling**:

- Tested: servants distributed across 5 hosts
- Additional latency: network RTT (typically <1ms on datacenter network)
- No architectural limit on number of hosts

## 6. Security Framework

### Secure Invocation Architecture

**Threat Model**: Client sends query string `"proc1 `IBM"` to servant. Servant evaluates this string. Malicious client could send `"system \"rm -rf /\""` instead.

**Defense**: Restrict evaluation to predefined API functions only. Parse query without using `eval` or `value`.

**Implementation** (`components/secure_invocation.q`):

```q
.si.parse:{[querystr]
  / Parse string to AST without evaluation
  / Reject: nested function calls in arguments
  / Reject: use of 'value', 'eval', 'system'
  / Allow: .api.* function calls with literal arguments
  ...
}

.si.validate:{[query; options]
  ast: .si.parse query;

  / Extract function name
  fname: first ast;

  / Verify function is in .api namespace
  if[not fname like ".api.*";
    '"Only .api.* functions allowed"];

  / Verify function exists
  if[not fname in key `.api;
    '"Function not found"];

  / Return: (function; arguments)
  (value fname; 1_ ast)
}
```

**Servant Integration**:

```q
.z.ps:{[msg]
  (qid; querystr; opts): msg;

  / Parse and validate
  (func; args): .si.validate[querystr; opts];

  / Execute safely
  result: @[func; args; {`error; x}];

  / Return
  (qid; result)
}
```

**Key Properties**:

1. Only `.api.*` functions callable (whitelist approach)
2. No dynamic code evaluation in arguments
3. Parse errors caught before execution
4. Type checking on arguments possible

### Authentication/Authorization

**Architecture**: Authentication happens at mserve, authorization at servant.

**Rationale**:

- mserve sees all incoming connections, can enforce authentication once
- Servant sees API-level requests with role attached, enforces function-level permissions
- Sending role in cleartext from mserve to servant is acceptable (mserve is trusted)

**Implementation** (`examples/02quickauth/authent.q`):

```q
/ In mserve
getrole:{[options]
  / Extract user credentials from options dict
  user: options `user;
  pass: options `pass;

  / Validate against user database
  if[not (user; pass) in userdb; :`unauthorized];

  / Return role
  userdb[(user; pass); `role]
}

/ When forwarding query to servant, inject role
send_query:{[hdl; qid]
  query: queries[qid; `query];
  opts: queries[qid; `options];
  role: getrole opts;

  / Add role to options
  opts[`role]: role;

  / Forward
  (neg hdl) (qid; query; opts);
}
```

**Servant Authorization** (`examples/02quickauth/authriz.q`):

```q
/ In servant
allowedfn:{[role]
  / Return list of allowed functions for this role
  $[role=`trader; (`.api.getQuote; `.api.placeOrder);
    role=`analyst; (`.api.getQuote; `.api.getHistorical);
    role=`admin; key `.api;
    ()]  / default: no access
}

.si.validate:{[query; options]
  (func; args): .si.parse query;

  / Check authorization
  role: options `role;
  allowed: allowedfn role;
  if[not func in allowed; '"Not authorized"];

  (value func; args)
}
```

## 7. Deployment Considerations

### Hardware Sizing

**mserve Instance**:

- CPU: 2-4 cores (single-threaded, but OS overhead + network interrupts)
- RAM: 4GB minimum (query table history, routing table, connections)
- Network: 1Gbps sufficient for most workloads
- Disk: minimal (logs only)

**Servant Sizing**:

- Depends entirely on workload (data volume, query complexity)
- Typical RDB: 32-128GB RAM, 8-16 cores
- Typical HDB: 64-256GB RAM (for memory-mapped files), 16-32 cores

### Network Topology

**Recommended**:
```
                Load Balancer (HAProxy/F5)
                          |
                  ┌───────┴───────┐
                  |               |
              mserve-1         mserve-2
                  |               |
          ┌───────┴───────┐       └── (standby)
          |       |       |
        RDB-1   HDB-A1  HDB-B1
        RDB-2   HDB-A2  HDB-B2
```

**Rationale**:

- External load balancer provides mserve HA
- Multiple RDB instances for data redundancy
- HDB-A and HDB-B pools for double-buffered EOD
- Multiple servants per pool for query load distribution

### Monitoring

**Key Metrics**:

From `queries` table in mserve:
```q
/ Average queue time
select avg time_sent - time_received from queries

/ Average execution time
select avg time_returned - time_sent from queries

/ Backlog per query
select avg backlog from queries

/ Queries by servant
select count i by slave_handle from queries

/ Errors by servant
select count i by slave_handle from queries where -128h=type result
```

**Alerting Thresholds**:

- Backlog > 10: servants overloaded, add capacity
- Execution time increasing: servant performance degrading
- Error rate > 1%: investigate failing servants
- Routing imbalance: check dispatch algorithm

### Disaster Recovery

**mserve State**:

- Routing table: persistent in CSV file, reloaded on restart
- Query history: in-memory, lost on crash (acceptable for monitoring data)
- Canary state: lost on crash (must restart canary if interrupted)

**Recommendations**:

- Export routing table to CSV periodically: `saveConfiguration[]`
- Log canary actions to external system for audit trail
- Monitor mserve with external health check, auto-restart on failure
- Consider dual mserve instances with state replication (future enhancement)

**Servant State**:

- Servants are stateless (except in-memory data)
- RDB state can be recovered from tick logs
- HDB state is persistent on disk
- Servants can restart/relocate without data loss

## 8. Migration Path

### From Existing KDB System

**Phase 1: Introduce mserve** (no behavioral change)

1. Deploy mserve with single servant (existing RDB or HDB)
2. Point client queries to mserve instead of direct servant
3. Validate: queries work identically
4. Duration: 1 day

**Phase 2: Add Load Balancing** (scale servants)

1. Add 2-4 additional servants (same q-file)
2. Use "even" dispatch algorithm (no routing logic)
3. Validate: query load distributes across servants
4. Duration: 1 week

**Phase 3: Enable Locality** (performance optimization)

1. Switch to "match" dispatch algorithm
2. Customize `getRoutingSymbol` for your query patterns
3. Measure: cache hit rate, query latency improvement
4. Duration: 2 weeks

**Phase 4: Double-Buffered EOD** (24/7 readiness)

1. Split HDB servants into two pools (hdbA, hdbB)
2. Implement EOD coordination (servantMessage handlers)
3. Test: EOD cycle completes with zero downtime
4. Duration: 4 weeks

**Phase 5: Canary Deployment** (zero-downtime updates)

1. Implement hot editing functions
2. Test: upgrade single servant with canary
3. Test: automatic failback on error
4. Deploy: use for all future updates
5. Duration: 4 weeks

**Total Migration**: 12 weeks from start to full 24/7 capability

### Risk Mitigation

**Rollback Plan**:

- Keep direct connections to servants as fallback
- Test mserve in parallel before cutover
- Monitor error rates closely post-migration
- Document rollback procedure

**Testing Strategy**:

- Load test with realistic query volume
- Chaos test: kill random servants, verify failover
- EOD test: simulate full EOD cycle in staging
- Canary test: deploy broken servant, verify failback

## 9. Future Enhancements

### High-Availability mserve

**Current Limitation**: Single mserve instance is SPOF

**Proposed Solution**:

- Dual mserve instances with state replication
- Client connects to both, sends queries to primary
- On primary failure, seamless failover to secondary
- Requires: distributed consensus protocol (Raft/Paxos) for routing table

### Dynamic Servant Scaling

**Current Limitation**: Servant count is static

**Proposed Solution**:

- Monitor query backlog in mserve
- When backlog > threshold, launch additional servants
- When backlog < threshold, gracefully retire excess servants
- Requires: cloud API integration (AWS/GCP autoscaling)

### Query Queueing and Prioritization

**Current Limitation**: Queries processed FIFO

**Proposed Solution**:

- Priority levels in query options: `high`, `medium`, `low`
- High-priority queries skip queue
- Low-priority queries deferred when backlog high
- Requires: priority queue data structure in mserve

### Cross-Datacenter Routing

**Current Limitation**: All servants assumed low-latency network

**Proposed Solution**:

- Servants tagged with datacenter/region
- Client location detected by mserve
- Queries routed to nearest datacenter for latency
- Requires: GeoIP lookup, latency-aware dispatch algorithm

## 10. Conclusion

This architecture provides a comprehensive solution for operating KDB+ systems in 24/7 trading environments. The combination of:

1. **Double-buffered EOD processing** - eliminates maintenance windows
2. **Canary deployment** - enables zero-downtime updates
3. **Locality-aware dispatch** - maximizes cache efficiency
4. **Security framework** - prevents code injection
5. **Hot configuration** - allows runtime adaptation

...creates a production-ready platform for continuous trading operations.

The technology is proven (descended from First Derivatives' mserve), well-tested (complete example implementations), and performant (1-2ms overhead, cache gains far exceed this).

For organizations facing the 24/7 trading transition, this represents a lower-risk, faster-to-deploy alternative to in-house development.

## Appendix: Code References

All code references in this document point to:
- Repository: mserve (enhanced load balancing for KDB+)
- Base: Nathan Perrem's mserve_np
- Key files:

  - `mserve_np.q` - core load balancer
  - `tickdemo/tickdemo.q` - EOD orchestration
  - `examples/05scripted/scripted.q` - canary deployment
  - `examples/04dispatch/match.q` - locality dispatch
  - `components/secure_invocation.q` - security framework
