/2019.06.17 ensure sym has g attr for schema returned to new subscriber
/2008.09.09 .k -> .q
/2006.05.08 add

\d .u

/Create global "w" as a dictionary which maps the name of each  
/table currently in memory (as a symbol) to a generic empty list  
/The value of each key  will be a list of pairs (a;b) where a is the handle
/for a subscriber process, and b is the list of symbols (ie. values in the 
/"sym" column) requested by that subscriber. 
init:{w::t!(count t::tables`.)#()} ;


/Remove the entry for table x and subscriber y  from the "w" data structure
/Note w[x;;] is the list of pairs (a;b) for table x where a is the handle and b is the list of symbols.
/So w[x;;0] is the list of handles. We find the position of the handle y in this list 
/and drop this position from the list of pairs, removing both the handle and list of symbols. 
del:{w[x]_:w[x;;0]?y} ; 


/Remove a subscriber from all tables upon disconnect
/Note: .z.pc runs with parameter x equal to the handle, after a connection has closed.
/Note also: 't' is a globlal containing the list of tables, set up in the 'init' function.
.z.pc:{del[;x] each t} ;


/Extract records from a specified table x for a specified set of symbols y
/When y is the null symbol, return the entire table x.
sel:{$[`~y;x;select from x where sym in y]} ;

/Publish
/pub[t;x]  t is the table name as a symbol, x is the data to be published.
/The inner function runs with the given values of t and x for each item of (w t).
/Recall (w t) is a list of pairs (a;b) where a is the handle and b is the list of symbols for a subscriber. 
/So the argument w in the inner function is actually only one such pair.
/The expression 'x:sel[x] w 1' filters the table x to include only rows with requested symbols.
/If the count of this result is not zero, an asynchronous message is sent to the handle,
/to invoke the function named "upd" on the subscriber with the specified table name and the filtered data.
pub:{[t;x]{[t;x;w]if[count x:sel[x]w 1;(neg first w)(`upd;t;x)]}[t;x]each w t} ;


/Add symbols to a new or existing subscription
/add[x;y] x is the table name, y is the list of symbols, subscriber handle is in z.w
/First 'i' is set to the position of the subscriber handle in the list of subscriptions for table x.
/When this is less than the count of that list, a subscription for this handle already exists.
/In that case 'amend' is used to update the list of symbols in this entry to be the union of the old and new lists. 
/Otherwise, append a new pair to the list of subscriptions for this table.
/Finally a return value is provided (which will only be sent when the request is synchronous).
/If the table is keyed, all rows with the requested symbols are returned.
/Otherwise an empty schema is returned with the "grouped" attribute added to the "sym" column. 
add:{$[(count w x)>i:w[x;;0]?.z.w;.[`.u.w;(x;i;1);union;y];w[x],:enlist(.z.w;y)];(x;$[99=type v:value x;sel[v]y;@[0#v;`sym;`g#]])} ;

/Create a new or replace an existing subscription
/sub[x;y] x is the table name, y is the list of symbols, subscriber handle is in z.w
/Note that 't' is a global containing the list of table names, set up in the "init" function above.
/If 'x' is the null symbol, subscribe to this set of symbols for each table name in t.
/If 'x' is not one of the table name in 't', throw an error.
/otherwize remove any previous subscription for this handle (z.w) from table x, and "add" the new one.
sub:{if[x~`;:sub[;y]each t];if[not x in t;'x];del[x].z.w;add[x;y]} ;


/Invoke end-of-day processing on each subscriber
/The parameter 'x'; will be the date of the day that has just ended.
/'w[;;0]' extracts the list of subscriber handles for each table from the global "w"
/and 'union/' converts this to the list of distinct subscribers.
/We send the command '.u.end x" to each subscriber, to invoke its end-of-day processing. 
end:{(neg union/[w[;;0]])@\:(`.u.end;x)} ;

