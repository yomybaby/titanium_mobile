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

#pragma mark Private

-(void)runSearch
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    
    [browser scheduleInRunLoop:[NSRunLoop currentRunLoop]
                       forMode:NSDefaultRunLoopMode];   
    [browser searchForServicesOfType:serviceType 
                            inDomain:domain];
    searching = YES;
    
    while (searching) {
        SInt32 result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 10, YES);
        
        if (result == kCFRunLoopRunFinished || result == kCFRunLoopRunStopped) {
            searching = NO;
        }
        
        // Manage the pool - but it might be a performance hit to constantly dealloc/alloc it
        // when there's nothing in it.
        [pool release];
        pool = [[NSAutoreleasePool alloc] init];        
    }
    
    [browser removeFromRunLoop:[NSRunLoop currentRunLoop]
                       forMode:NSDefaultRunLoopMode];
    
    [pool release];
}

#pragma mark Public

-(id)init
{
    if (self = [super init]) {
        browser = [[NSNetServiceBrowser alloc] init];
        services = [[[NSMutableArray alloc] init] autorelease];
        
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
    
    [super dealloc];
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
    searching = NO;
    [self fireEvent:@"stoppedSearch"
         withObject:self];
}

@end
