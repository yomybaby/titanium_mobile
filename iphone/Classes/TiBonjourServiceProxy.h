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
    
    BOOL local;
    BOOL published;
    NSString* error;
    NSCondition* connectCondition;
}

-(NSNetService*)service;

-(id)initWithContext:(id<TiEvaluator>)context_ service:(NSNetService*)service_ local:(bool)local_;

-(void)publish:(id)arg;
-(void)resolve:(id)args;
-(void)stop:(id)arg;

@property(readonly) TiSocketTCPProxy* socket;
@property(readonly, nonatomic) NSString* name;
@property(readonly, nonatomic) NSString* type;
@property(readonly, nonatomic) NSString* domain;
@property(readonly, nonatomic, getter=isLocal) NSNumber* local;

@end
