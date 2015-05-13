@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::base::CFGBase

import lang::dcflow::base::Label;
import lang::dcflow::base::LabelState;
import lang::dcflow::base::JumpTarget;

public default loc getItemLoc(node n) = |file:///tmp/noloc|;

@doc{Register that the given jump target, jt, corresponds to location jumpTo.}
public LabelState registerUnstructuredJumpTarget(LabelState ls, JumpTarget jt, Lab jumpTo) {
	ls.jumpTargets[jt] = jumpTo;
} 

@doc{Register that a structured jump of class targetType jumps to location l}
public LabelState registerStructuredJumpTarget(LabelState ls, JumpTarget jt, Lab l, str targetType) {
	return pushStackLabel(ls, targetType, jt, l);
} 

@doc{Unregister a structured jump of class targetType}
public LabelState removeStructuredJumpTarget(LabelState ls, str targetType) {
	return popStackLabel(ls, targetType);
}

@doc{Find all unstructured jump targets inside value v (a program, function, etc).}
public default map[JumpTarget targetName, Lab to] findUnstructuredJumpTargets(LabelState ls, value v) {
	return ( );
}

public default set[Lab] getTargetsForJump(LabelState ls, value v) = { };
public default set[Lab] getTargetsForJump(LabelState ls, str targetType, value v) = { };

public default set[Lab] getTargetsForJumpToTarget(LabelState ls, str targetType) = { };