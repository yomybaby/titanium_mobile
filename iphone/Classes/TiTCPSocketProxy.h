/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import <Foundation/Foundation.h>
#import "TiProxy.h"
#import "SocketModule.h"
#import "TiBlob.h"

@interface TiTCPSocketProxy : TiProxy {
    CFSocketRef socket;
    NSString* hostName;
    int port;
    
    NSMutableDictionary* remoteSocketDictionary; // remoteSocket->{inputStream, outputStream, writeBuffer, writePos}

    NSMutableArray* readBuffer;
    NSData* currentReadData; // See the comment at the head of readData
    
    NSLock* readLock;
    NSRecursiveLock* writeLock;
	
	SocketMode mode;
    int activeSockets;
    bool finished;
}

-(id)initWithContext:(id<TiEvaluator>)context host:(NSString*)host_ port:(int)port_ mode:(SocketMode)mode_;

// TODO: What function signatures are allowed?  (void)() doesn't work...
-(void)open:(id)unused;
-(void)close:(id)unused;

-(NSNumber*)isValid:(id)unused;
-(NSNumber*)dataAvailable:(id)unused;
-(NSNumber*)hasActiveSockets:(id)unused;

-(TiBlob*)read:(id)unused;
-(void)write:(id)arg;

@property(readonly, nonatomic) NSString* hostName;
@property(readonly, nonatomic) NSNumber* port;

@end