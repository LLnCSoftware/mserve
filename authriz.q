roles: ("S*"; enlist "|") 0: `:roles.csv  ;
roles: (roles `role)!(`$ "," vs/: roles `fn) ;
allowedfn:{ (roles x)# value `. }
