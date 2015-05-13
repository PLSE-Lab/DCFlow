@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::base::FlowEdge

import lang::dcflow::base::Label;
import List;

@doc{Info that can be put on as labels of a flow edge.}
data EdgeLabel
	= backedge()
	| conditionTrue()
	| conditionFalse()
	| jump()
	;

@doc{A flow edge records the flow from one label to the next.}
data FlowEdge = flowEdge(Lab from, Lab to, set[EdgeLabel] edgeLabels);

@doc{Sets of flow edges.}
alias FlowEdges = set[FlowEdge];

