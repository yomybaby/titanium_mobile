//
//  BonjourModule.h
//  Titanium
//
//  Created by Stiv on 2/16/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TiModule.h"

@interface BonjourModule : TiModule {
    NSNetServiceBrowser* domainBrowser;
    NSMutableArray* domains;
    
    BOOL searching;
}

+(NSString*)stringForErrorCode:(NSNetServicesError)code;

-(void)searchDomains:(id)unused;
-(void)stopDomainSearch:(id)unused;

// TODO: Should these belong to the module, or the service?
-(void)publish:(id)arg;
-(void)resolve:(id)args;
-(void)stop:(id)arg;

-(void)monitorService:(id)arg;
-(void)stopMonitoringService:(id)arg;

@property(readonly) NSArray* domains;

@end
