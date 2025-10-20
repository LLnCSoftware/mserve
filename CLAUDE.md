# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**mserve** is an enhanced load-balanced solution for kdb+/q that distributes client queries across multiple servant processes. It extends Nathan Perrem's original mserve_np implementation with:

- Multi-host servant deployment
- Pluggable dispatch algorithms for improved data locality
- Secure invocation framework to prevent code injection
- Benchmarking and performance monitoring

**Language**: kdb+/q (a time-series database and programming language)

## Running mserve

### Basic Usage

Start mserve with servants on localhost:
```bash
q mserve_np.q <num_servants> <servant_script> -p <port>
```

Example with 5 servants:
```bash
q mserve_np.q 5 servant.q -p 5000
```

### Multi-Host Deployment

To distribute servants across multiple hosts:
```bash
q mserve_np.q <num_servants> <servant_script> -p <port> host1 host2 host3
```

Servants will be round-robined across the specified hosts.

### Environment Variables

- `MSERVE_ALGO` - Select dispatch algorithm: `orig`, `even`, or `match` (default: `match`)
  - `orig`: Always select first free servant
  - `even`: Distribute load evenly across all servants
  - `match`: Route queries with same routing string to same servant (for cache warmth)

- `MSERVE_ROUTING` - Custom function definition for computing routing strings (used by `match` algorithm)

- `MSERVE_PLUGINS` - Comma-separated list of plugin q-files to load into mserve

- `Q_PLUGINS` - Comma-separated list of plugin q-files to load into servants

- `Q_SERVANTOF` - IP address of allowed connection (restricts servants to only accept connections from mserve)

## Examples Directory Structure

Examples are ordered for progressive learning:

1. **01quickstart** - Basic client-servant-mserve interaction (insecure, for learning only)
2. **02quickauth** - Introduces secure_invocation, plugins, authentication/authorization
3. **03multihost** - Servants distributed across multiple remote hosts
4. **04dispatch** - Custom dispatch algorithms and routing strategies
5. **05scripted** - CSV-based servant configuration for heterogeneous deployments
6. **06admincli** - Admin CLI for runtime configuration changes
7. **07precomp** - Pre-computation patterns for performance optimization

Each example directory contains its own README markdown file with detailed instructions.

## Core Components

### mserve_np.q

The main load balancer. Key data structures:

- `queries` table - Tracks all queries with timing, routing, and servant assignment
- `h` dictionary - Maps servant handles to lists of active query IDs
- `h2addr` - Maps handles to address tuples (host, port, script)
- `h2route` - Maps handles to routing strings for cache affinity

Key functions:
- `send_query[hdl; qid]` - Forwards query to selected servant
- `.z.ps` - Async message handler for incoming client requests
- `check[qid]` - Dispatch algorithm (selects servant for query)

### components/secure_invocation.q

Security toolkit that restricts execution to predefined API functions:

- `.si.validate[query; options]` - Validates query allows only `.api.*` functions, rejects nested evaluation
- `.si.parse` - Parses query strings without using eval
- `validateAndRunSync` - Use as `.z.pg` for synchronous API
- `validateAndRunAsync` - Use as `.z.ps` for asynchronous API

### components/util.q

Common utilities for string conversion, timestamp handling, IP address formatting.

### components/qeServant.q

Template servant implementation with:
- Exit-on-close behavior (`.z.pc:{exit 0}`)
- Secure invocation integration
- Plugin loading via `Q_PLUGINS`
- Standard `.z.ps`/`.z.pg` handlers

## Plugin Architecture

Plugins extend mserve or servant functionality without modifying core code.

### Loading Plugins

Specify plugins as comma-separated environment variable:

```bash
MSERVE_PLUGINS="plugin1.q,plugin2.q" q mserve_np.q 5 servant.q -p 5000
```

For servants:
```bash
Q_PLUGINS="authent.q,authriz.q" q servant.q -p 5001
```

### Plugin Types

**Dispatch Algorithms**: Override the `check` function to implement custom servant selection logic.

**Authentication**: Override `getrole[options]` to extract user role from request options.

**Authorization**: Override `allowedfn[role]` to return a function that filters allowed API functions by role.

See examples/04dispatch for dispatch plugins, examples/02quickauth for auth/authz plugins.

## Servant Development

### API Function Conventions

All API functions must be defined in the `.api` namespace:

```q
.api.myfunction:{[arg1; arg2]
  / implementation
 };
```

### Calling Conventions

**Asynchronous (recommended)**:
- Request: `(query_id; query_string_or_parsed_expr; options_dict)`
- Response: `(query_id; result)`

**Synchronous**:
- Request: `query_string_or_parsed_expr` or `(query_string_or_parsed_expr; options_dict)`
- Response: `result`

### Security Requirements

When using secure_invocation:
- Only `.api.*` functions can be called
- No function evaluation allowed in arguments (prevents code injection)
- Parse all query strings with `.si.parse` instead of `parse` to avoid eval

## Benchmarking

The queries table in mserve_np.q tracks timing metrics:

- `time_received` - Query arrival timestamp
- `time_sent` - Forwarded to servant timestamp
- `time_returned` - Response received timestamp
- `backlog` - Number of queries ahead in queue when received

Calculate overhead:
- Elapsed time: `time_returned - time_received` (includes queue time)
- Execution time: `time_returned - time_sent` (excludes queue time)

## launchQ.q Utility

Helper for launching q processes with environment variables and directory resolution:

```q
launchQ[base_path; env_vars; command_string]
```

Command string format: `(ENV_VARS) path/to/script.q arguments`

The utility:
- Parses environment settings from parentheses
- Resolves relative paths (`~/`, `../`, `./`) against base path
- Changes to script directory before launch
- Injects absolute q interpreter path

## Testing

From any example directory:

```bash
# Terminal 1: Start mserve
q mserve_np.q 3 servant.q -p 5000

# Terminal 2: Start client
q qs.q localhost 5000

# In client REPL:
send "proc1 `IBM"           / Single query
\t 3000                     / Timer mode - query every 3 seconds
```

## Common Patterns

### Custom Dispatch Based on Query Analysis

Override `getRoutingSymbol` to extract routing key from parsed query:

```q
getRoutingSymbol:{[query]
  / extract relevant field from query
  / return as symbol for servant affinity
 };
```

### Adding Query Options

Extend the calling convention to pass options (role, priority, timeout):

```q
/ Client sends:
(query_id; query_expr; `role`timeout!(user_role; 5000))

/ Servant validates:
.si.validate[query_expr; options]
```

### Heterogeneous Servants

Use scripted dispatch (example 05scripted) with CSV configuration:

```csv
host,port,script,data_partition
server1,5001,servant_rdb.q,recent
server2,5002,servant_hdb.q,historical
```

Dispatch algorithm routes based on query date range to appropriate servant type.
