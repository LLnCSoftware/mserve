
# Introduction: Enhanced Load Balancer for kdb/q

Welcome to the enhanced load balancer for kdb/q, based on [mserve_np](https://github.com/nperrem/mserve) and inspired by the [Load Balancing Cookbook](https://code.kx.com/trac/wiki/Cookbook/LoadBalancing). This tool provides advanced query distribution, multi-host support, secure invocation, and benchmarking capabilities to optimize performance in distributed environments.

This documentation is designed to serve:
- **Experienced kdb/q professionals**: Learn how this tool extends standard load balancing practices.
- **New users**: Step-by-step examples guide you through setup, security, and multi-host configurations.

## Examples and Key Features

1. **[Quickstart: Basic Single-Host Setup](#)**  
   Start with a simple configuration to understand the client, load balancer, and servant interaction.

2. **[Quick Authentication and Authorization](#)**  
   Secure your system using plugins for user authentication and role-based access control.

3. **[Multi-Host Configuration](#)**  
   Scale your setup across multiple machines with distributed servants and query routing.

4. **[MServe Overview and Glossary](#)**  
   Understand key features like routing strings, dispatch algorithms, and secure invocation. Includes a sequence diagram to visualize query flow.

## Additional Resources

- **Glossary**: Definitions of key terms like "servant," "dispatch algorithm," and "secure invocation."  
- **File Overview**: A breakdown of source files and their roles in the system.  
- **Performance Insights**: Tools to benchmark and monitor query handling across servants.

Dive into the examples to get started or explore the glossary for in-depth understanding of core concepts!
