/ General example plugin for authentication for use either by a servant (when 
/ not being load balanced) or by a load balancer 
/ mserve.q itself. This is a simple example that uses a CSV file for user information. 

users: ("JS*S"; enlist "|") 0: `:users.csv ; / load user information
getrole:{ exec first role from users where username=.z.u }; / get role for user of current request 
/ check password on connection open
.z.pw:{[u;pw] ps:exec first password from users where username=u; ps~raze string -33!pw }; 
