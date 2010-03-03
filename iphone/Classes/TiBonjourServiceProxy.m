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

#pragma mark Delegate methods

#pragma mark Publication

-(void)netServiceWillPublish:(NSNetService*)service_
{
    [self fireEvent:@"willPublish"
         withObject:nil];
}

-(void)netService:(NSNetService*)service_ didNotPublish:(NSDictionary*)errorDict
{
    NSString* errorStr = [BonjourModule stringForErrorCode:[[errorDict valueForKey:NSNetServicesErrorCode] intValue]];
    
    [self fireEvent:@"didNotPublish"
         withObject:errorStr];
}

-(void)netServiceDidPublish:(NSNetService *)service_
{
    [self fireEvent:@"didPublish"
         withObject:nil];
}

#pragma mark Resolution

-(void)netServiceWillResolve:(NSNetService*)service_
{
    [self fireEvent:@"willResolve"
         withObject:nil];
}

-(void)netService:(NSNetService*)service_ didNotResolve:(NSDictionary*)errorDict
{
    NSString* errorStr = [BonjourModule stringForErrorCode:[[errorDict valueForKey:NSNetServicesErrorCode] intValue]];
    
    [self fireEvent:@"didNotResolve"
         withObject:errorStr];
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
            // This is necessary because otherwise the hostname lookup might muck up, due to local. not being a real domain.
            const struct sockaddr_in* sock = (struct sockaddr_in*)address;
            char hostStr[INET_ADDRSTRLEN];
            inet_ntop(address->sa_family, &(sock->sin_addr), hostStr, INET_ADDRSTRLEN);
            NSString* hostString = [NSString stringWithUTF8String:hostStr];
            socket = [[[TiSocketTCPProxy alloc] _initWithPageContext:[self pageContext]
                                                                args:[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:[service port]], @"port",
                                                                                                                                        hostString, @"hostName",
                                                                                                                                        [NSNumber numberWithInt:READ_WRITE_MODE], @"mode", nil]]]
                      autorelease];
            [socket retain]; // Avoid retain/release problems in dealloc
            
            [self fireEvent:@"resolved"
                 withObject:nil];
            break;
        }
    }
}

#pragma mark Service monitoring

-(void)netService:(NSNetService*)service_ didUpdateTXTRecordData:(NSData*)data
{
    TiBlob* datablob = [[[TiBlob alloc] initWithData:data mimetype:@"application/octet-stream"] autorelease];
    [self fireEvent:@"recordChanged"
         withObject:datablob];
}

#pragma mark Service stoppage

-(void)netServiceDidStop:(NSNetService *)service_
{
    [self fireEvent:@"stopped"
         withObject:nil];
}

@end
