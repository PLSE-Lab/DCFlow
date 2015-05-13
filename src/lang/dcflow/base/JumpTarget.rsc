@license{
  Copyright (c) 2009-2014 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - mhills@cs.ecu.edu (ECU)}
module lang::dcflow::base::JumpTarget

import lang::dcflow::base::Label;

data JumpTarget
	= namedTarget(str targetName)
	| numberedTarget(int targetNum)
	| plainTarget()
	| unknownTarget()
	;
