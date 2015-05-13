@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::\syntax::SyntaxUtils

import lang::dcflow::\syntax::DCFlowSyntax;
import lang::dcflow::ast::AbstractSyntax;

import List;
import String;

private tuple[str,str] splitTargetInternal((CQualifiedName) `<{CName "::"}+ names>`) {
	nparts = [ "<n>" | n <- names ];
	if (size(nparts) < 2) throw "Invalid name for type/constructor";

	// Remove escape character at the start, if it has one
	nparts = [ removeStartingSlash(n) | n <- nparts ];
	
	return < intercalate("::",nparts[..-1]), nparts[-1] >;	
}

@doc{Split the target qualified name into the constructor name (the last part) and the type name (all but the last part) with optional arity}
public tuple[str,str,RuleArity] splitTarget((CQualifiedNameWithArity) `<CQualifiedName qn>`) {
	< tn, cn > = splitTargetInternal(qn);
	return < tn, cn, empty() >;
}

public tuple[str,str,RuleArity] splitTarget((CQualifiedNameWithArity) `<CQualifiedName qn> / <NaturalNumber nn>`) {
	< tn, cn > = splitTargetInternal(qn);
	return < tn, cn, numeric(toInt("<nn>")) >;
}

public tuple[str,str,RuleArity] splitTarget((CQualifiedNameWithArity) `<CQualifiedName qn> { <{CName ","}+ names> }`) {
	< tn, cn > = splitTargetInternal(qn);
	return < tn, cn, fieldNames([ removeStartingSlash("<ni>") | ni <- names ]) >;
}

public str removeStartingSlash(str s) {
	if (s[0] == "\\") {
		return s[1..];
	} else {
		return s;
	}
}

