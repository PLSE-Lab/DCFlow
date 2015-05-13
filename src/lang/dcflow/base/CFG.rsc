@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::base::CFG

import lang::dcflow::base::Label;
import lang::dcflow::base::FlowEdge;
import lang::dcflow::base::CFGExceptions;
import analysis::graphs::Graph;
import Set;

@doc{Representations of the control flow graph}
public data CFG 
	= cfg(loc item, map[Lab, CFGNode] nodes, FlowEdges edges, map[str id, CFGNode nd] labeledNodes)
	;

@doc{Control flow graph nodes}
data CFGNode
	= cfgNode(node n, Lab l)
	| headerNode(Lab l)
	| footerNode(Lab l)
	| linkNode(Lab l)
	| entryNode(Lab l)
	| exitNode(Lab l)
	;

@doc{Sets of control flow graph nodes.}
public alias CFGNodes = set[CFGNode];

@doc{Convert the CFG into a Rascal Graph, based on flow edge information}
public Graph[CFGNode] cfgAsGraph(CFG cfg) {
	return { < cfg.nodes[e.from], cfg.nodes[e.to] > | e <- cfg.edges };
}

@doc{Check to see if this CFG has an entry node.}
public bool hasEntryNode(CFG g) = ":entry" in g.labeledNodes;

@doc{Get the unique entry node for the CFG.}
public CFGNode getEntryNode(CFG g) {
	if (hasEntryNode(g)) return g.labeledNodes[":entry"];
	throw labeledNodeNotFound(":entry");
}

@doc{Check to see if this CFG has an exit node.}
public bool hasExitNode(CFG g) = ":exit" in g.labeledNodes;

@doc{Get the unique entry node for the CFG.}
public CFGNode getExitNode(CFG g) {
	if (hasExitNode(g)) return g.labeledNodes[":exit"];
	throw labeledNodeNotFound(":exit");
}
