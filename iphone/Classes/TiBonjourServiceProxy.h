//
//  TiBonjourServiceProxy.h
//  Titanium
//
//  Created by Stiv on 2/20/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TiProxy.h"
#import "TiSocketTCPProxy.h"

// NSNetService Delegate
@interface TiBonjourServiceProxy : TiProxy {
    TiSocketTCPProxy* socket;
    NSNetService* service;
    
    bool local;
}

-(NSNetService*)service;

-(id)initWithContext:(id<TiEvaluator>)context_ service:(NSNetService*)service_ local:(bool)local_;

// TODO: Add TXTRecord creation
// TODO: Move publish/stop to this class?

@property(readonly, nonatomic) TiSocketTCPProxy* socket;
@property(readonly, nonatomic) NSString* name;
@property(readonly, nonatomic) NSString* type;
@property(readonly, nonatomic) NSString* domain;
@property(readonly, nonatomic, getter=isLocal) NSNumber* local;

@end
