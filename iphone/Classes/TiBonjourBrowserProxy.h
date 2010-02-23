//
//  TiBonjourBrowserProxy.h
//  Titanium
//
//  Created by Stiv on 2/20/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TiProxy.h"

// NSNetServiceBrowser delegate
@interface TiBonjourBrowserProxy : TiProxy {
    NSNetServiceBrowser* browser;
    NSString* serviceType;
    NSString* domain;
    
    NSMutableArray* services;
}

-(id)initWithContext:(id<TiEvaluator>)context serviceType:(NSString*)serviceType_ domain:(NSString*)domain_;

-(void)search:(id)unused;
-(void)stopSearch:(id)unused;

@property(readonly, nonatomic) NSString* serviceType;
@property(readonly, nonatomic) NSString* domain;
@property(readonly) NSArray* services;

@end