@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::util::C2A

import lang::dcflow::\syntax::DCFlowSyntax;
import lang::dcflow::ast::AbstractSyntax;
import lang::dcflow::\syntax::SyntaxUtils;
import ParseTree;
import List;
import IO;

@doc{Convert the DCFlow program at location l into an AST}
public Program buildAST(loc l) {
	return buildAST(parse(#start[CModule],l));
}

@doc{Convert the DCFlow program in Tree pt into an AST}
public Program buildAST(Tree pt) {
	if (pt has top && CModule cm := pt.top) {
		return buildModule(cm);
	} else if (CModule cm := pt) {
		return buildModule(cm);
	} else {
		throw "Invalid module provided";
	}
}

@doc{Convert a concrete module into a program.}
public Program buildModule((CModule)`module <CQualifiedName name> <CImport* imports> <CRule* rules>`) {
	list[str] importedModules = [ ];
	for ((CImport)`import <CQualifiedName iname> ;` <- imports) {
		importedModules = importedModules + "<iname>";
	}

	list[str] astSources = [ ];
	for ((CImport)`ast <CQualifiedName iname> ;` <- imports) {
		astSources = astSources + "<iname>";
	}
	
	lrel[str tn,str cn,RuleArity arity] contextNames = [ ]; 
	for ((CRule)`context <CQualifiedNameWithArity+ cnames> ;` <- rules) {
		for (cn <- cnames) {
			< tname, cname, arity > = splitTarget(cn);
			contextNames = contextNames + < tname, cname, arity >;
		}
	}

	list[str] typeNames = [ ];
	for ((CRule)`astType <CQualifiedName tname> ;` <- rules) {
		typeNames = typeNames + "<tname>";
	}
	
	if (size(typeNames) == 0 && size(contextNames) > 0) {
		typeNames = contextNames[0..1].tn;
	} else if (size(typeNames) == 0 && size(contextNames) == 0) {
		throw "You must provide at least one context name";
	} else if (size(typeNames) > 1) {
		throw "Only one AST type name may be provided.";
	}
		
	list[Rule] ruleList = [ ];
	for (r <- rules, r is \default) {
		ruleList = ruleList + buildRule(r);
	}

	set[str] stargetSet = { };
	for ((CRule)`structured target <CQualifiedName+ cnames> ;` <- rules) {
		stargetSet = stargetSet + { "<cn>" | cn <- cnames };
	}
	stargetSet = { ":" + removeStartingSlash(cn) | cn <- stargetSet };
	
	set[str] utargetSet = { };
	for ((CRule)`unstructured target <CQualifiedName+ cnames> ;` <- rules) {
		utargetSet = utargetSet + { "<cn>" | cn <- cnames };
	}
	utargetSet = { ":" + removeStartingSlash(cn) | cn <- utargetSet };

	lrel[str tn,str cn,RuleArity arity] ignores = [ ]; 
	for ((CRule)`ignore <CQualifiedNameWithArity+ cnames> ;` <- rules) {
		for (cn <- cnames) {
			< tname, cname, arity > = splitTarget(cn);
			ignores = ignores + < tname, cname, arity >;
		}
	}

	set[str] newEdgeLabels = { };
	for ((CRule)`edge label <CName+ cnames> ;` <- rules) {
		newEdgeLabels = newEdgeLabels + { "<cn>" | cn <- cnames };
	}
	
	set[str] newNodeLabels = { };
	for ((CRule)`node label <CName+ cnames> ;` <- rules) {
		newNodeLabels = newNodeLabels + { "<cn>" | cn <- cnames };
	}
				
	return pgm("<name>", astSources, importedModules, contextNames, typeNames[0], ruleList, stargetSet, utargetSet, ignores, newEdgeLabels, newNodeLabels);	
}

@doc{Convert a concrete rule into an abstract rule}
public list[Rule] buildRule((CRule)`rule <CQualifiedNameWithArity+ targets> = <{CRulePart ","}+ parts> ;`) {
	list[Rule] res = [ ];
	list[RulePart] rparts = [ ];
	
	for (part <- parts) {
		rparts = rparts + buildRulePart(part);
	}
	
	for (tgt <- targets) {
		< tname, cname, arity > = splitTarget(tgt);
		res = res + rule(tname, cname, arity, rparts);
	}
	
	return res;
}

@doc{Convert a single rule item}
public RulePart buildRulePart((CRulePart)`<CRuleItem ri>`) {
	return namePart(buildRuleItem(ri));
}

@doc{Convert a link rule part where there are labels on the arrow}
public RulePart buildRulePart((CRulePart)`<CRulePart l> <CDash _> <{CName ","}+ names> <CDash _> \> <CRulePart r>`) {
	return linkPart(buildRulePart(l), buildRulePart(r), { "<n>" | n <- names });
}

@doc{Convert a link rule part where there are no labels on the arrow}
public RulePart buildRulePart((CRulePart)`<CRulePart l> <CDash _> \> <CRulePart r>`) {
	return linkPart(buildRulePart(l), buildRulePart(r), { });
}

@doc{Convert a create rule part, which creates a node}
public RulePart buildRulePart((CRulePart)`create (<CBaseName cn>)`) {
	return createPart(buildBaseName(cn));
}

@doc{Convert a jump rule part, with item providing the target}
public RulePart buildRulePart((CRulePart)`jump (<CRuleItem cn>)`) {
	return jumpPart(buildRuleItem(cn));
}

@doc{Convert a jump rule part, with item providing the target}
public RulePart buildRulePart((CRulePart)`jump (<CRuleItem cn>, <CName ttype>)`) {
	return jumpPart(buildRuleItem(cn), ":" + removeStartingSlash("<ttype>"));
}

@doc{Convert a jump rule part, with item providing the target}
public RulePart buildRulePart((CRulePart)`jumpToTarget (<CName ttype>)`) {
	return jumpToTargetPart(":" + removeStartingSlash("<ttype>"));
}

@doc{Convert a meta-level conditional}
public RulePart buildRulePart((CRulePart)`if ( <CPredOp predOp> ) { <CRulePart ifPart> } else { <CRulePart elsePart>}`) {
	return condPart(buildPredOp(predOp), buildRulePart(ifPart), buildRulePart(elsePart));
}

@doc{Convert a nothing rule part (our version of skip)}
public RulePart buildRulePart((CRulePart)`#nothing`) {
	return nothing();
}

@doc{Convert a meta-level for loop}
public RulePart buildRulePart((CRulePart)`for(<CName v> \<- <CRuleItem item>) { <CRulePart body> }`) {
	return loopPart("<v>", buildRuleItem(item), buildRulePart(body));
}

@doc{Convert an entry rule part with 0 or more defaults}
public RulePart buildRulePart((CRulePart)`entry (<{CRuleItem ","}+ items>)`) {
	return entryPart([buildRuleItem(ri)|ri<-items]);
}

@doc{Convert an exit rule part with 0 or more defaults}
public RulePart buildRulePart((CRulePart)`exit (<{CRuleItem ","}+ items>)`) {
	return exitPart([buildRuleItem(ri)|ri<-items]);
}

@doc{Convert a jumpTarget rule part}
public RulePart buildRulePart((CRulePart)`jumpTarget (<CRuleItem item>)`) {
	return jumpTargetPart(buildRuleItem(item));
}

@doc{Convert a jumpTarget rule part with a jump target label type}
public RulePart buildRulePart((CRulePart)`jumpTarget (<CRuleItem item>, <CName ttype>)`) {
	return jumpTargetPart(buildRuleItem(item), ":" + removeStartingSlash("<ttype>"));
}

@doc{Convert a decorated item into a rule item with the appropriate item information based on the decorations}
public RuleItem buildRuleItem((CRuleItem)`<CDecoration+ decorations> <CItemName itemName>`) {
	decs = { buildDecoration(d) | d <- decorations };
	return ruleItem(buildItem(itemName), decs);
}

@doc{Convert an undecorated item}
public RuleItem buildRuleItem((CRuleItem)`<CItemName itemName>`) {
	return ruleItem(buildItem(itemName), {});
}

@doc{Convert an item name representing a single name.}
public ItemName buildItem((CItemName)`<CBaseName fn>`) {
	return buildBaseName(fn);
}

@doc{Convert an item name representing a compound name.}
public ItemName buildItem((CItemName)`<CBaseName fn>.<{CName "."}+ cnl>`) {
	return compoundName(buildBaseName(fn),["<cn>"|cn<-cnl]);
}

public default ItemName buildItem(CItemName iname) {
	println("Found an item name we cannot handle");
	return fieldName("");
}

@doc{Convert an item representing a field name}
public ItemName buildBaseName((CBaseName)`<CName fn>`) {
	return fieldName(removeStartingSlash("<fn>"));
}

@doc{Convert an item representing self}
public ItemName buildBaseName((CBaseName)`self`) {
	return selfName();
}

@doc{Convert an item representing following}
public ItemName buildBaseName((CBaseName)`following`) {
	return followingName();
}

@doc{Convert an item representing first}
public ItemName buildBaseName((CBaseName)`first`) {
	return firstName();
}

@doc{Convert an item representing last}
public ItemName buildBaseName((CBaseName)`last`) {
	return lastName();
}

@doc{Convert an item representing next}
public ItemName buildBaseName((CBaseName)`next`) {
	return nextName();
}

@doc{Convert an item representing header}
public ItemName buildBaseName((CBaseName)`header`) {
	return headerName();
}

@doc{Convert an item representing footer}
public ItemName buildBaseName((CBaseName)`footer`) {
	return footerName();
}

@doc{Convert an item representing exit}
public ItemName buildBaseName((CBaseName)`exit`) {
	return exitName();
}

@doc{Convert an item representing entry}
public ItemName buildBaseName((CBaseName)`entry`) {
	return entryName();
}

@doc{Convert the entry decoration into the appropriate label.}
public ItemInfo buildDecoration((CDecoration)`^`) = entryLabel();

@doc{Convert the exit decoration into the appropriate label.}
public ItemInfo buildDecoration((CDecoration)`$`) = exitLabel();

@doc{Convert the check decoration into the appropriate label.}
public ItemInfo buildDecoration((CDecoration)`?`) = checkLabel();

@doc{Convert the check decoration into the appropriate label.}
public ItemInfo buildDecoration((CDecoration)`@`) = loopTarget();

@doc{Convert the jump decoration into the appropriate label.}
public ItemInfo buildDecoration((CDecoration)`!`) = jump();

@doc{Convert the empty? predicate into AST form}
public PredOp buildPredOp((CPredOp)`empty?(<CItemName itemName>)`) = emptyOp(buildItem(itemName));

@doc{Convert the first? predicate into AST form}
public PredOp buildPredOp((CPredOp)`first?(<CItemName itemName>)`) = firstOp(buildItem(itemName));

@doc{Convert the last? predicate into AST form}
public PredOp buildPredOp((CPredOp)`last?(<CItemName itemName>)`) = lastOp(buildItem(itemName));

@doc{Convert the is predicate into AST form}
public PredOp buildPredOp((CPredOp)`<CItemName itemName> is <CQualifiedName qn>`) = isOp(buildItem(itemName), "<qn>");

 