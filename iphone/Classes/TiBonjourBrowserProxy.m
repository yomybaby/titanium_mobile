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

@synthesize serviceType, domain;

#pragma mark Public

-(id)init
{
    if (self = [super init]) {
        browser = [[NSNetServiceBrowser alloc] init];
        services = [[NSMutableArray alloc] init];
        
        [browser removeFromRunLoop:[NSRunLoop currentRunLoop] 
                           forMode:NSDefaultRunLoopMode];
        [browser scheduleInRunLoop:[NSRunLoop mainRunLoop] 
                           forMode:NSDefaultRunLoopMode];
        
        [browser setDelegate:self];
    }
    
    return self;
}

-(void)dealloc
{
    [browser release];
    [serviceType release];
    [domain release];
    [services release];
    
    [super dealloc];
}

-(NSArray*)services
{
    return [[services copy] autorelease];
}

-(NSString*)description
{
    return [NSString stringWithFormat:@"BonjourServiceBrowser: %@ (%d)", [services description], [services retainCount]];
}

-(void)setServiceType:(NSString*)type_
{
    if (serviceType == type_) {
        return;
    }
    
    [serviceType release];
    serviceType = [type_ retain];
}

-(void)setDomain:(NSString*)domain_
{
    if (domain == domain_) {
        return;
    }
    
    [domain release];
    domain = [domain_ retain];
}

-(void)search:(id)unused
{
    //[self performSelectorInBackground:@selector(runSearch) withObject:nil];
    [browser searchForServicesOfType:serviceType 
                            inDomain:domain];
}

-(void)stopSearch:(id)unused
{
    [browser stop];
}

-(void)purgeServices:(id)unused
{
    [services removeAllObjects];
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
             withObject:services];
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
             withObject:services];
    }
}

#pragma mark Search management

-(void)netServiceBrowserWillSearch:(NSNetServiceBrowser*)browser_
{
    [self fireEvent:@"willSearch"
         withObject:nil];
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)browser_ didNotSearch:(NSDictionary *)errorDict
{
    [self fireEvent:@"didNotSearch"
         withObject:[[BonjourModule stringForErrorCode:[[errorDict objectForKey:NSNetServicesErrorCode] intValue]] autorelease]];
}

-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser*)browser_
{
    [self fireEvent:@"stoppedSearch"
         withObject:nil];
}

@end
