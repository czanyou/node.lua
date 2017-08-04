/***
 * The content of this file or document is CONFIDENTIAL and PROPRIETARY
 * to ChengZhen(Anyou).  It is subject to the terms of a
 * License Agreement between Licensee and ChengZhen(Anyou).
 * restricting among other things, the use, reproduction, distribution
 * and transfer.  Each of the embodiments, including this information and
 * any derivative work shall retain this copyright notice.
 *
 * Copyright (c) 2014-2015 ChengZhen(Anyou). All Rights Reserved.
 *
 */
#include "media_comm.h"
 
#include "media_comm.c"
#include "media_queue.c"

//______________________________________________________________________________
////////////////////////////////////////////////////////////////////////////////
// Media System

int MediaSystemRelease() 
{
	return 0;
}

int MediaSystemInit(int mmzSize) 
{
	return 0;
}

LPCSTR MediaSystemGetType() 
{ 
	return "mock"; 
}


LPCSTR MediaSystemGetVersion()
{
	return "1.0.0";
}
