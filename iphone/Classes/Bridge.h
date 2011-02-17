/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "TiProxy.h"

@class TiHost;
@class Bridge;

@protocol TiBridgeDelegate <NSObject>

@optional
-(void)bridgeLoaded:(Bridge *)loadedBridge;
-(void)bridgeUnloaded:(Bridge *)unloadedBridge;
@end

@interface Bridge : NSObject {
@private
	NSObject<TiBridgeDelegate> * delegate;
	id callback;
	NSString *basename;
@protected
	NSURL *url;
	TiHost *host;
}

@property(readwrite,assign) NSObject<TiBridgeDelegate> * delegate;

-(id)initWithHost:(TiHost*)host;

-(void)boot:(id)callback url:(NSURL*)url preload:(NSDictionary*)preload;

-(void)booted;

-(void)shutdown:(NSCondition*)condition;

-(void)gc;

-(TiHost*)host;

- (NSString*)basename;

@end
