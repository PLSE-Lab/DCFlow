@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::ide::RegisterDCFlow

import lang::dcflow::\syntax::DCFlowSyntax;
import lang::dcflow::ide::Outline;
import lang::dcflow::ide::Check;

import ParseTree;
import util::IDE;

public void registerDCFlow() {
	registerLanguage("DCFlow", "cfg", parseDCFlow);
	registerContributions("DCFlow", buildContributionSet());
}

public Tree parseDCFlow(str s, loc l) {
	return parse(#start[CModule], s, l);	
}

public set[Contribution] buildContributionSet() {
	return { createOutlinerContribution(), createCheckerContribution() };
}