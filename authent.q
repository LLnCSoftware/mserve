users: ("JS*S"; enlist "|") 0: `:users.csv ;
getrole:{ exec first role from users where username=.z.u };
.z.pw:{[u;pw] ps:exec first password from users where username=u; ps~raze string -33!pw };
