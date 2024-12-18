# 02quickauth

This example uses essentially the same client as in 01quickstart, but which accepts 
2 additional command line arguments for the username and password, which are 
added to the "hopen" command that connects to mserve\_np.q. 

The servant here has modifications which allow it to load and utilize the plugins
to optionally implement authentication, authorization, and exit on close.

## Demo1- Adding authentication and authorization

**start the server:** 

```
KDBQ\_PLUGINS="authent.q"  q mserve\_np.q 1 servant.q -p 5000
```

When the mserve\_np.q loads the "authent.q" plugin to do authentication, it will automatically 
add the "authriz.q" plugin to the servant to do authorization.

Currently you have to use these names because they are hard coded in mserve\_np.q for that purpose.

**Start the client with no username or password:** 

```
q qs.q localhost 5000    
q qs.q localhost 5000 ken wrongpassword
```

You will get an 'access error. Same will happen for invalid passwords.  

**Start the client as an ordinary user:**  

```
q qs.q localhost 5000 ken ken
``` 

You will be able to run "proc1", but "proc2" will give you an "unknown command" error.

**Start the client as a power user:**  

```
q qs.q localhost 5000 arthur arthur
```

You will be able to run both "proc1" and "proc2"

## Demo2 - Running without the load balancer

Note that in each case below the servant will stay up when the client disconnects.
Thats because the "exitOnClose" plugin is omitted ! 

**Start the servant with auth/auth:** 

```
 KDBQ\_PLUGINS="authent.q,authriz.q"  q servant.q -p 5001
```

* q qs.q localhost 5001  -> no credentials 'access error
* q qs.q localhost 5001 ken ken -> ordinary user, proc1 only.
* q qs.q localhost 5001 arthur arthur -> power user, both proc1 and proc2.

**Start the sevant with authentication only:** 

```
KDBQ\_PLUGINS="authent.q"  q servant.q -p 5001
```

* q qs.q localhost 5001 -> no credentials 'access error
* q.qs.q localhost 5001 dan dan -> ordinary user can run both proc1 and proc2 (no authorization)

**Start the servant with no plugins:** q servant.q -p 5001

* q qs.q localhost 5001 -> can run both proc1 and proc2


## The client qs.q

The only change from 01quickstart is accepting the username and password
from the command line and adding them to the hopen command.

## The servant servant.q

(more to come)

