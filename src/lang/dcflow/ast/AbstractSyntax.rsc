@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::ast::AbstractSyntax

data Program = pgm(str name, list[str] astSources, list[str] imports, lrel[str,str,RuleArity] contexts, str astType, list[Rule] rules, set[str] structuredTargets, set[str] unstructuredTargets, lrel[str,str,RuleArity] ignores, set[str] newEdgeLabels, set[str] newNodeLabels);

data RuleArity
	= empty()
	| numeric(int arity)
	| fieldNames(list[str] fieldNames)
	;
	
data Rule
	= rule(str targetType, str targetCons, RuleArity ruleArity, list[RulePart] parts)
	;
	
data RulePart
	= linkPart(RulePart from, RulePart to, set[str] edgeLabels)
	| createPart(ItemName name)
	| jumpPart(RuleItem item)
	| jumpPart(RuleItem item, str targetType)
	| jumpToTargetPart(str targetType)
	| condPart(PredOp op, RulePart truePart, RulePart falsePart)
	| nothing()
	| loopPart(str loopvar, RuleItem iterItem, RulePart body)
	| entryPart(list[RuleItem] items)
	| exitPart(list[RuleItem] items)
	| jumpTargetPart(RuleItem item)
	| jumpTargetPart(RuleItem item, str targetType)
	| namePart(RuleItem item)
	;
	
data PredOp
	= emptyOp(ItemName name)
	| firstOp(ItemName name)
	| lastOp(ItemName name)
	| isOp(ItemName item, str consName)
	;

data RuleItem
	= ruleItem(ItemName itemName, set[ItemInfo] itemInformation)
	;
	
data ItemName
	= fieldName(str name)
	| compoundName(ItemName basePart, list[str] fieldPart)
	| selfName()
	| followingName()
	| firstName()
	| lastName()
	| nextName()
	| headerName()
	| footerName()
	| exitName()
	| entryName()
	;
	
data ItemInfo
	= entryLabel()
	| exitLabel()
	| entryDefault(list[ItemName] defaultEntries)
	| exitDefault(list[ItemName] defaultExits)
	| checkLabel()
	| loopTarget()
	| namedTarget(str name)
	| namedTargetWithId(str name, ItemName idProvider)
	| jump()
	;
	