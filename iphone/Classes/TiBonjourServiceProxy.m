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


@implementation TiBonjourServiceProxy

@synthesize socket;

#pragma mark Private

-(NSNetService*)service
{
    return service;
}

#pragma mark Public

-(id)initWithContext:(id<TiEvaluator>)context_ service:(NSNetService*)service_ socket:(TiTCPSocketProxy*)socket_ local:(bool)local_
{
    if (self = [super _initWithPageContext:context_]) {
        service = service_;
        socket = socket_;
        local = local_;
        
        [service setDelegate:self];
    }
    
    return self;
}

-(id)initWithContext:(id<TiEvaluator>)context_ service:(NSNetService*)service_ local:(bool)local_
{
    if (self = [super _initWithPageContext:context_]) {
        // NOTE: We need to resolve the service to make sure that it's available before opening this socket,
        // and make sure it's available over IPv4.
        socket = nil;
        
        service = service_;
        local = local_;
        
        [service setDelegate:self];
    }
    
    return self;
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

#pragma mark Delegate methods

#pragma mark Publication

-(void)netServiceWillPublish:(NSNetService*)service_
{
    [self fireEvent:@"willPublish"
         withObject:self];
}

-(void)netService:(NSNetService*)service_ didNotPublish:(NSDictionary*)errorDict
{
    NSString* errorStr = [BonjourModule stringForErrorCode:[[errorDict valueForKey:NSNetServicesErrorCode] intValue]];
    
    [self fireEvent:@"didNotPublish"
         withObject:[NSDictionary dictionaryWithObjectsAndKeys:self, @"service", errorStr, @"error", nil]];
}

-(void)netServiceDidPublish:(NSNetService *)service_
{
    [self fireEvent:@"didPublish"
         withObject:self];
}

#pragma mark Resolution

-(void)netServiceWillResolve:(NSNetService*)service_
{
    [self fireEvent:@"willResolve"
         withObject:self];
}

-(void)netService:(NSNetService*)service_ didNotResolve:(NSDictionary*)errorDict
{
    NSString* errorStr = [BonjourModule stringForErrorCode:[[errorDict valueForKey:NSNetServicesErrorCode] intValue]];
    
    [self fireEvent:@"didNotResolve"
         withObject:[NSDictionary dictionaryWithObjectsAndKeys:self, @"service", errorStr, @"error", nil]];
}

-(void)netServiceDidResolveAddress:(NSNetService*)service_
{
    // If an IPv4 address has been resolved, open a socket and fire the event.
    // TODO: Also support IPv6 - but that would be a little more complicated and also require
    // sockets to support IPv6.
    NSData* addressData = nil;
    NSEnumerator* addressEnum = [[service addresses] objectEnumerator];
    while (addressData = [addressEnum nextObject]) {
        const struct sockaddr* address = [addressData bytes];
        if (address->sa_family == AF_INET) {
            // Leave it to the user to open the socket
            socket = [[[TiTCPSocketProxy alloc] initWithContext:[self pageContext]
                                                           host:[service hostName]
                                                           port:[service port]
                                                           mode:READ_WRITE_MODE] autorelease];
            [self fireEvent:@"resolved"
                 withObject:self];
            break;
        }
    }
}

#pragma mark Service monitoring

-(void)netService:(NSNetService*)service_ didUpdateTXTRecordData:(NSData*)data
{
    TiBlob* datablob = [[[TiBlob alloc] initWithData:data mimetype:@"application/octet-stream"] autorelease];
    [self fireEvent:@"recordChanged"
         withObject:[NSDictionary dictionaryWithObjectsAndKeys:self, @"service", datablob, @"data", nil]];
}

#pragma mark Service stoppage

-(void)netServiceDidStop:(NSNetService *)service_
{
    [self fireEvent:@"stopped"
         withObject:self];
}

@end
