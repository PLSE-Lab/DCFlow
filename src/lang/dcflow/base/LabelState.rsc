@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::base::LabelState

import lang::dcflow::base::CFG;
import lang::dcflow::base::Label;
import lang::dcflow::base::FlowEdge;
import lang::dcflow::base::JumpTarget;
import List;
import Node;

// TODO: This doesn't handle nested contexts of the same context type,
// we probably need a user-defined function per language to properly
// handle this...

@doc{The labeling state keeps track of information needed during the labeling and edge computation operations.}
data LabelState 
	= lstate(int counter,
	         map[Lab l, CFGNode n] cfgNodes, 
			 tuple[str tn, str cn] context, 
			 map[str id, CFGNode nd] labeledNodes, 
			 map[str id, lrel[JumpTarget targetName, Lab to] jumpStack] labeledStacks, 
			 map[Lab from, Lab to] headerNodes, 
			 map[Lab from, Lab to] footerNodes, 
			 map[Lab from, Lab to] linkNodes,
			 map[JumpTarget targetName, Lab to] jumpTargets,
			 rel[Lab,EdgeLabel,EdgeLabel] patchLabels) 
	;

@doc{Initialize the label state}	
public LabelState newLabelState() = lstate(0, ( ), <"","">, ( ), ( ), ( ), ( ), ( ), ( ), { });

@doc{Discard everything but the counter.}
public LabelState resetLabelState(LabelState ls) {
	return newLabelState()[counter=ls.counter][cfgNodes=ls.cfgNodes];
}

@doc{Expand the label state to include entry and exit information.}
public LabelState addEntryExitNodes(LabelState ls, CFGNode entryNode, CFGNode exitNode) {
	ls.labeledNodes[":entry"] = entryNode;
	ls.labeledNodes[":exit"] = exitNode;
	return ls;
}

@doc{Check to see if we have an entry node in the state.}
public bool hasEntryNode(LabelState ls) = ":entry" in ls.labeledNodes;

@doc{Get the current entry node}
public CFGNode getEntryNode(LabelState ls) = ls.labeledNodes[":entry"];

@doc{Get the label of the current entry node}
public Lab getEntryNodeLabel(LabelState ls) = ls.labeledNodes[":entry"]@lab;

@doc{Check to see if we have an exit node in the state.}
public bool hasExitNode(LabelState ls) = ":exit" in ls.labeledNodes;

@doc{Get the current exit node}
public CFGNode getExitNode(LabelState ls) = ls.labeledNodes[":exit"];

@doc{Get the label of the current exit node}
public Lab getExitNodeLabel(LabelState ls) = ls.labeledNodes[":exit"]@lab;

@doc{Check to see if the given labeled stack exists.}
public bool stackLabelExists(LabelState ls, str stackLabel) = stackLabel in ls.labeledStacks;

@doc{Get the given label stack.}
public list[Lab] getStackLabels(LabelState ls, str stackLabel) = ls.labeledStacks[stackLabel]<1>;

@doc{Check to see if the nth entry of a given label stack is available.}
public bool hasNthStackLabel(LabelState ls, str stackLabel, int n) = stackLabel in ls.labeledStacks && size(ls.labeledStacks[stackLabel]) <= n;

@doc{Get the nth entry of a given label stack (for, e.g., break 5), where 1 is the first element in the stack (not 0!)}
public Lab getNthStackLabel(LabelState ls, str stackLabel, int n) = getStackLabels(ls, stackLabel)[n-1];

@doc{Push a new label onto the named stack}
public LabelState pushStackLabel(LabelState ls, str stackLabel, JumpTarget jt, Lab l) {
	if (stackLabel in ls.labeledStacks) {
		ls.labeledStacks[stackLabel] = push(< jt, l >, ls.labeledStacks[stackLabel]);
	} else {
		ls.labeledStacks[stackLabel] = [ < jt, l > ];
	}
	return ls;
} 

@doc{Pop a label off the named stack}
public LabelState popStackLabel(LabelState ls, str stackLabel) {
	if (stackLabel in ls.labeledStacks && !isEmpty(ls.labeledStacks[stackLabel])) {
		if (size(ls.labeledStacks[stackLabel]) == 1)
			ls.labeledStacks[stackLabel] = [ ];
		else
			ls.labeledStacks[stackLabel] = ls.labeledStacks[stackLabel][1..];
	}
	return ls;
} 

public LabelState addPatchLabels(LabelState ls, Lab fromLabel, EdgeLabel toAdd, EdgeLabel blockers...) {
	ls.patchLabels = ls.patchLabels + { < fromLabel, toAdd, b > | b <- blockers };
	return ls;
}
