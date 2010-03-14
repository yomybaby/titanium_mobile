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
        connectCondition = [[NSCondition alloc] init];
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
        connectCondition = [[NSCondition alloc] init];
        
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
    [connectCondition release];
    
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
    
    NSString* domain = nil;
    if ([serviceInfo objectForKey:domainKey]) {
        ENSURE_CLASS([serviceInfo objectForKey:domainKey], [NSString class])
        domain = [serviceInfo objectForKey:domainKey];
    }
    else {
        domain = @"local.";
    }
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
    if (!socket) {
        [self throwException:@"Attempt to publish service with no associated socket"
                   subreason:nil
                    location:CODELOCATION];
    }
    
    RELEASE_TO_NIL(error);
    
    [service publish];
    
    if (!published && !error) {
        [connectCondition lock];
        [connectCondition wait];
        [connectCondition unlock];
    }
    
    if (error) {
        [self throwException:[@"Failed to publish: " stringByAppendingString:error]
                   subreason:nil
                    location:CODELOCATION];
    }
}

-(void)resolve:(id)args
{
    if (published) {
        [self throwException:@"Attempt to resolve published Bonjour service"
                   subreason:nil
                    location:CODELOCATION];
    }
    if (socket) {
        [self throwException:@"Attempt to re-resolve service"
                   subreason:nil
                    location:CODELOCATION];
    }
    
    RELEASE_TO_NIL(error);
    
    NSTimeInterval timeout = 120.0;
    if ([args count] != 0 && !IS_NULL_OR_NIL([args objectAtIndex:0])) {
        ENSURE_CLASS([args objectAtIndex:0], [NSNumber class])
        timeout = [[args objectAtIndex:0] doubleValue];
    }
    
    [service resolveWithTimeout:timeout];
    
    if (!socket && !error) {
        [connectCondition lock];
        [connectCondition wait];
        [connectCondition unlock];
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
    
    if (published) {
        [connectCondition lock];
        [connectCondition wait];
        [connectCondition unlock];
    }
}

#pragma mark Private

-(void)synthesizeService
{
    
}

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
    
    [connectCondition lock];
    [connectCondition signal];
    [connectCondition unlock];
}

-(void)netServiceDidPublish:(NSNetService *)service_
{
    published = YES;
    
    [connectCondition lock];
    [connectCondition signal];
    [connectCondition unlock];
}

#pragma mark Resolution

-(void)netService:(NSNetService*)service_ didNotResolve:(NSDictionary*)errorDict
{
    [self setError:[BonjourModule stringForErrorCode:[[errorDict valueForKey:NSNetServicesErrorCode] intValue]]];
}

-(void)netServiceDidResolveAddress:(NSNetService*)service_
{
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
            
            [connectCondition lock];
            [connectCondition signal];
            [connectCondition unlock];
            break;
        }
    }
}

#pragma mark Stopping

-(void)netServiceDidStop:(NSNetService*)service_
{
    published = NO;
    
    [connectCondition lock];
    [connectCondition signal];
    [connectCondition unlock];
}

@end
