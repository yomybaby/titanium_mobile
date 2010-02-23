//
//  TiBonjourServiceProxy.h
//  Titanium
//
//  Created by Stiv on 2/20/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TiProxy.h"
#import "TiTCPSocketProxy.h"

// NSNetService Delegate
@interface TiBonjourServiceProxy : TiProxy {
    TiTCPSocketProxy* socket;
    NSNetService* service;
    
    bool local;
}

-(NSNetService*)service;

-(id)initWithContext:(id<TiEvaluator>)context_ service:(NSNetService*)service_ socket:(TiTCPSocketProxy*)socket_ local:(bool)local_;
-(id)initWithContext:(id<TiEvaluator>)context_ service:(NSNetService*)service_ local:(bool)local_;

// TODO: Add TXTRecord creation

@property(readonly, nonatomic) TiTCPSocketProxy* socket;
@property(readonly, nonatomic) NSString* name;
@property(readonly, nonatomic) NSString* type;
@property(readonly, nonatomic) NSString* domain;
@property(readonly, nonatomic, getter=isLocal) NSNumber* local;

@end
