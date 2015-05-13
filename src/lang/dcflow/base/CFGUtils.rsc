@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::base::CFGUtils

import lang::dcflow::base::CFG;
import lang::dcflow::base::Label;
import lang::dcflow::base::LabelState;
import lang::dcflow::base::FlowEdge;

import List;
import Set;
import Node;
import IO;

@doc{Base version of entry function.}
public default Lab entry(node n, LabelState ls) {
	list[Lab] labels = [ l | l:lab(_) <- getChildren(n) ];
	if (size(labels) == 1) {
		if (labels[0] in ls.headerNodes) {
			return ls.headerNodes[labels[0]];
		}
		return labels[0];
	}
	return nothing();
}

@doc{Base version of exit function.}
public default set[Lab] exit(node n, LabelState ls) {
	list[Lab] labels = [ l | l:lab(_) <- getChildren(n) ];
	if (size(labels) == 1) {
		if (labels[0] in ls.footerNodes) {
			return { ls.footerNodes[labels[0]] };
		}
		return { labels[0] };
	}
	return { };
}

@doc{Compute the entry of a list}
public default Lab entry(list[&T <: node] ns, LabelState ls) {
	if (!isEmpty(ns)) {
		res = entry(ns[0], ls);
		if (res is nothing)
			return entry(tail(ns), ls);
		else
			return res;
	} else {
		return nothing();
	}	
}

@doc{Compute exit over lists.}
public default set[Lab] exit(list[&T <: node] ns, LabelState ls) {
	if (!isEmpty(ns)) {
		res = exit(ns[-1], ls);
		if (!isEmpty(res))
			return res;
		else
			return exit(ns[..-1], ls);
	} else {
		return { };
	}	
}

@doc{Base version of internalFlow function.}
public default tuple[FlowEdges,LabelState] internalFlow(node n, LabelState ls) = < { }, ls >;

@doc{Add edges for a given individual item}
public tuple[FlowEdges, LabelState] addEdges(FlowEdges edges, LabelState ls, &T <: node v) {
	< newEdges, ls > = internalFlow(v, ls);
	return < edges + newEdges, ls >;
}

public tuple[FlowEdges, LabelState] internalFlow(str v, LabelState ls) {
	println("Got here with a string");
	return < {}, ls >;
}

@doc{Add edges between items given as a sequence in a list.}
public tuple[FlowEdges, LabelState] addSeqEdges(FlowEdges edges, LabelState ls, list[&T <: node] vs) {
	for ([_*,v1,v2,_*] := vs) {
		< edges, ls > = linkItems(edges, ls, v1, v2);
	}
	return < edges, ls >;
}

public default tuple[FlowEdges, LabelState] linkItems(FlowEdges edges, LabelState ls, &T <: node v1, &U <: node v2, EdgeLabel edgeLabels...) {
	edges += { flowEdge(f, i, toSet(edgeLabels)) | i := entry(v2, ls), nothing() !:= i, f <- exit(v1, ls) };
	return < edges, ls >;
}

public tuple[FlowEdges, LabelState] linkItems(FlowEdges edges, LabelState ls, list[&T <: node] v1, &U <: node v2, EdgeLabel edgeLabels...) {
	edges += { flowEdge(f, i, toSet(edgeLabels)) | i := entry(v2, ls), nothing() !:= i, f <- exit(v1, ls) };
	return < edges, ls >;
}

public tuple[FlowEdges, LabelState] linkItems(FlowEdges edges, LabelState ls, &T <: node v1, list[&U <: node] v2, EdgeLabel edgeLabels...) {
	edges += { flowEdge(f, i, toSet(edgeLabels)) | i := entry(v2, ls), nothing() !:= i, f <- exit(v1, ls) };
	return < edges, ls >;
}

public tuple[FlowEdges, LabelState] linkItems(FlowEdges edges, LabelState ls, list[&T <: node] v1, list[&U <: node] v2, EdgeLabel edgeLabels...) {
	edges += { flowEdge(f, i, toSet(edgeLabels)) | i := entry(v2, ls), nothing() !:= i, f <- exit(v1, ls) };
	return < edges, ls >;
}

public tuple[FlowEdges, LabelState] linkItemsLabelLabel(FlowEdges edges, LabelState ls, Lab l1, Lab l2, EdgeLabel edgeLabels...) {
	edges += flowEdge(l1, l2, toSet(edgeLabels)) ;
	return < edges, ls >;
}

public tuple[FlowEdges, LabelState] linkItemsNodeLabel(FlowEdges edges, LabelState ls, &T <: node v1, Lab l, EdgeLabel edgeLabels...) {
	edges += { flowEdge(f, l, toSet(edgeLabels)) | f <- exit(v1, ls) };
	return < edges, ls >;
}

public tuple[FlowEdges, LabelState] linkItemsLabelNode(FlowEdges edges, LabelState ls, Lab l, &T <: node v2, EdgeLabel edgeLabels...) {
	edges += { flowEdge(l, i, toSet(edgeLabels)) | i := entry(v2, ls), nothing() !:= i };
	return < edges, ls >;
}

public tuple[FlowEdges, LabelState] linkItemsNodeLabel(FlowEdges edges, LabelState ls, list[&T <: node] v1, Lab l, EdgeLabel edgeLabels...) {
	edges += { flowEdge(f, l, toSet(edgeLabels)) | f <- exit(v1, ls) };
	return < edges, ls >;
}

public tuple[FlowEdges, LabelState] linkItemsLabelNode(FlowEdges edges, LabelState ls, Lab l, list[&T <: node] v2, EdgeLabel edgeLabels...) {
	edges += { flowEdge(l, i, toSet(edgeLabels)) | i := entry(v2, ls), nothing() !:= i };
	return < edges, ls >;
}

public tuple[FlowEdges, LabelState] removeLinks(FlowEdges edges, LabelState ls) {
	// We inserted link nodes to "hold" where we will link to following; find what is
	// reachable from those nodes
	linkNodes = ls.linkNodes<1>;
	reachableFromLink = { < f, t, el > | flowEdge(f,t,el) <- edges, f in linkNodes };
	heads = reachableFromLink<0>;
	
	// Find the edges to remove; these will be the edges coming into, or out of, these
	// link nodes. 
	toRemove1 = { fe | fe:flowEdge(f,t,el) <- edges, t in heads };
	toRemove2 = { fe | fe:flowEdge(f,t,el) <- edges, f in heads };
	
	// Create the edges to add; these will replace the edges we are removing with edges
	// directly from the nodes that went to the link to the nodes reachable from the link.
	toAdd = { flowEdge(f, t2, el1+el2) | fe:flowEdge(f, t1, el1) <- toRemove1, <t2,el2> <- reachableFromLink[t1] };
	
	return < edges - (toRemove1 + toRemove2) + toAdd, ls >;
}

public tuple[CFGNode, LabelState] createHeader(LabelState ls) {
	ls.counter = ls.counter + 1;
	Lab l = lab(ls.counter);
	newNode = headerNode(l);
	ls.cfgNodes[l] = newNode;
	return < newNode, ls >;
}

public tuple[CFGNode, LabelState] createFooter(LabelState ls) {
	ls.counter = ls.counter + 1;
	Lab l = lab(ls.counter);
	newNode = footerNode(l);
	ls.cfgNodes[l] = newNode;
	return < newNode, ls >;
}

public tuple[CFGNode, LabelState] createLink(LabelState ls) {
	ls.counter = ls.counter + 1;
	Lab l = lab(ls.counter);
	newNode = linkNode(l);
	ls.cfgNodes[l] = newNode;
	return < newNode, ls >;
}

public tuple[CFGNode, LabelState] createEntry(LabelState ls) {
	ls.counter = ls.counter + 1;
	Lab l = lab(ls.counter);
	newNode = entryNode(l);
	ls.cfgNodes[l] = newNode;
	return < newNode, ls >;
}

public tuple[CFGNode, LabelState] createExit(LabelState ls) {
	ls.counter = ls.counter + 1;
	Lab l = lab(ls.counter);
	newNode = exitNode(l);
	ls.cfgNodes[l] = newNode;
	return < newNode, ls >;
}

public map[Lab,CFGNode] deriveNodeMap(LabelState ls, FlowEdges es) {
	return ( l : ls.cfgNodes[l] | l <- ({ e.from | e <- es } + { e.to | e <- es }), nothing() !:= l);
}

public FlowEdges consolidateEdges(FlowEdges edges) {
	while ( {x*,fe1:flowEdge(f,t,el1),fe2:flowEdge(f,t,el2)} := edges ) {
		edges = {*x, flowEdge(f,t,el1+el2) };
	}
	return edges;
}

public FlowEdges addMissingEdgeLabels(LabelState ls, FlowEdges es) {
	for (l2p <- ls.patchLabels<0>) {
		edgesFrom = { e | e <- es, e.from == l2p };
		labelsUsed = { *e.edgeLabels | e <- edgesFrom };
		for (e <- edgesFrom) {
			es = es - e;
			startingEdgeLabels = e.edgeLabels;
			for (cl <- ls.patchLabels[l2p]<0>, cl notin labelsUsed, cl notin startingEdgeLabels, isEmpty(ls.patchLabels[l2p,cl] & startingEdgeLabels)) {
				e.edgeLabels = e.edgeLabels + cl;
			}
			es = es + e;
		}
	}
	
	return es;
}

public FlowEdges removeImpossibleEdges(FlowEdges es) {
	// Find jump edges -- they are unconditional, so we remove non-jump
	// edges from the same source
	jumpEdges = { e | e <- es, jump() in e.edgeLabels };
	jumpSources = { e.from | e <- jumpEdges };
	edgesToRemove = { e | e <- es, e.from in jumpSources, e notin jumpEdges };
	
	return es - edgesToRemove;
}

public set[Lab] pred(CFG cfg, Lab l) {
	return { e.from | e <- cfg.edges, e.to == l };
}

public set[Lab] succ(CFG cfg, Lab l) {
	return { e.to | e <- cfg.edges, e.from == l };
}