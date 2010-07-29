/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiAppBackgroundServiceProxy.h"
#import "TiUtils.h"
#import "TiApp.h"

#ifdef USE_TI_APP
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0


@implementation TiAppBackgroundServiceProxy

#pragma mark internal

-(void)dealloc
{
	RELEASE_TO_NIL(bridge);
	[super dealloc];
}

-(void)beginBackground
{
	bridge = [[KrollBridge alloc] initWithHost:[self _host]];
	NSURL *url = [TiUtils toURL:[self valueForKey:@"url"] proxy:self];
	
	//TODO: we need to make this in the App namespace, not UI
	NSDictionary *preload = [NSDictionary dictionaryWithObjectsAndKeys:self,@"currentService",nil];
	[bridge boot:nil url:url preload:preload];
}

-(void)endBackground
{
	if (bridge!=nil)
	{
		[self fireEvent:@"stop"];
		[bridge shutdown:nil];
		RELEASE_TO_NIL(bridge);
	}
}

#pragma mark public apis

-(void)stop:(id)args
{
	[self endBackground];
	[[TiApp app] stopBackgroundService:self];
}

@end

#endif
#endif