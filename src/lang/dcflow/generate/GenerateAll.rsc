@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::generate::GenerateAll

import lang::dcflow::ast::AbstractSyntax;
import lang::rascal::types::AbstractType;
import lang::dcflow::generate::GenerateUtils;
import lang::dcflow::generate::GenerateBuilder;
import lang::dcflow::generate::GenerateLabeler;
import lang::dcflow::util::C2A;

import Set;
import List;
import Type;
import IO;
import String;

public str generateAll(loc ploc, str modname="Builder", str funname="createCFG") {
	return generateAll(buildAST(ploc), modname=modname, funname=funname);
}

public str generateAll(Program p, str modname="Builder", str funname="createCFG") {
	gs = createGenState(p);
	return generateDCFlowModule(gs, p, modname, funname=funname);
}
 
public void generateAndWriteAll(loc ploc, loc rootloc, str funname="createCFG") {
	return generateAndWriteAll(buildAST(ploc), rootloc, funname=funname);
}

public void generateAndWriteAll(Program p, loc rootloc, str funname="createCFG") {
	gs = createGenState(p);
	generateAndWriteDCFlowModule(gs, p, "generated::Build<p.name>CFG", rootloc, funname=funname);
	//generateDCFlowLabeler(gs, p, "generated::Label<p.name>AST", rootloc);
	//return genInfo("generated::Build<p.name>CFG", "generated::Label<p.name>AST");
}