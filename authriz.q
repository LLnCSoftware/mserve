/Plugin designed to be used by the servant to determine if the user is allowed to access a function.

roles: ("S*"; enlist "|") 0: `:roles.csv  ; / load role information into roles table
roles: (roles `role)!(`$ "," vs/: roles `fn) ; / convert to dictionary mapping roles to a list of functions
allowedfn:{ (roles x)# value `. } ; / get list of functions allowed for a given role


