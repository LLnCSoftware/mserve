/ Plugin used to ensure servants launched by mserve_np will terminate when disconnected.
/ In particular it allows you to shut down all the servants, just by killing mserve_np.
.z.po:{ .z.pc:{exit 0}; }

/ Additional code could be added to enhance security
/ .z.po:{ .z.pw:{0b}; .z.pc:{exit 0} }                          / ensure only a single connection, terminate when disconnected
/ .z.pw:{ mserve_ip_addr ~ "." sv string "h"$ 0x0 vs .z.a }     / ensure only connection to known ip address
