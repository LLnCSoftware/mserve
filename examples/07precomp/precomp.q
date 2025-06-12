\l ../../../precomp/data/preComp.q

routingDescriptor:([symbol:`GS`AAPL`BA`VOD`MSFT`GOOG`IBM`UBS]);

requestContextSource:{[conditions; valuesByDimension] receiveContextSource preComp[0N!conditions; 0N!valuesByDimension]} ;
/receiveContextSource:{myContextSource:: x; show myContextSource}

contextValues:{[variables; contextSource]; getBitVector[variables; contextSource]} ;

