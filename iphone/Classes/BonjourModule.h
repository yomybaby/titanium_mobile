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
    
    NSString* searchError;
    BOOL searching;
}

+(NSString*)stringForErrorCode:(NSNetServicesError)code;

-(void)searchDomains:(id)unused;
-(void)stopDomainSearch:(id)unused;
-(NSNumber*)isSearching:(id)unused;

@property(readonly) NSArray* domains;

@end
