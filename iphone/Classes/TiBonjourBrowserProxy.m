//
//  TiBonjourBrowserProxy.m
//  Titanium
//
//  Created by Stiv on 2/20/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "TiBonjourBrowserProxy.h"
#import "TiBonjourServiceProxy.h"
#import "BonjourModule.h"

@implementation TiBonjourBrowserProxy

@synthesize serviceType, domain, services;

#pragma mark Public

-(id)initWithContext:(id<TiEvaluator>)context serviceType:(NSString*)serviceType_ domain:(NSString*)domain_
{
    if (self = [super _initWithPageContext:context]) {
        browser = [[NSNetServiceBrowser alloc] init];
        services = [[[NSMutableArray alloc] init] autorelease];
        
        serviceType = [serviceType_ retain];
        domain = [domain_ retain];
        
        [browser setDelegate:self];
    }
    
    return self;
}

-(void)dealloc
{
    [browser release];
    [serviceType release];
    [domain release];
    
    [super dealloc];
}

-(void)search:(id)unused
{
    [browser searchForServicesOfType:serviceType 
                            inDomain:domain];
}

-(void)stopSearch:(id)unused
{
    [browser stop];
}

#pragma mark Delegate methods

#pragma mark Service management

// TODO: Should didFind/didRemove only return a list of those services found or removed?  Or should they be rolled into a single event, 'updatedServices'?

-(void)netServiceBrowser:(NSNetServiceBrowser*)browser_ didFindService:(NSNetService*)service moreComing:(BOOL)more
{
    [services addObject:[[[TiBonjourServiceProxy alloc] initWithContext:[self pageContext]
                                                                service:service
                                                                    local:NO] autorelease]];
    
    if (!more) {
        [self fireEvent:@"foundServices"
             withObject:[NSDictionary dictionaryWithObjectsAndKeys:self, @"browser", services, @"services", nil]];
    }
}

-(void)netServiceBrowser:(NSNetServiceBrowser*)browser_ didRemoveService:(NSNetService*)service moreComing:(BOOL)more
{
    // Create a temp object to release; this is what -[TiBonjourServiceProxy isEqual:] is for
    [services removeObject:[[[TiBonjourServiceProxy alloc] initWithContext:[self pageContext]
                                                                    service:service
                                                                     local:NO] autorelease]];
    
    if (!more) {
        [self fireEvent:@"removedServices"
             withObject:[NSDictionary dictionaryWithObjectsAndKeys:self, @"browser", services, @"services", nil]];
    }
}

#pragma mark Search management

-(void)netServiceBrowserWillSearch:(NSNetServiceBrowser*)browser_
{
    [self fireEvent:@"willSearch"
         withObject:self];
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)browser_ didNotSearch:(NSDictionary *)errorDict
{
    [self fireEvent:@"didNotSearch"
         withObject:[NSDictionary dictionaryWithObjectsAndKeys:self, @"browser", 
                                                                [BonjourModule stringForErrorCode:[[errorDict objectForKey:NSNetServicesErrorCode] intValue]], @"error",
                                                                nil]];
}

-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser*)browser_
{
    [self fireEvent:@"stoppedSearch"
         withObject:self];
}

@end
