//
//  TiBonjourServiceProxy.m
//  Titanium
//
//  Created by Stiv on 2/20/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "TiBonjourServiceProxy.h"
#import "BonjourModule.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netdb.h>
#import <arpa/inet.h>

const NSString* nameKey = @"name";
const NSString* typeKey = @"type";
const NSString* domainKey = @"domain";
const NSString* socketKey = @"socket";

@implementation TiBonjourServiceProxy

@synthesize socket;

#pragma mark Public

-(id)init
{
    if (self = [super init]) {
        local = YES;
    }
    
    return self;
}

-(id)initWithContext:(id<TiEvaluator>)context_ service:(NSNetService*)service_ local:(bool)local_
{
    if (self = [super _initWithPageContext:context_]) {
        // NOTE: We need to resolve the service to make sure that it's available before opening this socket,
        // and make sure it's available over IPv4.
        socket = nil;
        
        service = [service_ retain];
        local = local_;
        
        [service removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [service scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        
        [service setDelegate:self];
    }
    
    return self;
}

-(void)dealloc
{
    [service release];
    [socket release];
    
    [super dealloc];
}

-(BOOL)isEqual:(id)obj
{
    if ([obj isKindOfClass:[TiBonjourServiceProxy class]]) {
        if ([[obj name] isEqual:[self name]] &&
            [[obj type] isEqual:[self type]] &&
            [[obj domain] isEqual:[self type]]) {
            return true;
        }
    }
    
    return false;
}

-(void)setService:(NSDictionary*)serviceInfo
{
    ENSURE_CLASS([serviceInfo objectForKey:nameKey], [NSString class])
    ENSURE_CLASS([serviceInfo objectForKey:typeKey], [NSString class])
    ENSURE_CLASS([serviceInfo objectForKey:domainKey], [NSString class])
    ENSURE_CLASS([serviceInfo objectForKey:socketKey], [TiSocketTCPProxy class])
    
    [service release];
    [socket release];
    
    socket = [[serviceInfo objectForKey:socketKey] retain];
    service = [[NSNetService alloc] initWithDomain:[serviceInfo objectForKey:domainKey] 
                                              type:[serviceInfo objectForKey:typeKey]
                                              name:[serviceInfo objectForKey:nameKey]
                                              port:[[socket port] intValue]];
    
    [service removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [service scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [service setDelegate:self];
}

-(NSString*)name
{
    return [service name];
}

-(NSString*)type
{
    return [service type];
}

-(NSString*)domain
{
    return [service domain];
}

-(NSNumber*)isLocal
{
    return [NSNumber numberWithBool:local];
}

-(NSNetService*)service
{
    return service;
}

-(void)publish:(id)arg
{
    RELEASE_TO_NIL(error);
    
    if (!local) {
        [self throwException:@"Attempt to republish discovered Bonjour service" 
                   subreason:nil
                    location:CODELOCATION];
    }
    if (published) {
        [self throwException:@"Attempt to republish service"
                   subreason:nil
                    location:CODELOCATION];
    }
    
    [service publish];
    
    // Block
    while (!published && !error) {
        usleep(10);
    }
    
    if (error) {
        [self throwException:[@"Failed to publish: " stringByAppendingString:error]
                   subreason:nil
                    location:CODELOCATION];
    }
}

-(void)resolve:(id)args
{
    RELEASE_TO_NIL(error);
    
    NSTimeInterval timeout = 120.0;
    if ([args count] != 0 && !IS_NULL_OR_NIL([args objectAtIndex:0])) {
        ENSURE_CLASS([args objectAtIndex:0], [NSNumber class])
        timeout = [[args objectAtIndex:0] doubleValue];
    }
    
    if (local) {
        [self throwException:@"Attempt to resolve local Bonjour service"
                   subreason:nil
                    location:CODELOCATION];
    }
    if (socket) {
        [self throwException:@"Attempt to re-resolve service"
                   subreason:nil
                    location:CODELOCATION];
    }
    
    [service resolveWithTimeout:timeout];
    
    // Block; always up to 'timeout' max, though.
    while (!socket && !error) {
        usleep(10);
    }
    
    if (error) {
        [self throwException:[@"Did not resolve: " stringByAppendingString:error]
                   subreason:nil
                    location:CODELOCATION];
    }
}

-(void)stop:(id)arg
{    
    [service stop];
    
    // Block
    while (published) {
        usleep(10);
    }
}

#pragma mark Private

-(void)setError:(NSString*)error_
{
    if (error != error_) {
        [error release];
        error = [error_ retain];
    }
}

-(void)setSocket:(TiSocketTCPProxy*)socket_
{
    if (socket != socket_) {
        [socket release];
        socket = [socket_ retain];
    }
}

#pragma mark Delegate methods

#pragma mark Publication

-(void)netService:(NSNetService*)service_ didNotPublish:(NSDictionary*)errorDict
{
    [self setError:[BonjourModule stringForErrorCode:[[errorDict valueForKey:NSNetServicesErrorCode] intValue]]];
}

-(void)netServiceDidPublish:(NSNetService *)service_
{
    published = YES;
}

#pragma mark Resolution

-(void)netService:(NSNetService*)service_ didNotResolve:(NSDictionary*)errorDict
{
    [self setError:[BonjourModule stringForErrorCode:[[errorDict valueForKey:NSNetServicesErrorCode] intValue]]];
}

-(void)netServiceDidResolveAddress:(NSNetService*)service_
{
    // If an IPv4 address has been resolved, open a socket and fire the event.
    // TODO: Do we really need to only check IPv4?  Why not just resolve the first given address?
    NSData* addressData = nil;
    NSEnumerator* addressEnum = [[service addresses] objectEnumerator];
    while (addressData = [addressEnum nextObject]) {
        const struct sockaddr* address = [addressData bytes];
        if (address->sa_family == AF_INET) {
            [self setSocket:[[[TiSocketTCPProxy alloc] _initWithPageContext:[self pageContext]
                                                                       args:[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                        [NSNumber numberWithInt:[service port]], @"port",
                                                                                                        [service hostName], @"hostName",
                                                                                                        [NSNumber numberWithInt:READ_WRITE_MODE], @"mode", nil]]]
                      autorelease]];
            break;
        }
    }
}

#pragma mark Stopping

-(void)netServiceDidStop:(NSNetService*)service_
{
    published = NO;
}

@end
