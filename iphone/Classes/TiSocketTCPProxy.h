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

@interface TiSocketTCPProxy : TiProxy {
    CFSocketRef socket;
    NSString* hostName;
    int port;
    
    NSMutableDictionary* remoteSocketDictionary; // remoteSocket->{inputStream, outputStream, writeBuffer, writePos}

    NSMutableArray* readBuffer;
    NSData* currentReadData;
    
    NSLock* readLock;
    NSRecursiveLock* writeLock;
	
	SocketMode mode;
    int activeSockets;
}

-(void)listen:(id)unused;
-(void)connect:(id)unused;
-(void)close:(id)unused;

-(NSNumber*)isValid:(id)unused;
-(NSNumber*)dataAvailable:(id)unused;
-(NSNumber*)hasActiveSockets:(id)unused;

-(TiBlob*)read:(id)unused;
-(void)write:(id)arg;

@property(readonly, nonatomic) NSString* hostName;
@property(readonly, nonatomic) NSNumber* port;
@property(readonly, nonatomic) NSNumber* mode;

@end