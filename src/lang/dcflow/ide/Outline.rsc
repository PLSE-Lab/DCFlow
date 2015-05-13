@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::ide::Outline

import lang::dcflow::\syntax::DCFlowSyntax;
import lang::dcflow::generate::GenerateUtils;
import lang::dcflow::\syntax::SyntaxUtils;
import lang::dcflow::ast::AbstractSyntax;

import ParseTree;
import util::IDE;
import List;
import Set;

data Node
	= outline(list[Node] nodes)
	| rules(list[Node] nodes)
	| ruleType(list[Node] nodes)
	| ruleDecl()
	| ignoreDecl()
	;
	
anno str Node@label;
anno loc Node@\loc;

public node outlineModule(Tree t) {
	if (t has top) return outlineModule(t.top);
	if (CModule m := t)
		return Node::outline([outlineRules(m.rules)])[@label="<m.name>"];
	else
		return Node::outline([])[@label="empty"];
}

public Node outlineRules(CRule* rules) {
	lrel[str,str,RuleArity,Node] ruleNodes = [ < tn, cn, ruleArity, ruleDecl()[@label="<cn>"][@\loc=r@\loc] > | 
		r:(CRule) `rule <CQualifiedNameWithArity+ targets> = <{CRulePart ","}+ parts> ;` <- rules,
		tgt <- targets, < tn, cn, ruleArity > := splitTarget(tgt) ];
	lrel[str,str,RuleArity,Node] ignoreNodes = [ < tn, cn, ruleArity, ignoreDecl()[@label="ignore: <cn>"][@\loc=r@\loc] > |
		r:(CRule) `ignore <CQualifiedNameWithArity+ targets> ;` <- rules,
		tgt <- targets, < tn, cn, ruleArity > := splitTarget(tgt) ];
	list[Node] ruleTypeNodes = [ ruleType([ rn | cn <- sort(toList(toSet(ruleNodes[tn]<0>) + toSet(ignoreNodes[tn]<0>))), rn <- (ruleNodes[tn,cn,_]+ignoreNodes[tn,cn,_])])[@label="<tn>"] | tn <- sort(toList(toSet(ruleNodes<0>))) ];
	return Node::rules(ruleTypeNodes)[@label="Rules"];
}

public Contribution createOutlinerContribution() = outliner(outlineModule);