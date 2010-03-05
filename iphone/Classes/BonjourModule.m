//
//  BonjourModule.m
//  Titanium
//
//  Created by Stiv on 2/16/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "BonjourModule.h"
#import "TiBonjourServiceProxy.h"
#import "TiBonjourBrowserProxy.h"

const NSString* nameArg = @"name";
const NSString* typeArg = @"type";
const NSString* domainArg = @"domain";
const NSString* socketArg = @"socket";

@implementation BonjourModule

#pragma mark Public

-(void)_configure
{
    [super _configure];
    domains = [[NSMutableArray alloc] init];
    domainBrowser = [[NSNetServiceBrowser alloc] init];
    
    [domainBrowser removeFromRunLoop:[NSRunLoop currentRunLoop] 
                             forMode:NSDefaultRunLoopMode];
    [domainBrowser scheduleInRunLoop:[NSRunLoop mainRunLoop] 
                             forMode:NSDefaultRunLoopMode];
}

-(void)_destroy
{
    [domains release];
    [domainBrowser release];
    [super _destroy];
}

-(NSArray*)domains
{
    return [[domains copy] autorelease];
}

+(NSString*)stringForErrorCode:(NSNetServicesError)code
{
    switch (code) {
        case NSNetServicesUnknownError:
            return @"UnknownError";
            break;
        case NSNetServicesCollisionError:
            return @"NameCollisionError";
            break;
        case NSNetServicesNotFoundError:
            return @"NotFoundError";
            break;
        case  NSNetServicesActivityInProgress:
            return @"InProgress";
            break;
        case NSNetServicesBadArgumentError:
            return @"BadArgumentError";
            break;
        case NSNetServicesCancelledError:
            return @"Cancelled";
            break;
        case NSNetServicesInvalidError:
            return @"InvalidError";
            break;
        case NSNetServicesTimeoutError:
            return @"TimeoutError";
            break;
    }
    
    return @"";
}

-(void)publish:(id)arg
{
    ENSURE_ARRAY(arg)
    
    TiBonjourServiceProxy* service = [arg objectAtIndex:0];
    ENSURE_CLASS(service, [TiBonjourServiceProxy class])
    if (![[service isLocal] boolValue]) {
        [self throwException:@"Attempt to republish discovered Bonjour service" 
                   subreason:nil
                    location:CODELOCATION];
    }
    [[service service] publish];
}

-(void)resolve:(id)args
{
    ENSURE_ARRAY(args)
    if ([args count] > 2) {
        [self throwException:TiExceptionNotEnoughArguments
                   subreason:nil
                    location:CODELOCATION];
    }
    
    ENSURE_CLASS([args objectAtIndex:0], [TiBonjourServiceProxy class])
    TiBonjourServiceProxy* service = [args objectAtIndex:0];
    
    NSTimeInterval timeout = 120.0;
    if ([args count] == 2 && !IS_NULL_OR_NIL([args objectAtIndex:1])) {
        ENSURE_CLASS([args objectAtIndex:1], [NSNumber class])
        timeout = [[args objectAtIndex:1] doubleValue];
    }
    
    if ([[service isLocal] boolValue]) {
        [self throwException:@"Attempt to resolve local Bonjour service"
                   subreason:nil
                    location:CODELOCATION];
    }
    [[service service] resolveWithTimeout:timeout];
}

-(void)stop:(id)arg
{
    ENSURE_ARRAY(arg)
    
    id service = [arg objectAtIndex:0];
    ENSURE_CLASS(service, [TiBonjourServiceProxy class])
    
    [[service service] stop];
}

-(void)monitorService:(id)arg
{
    ENSURE_ARRAY(arg)
    
    id service = [arg objectAtIndex:0];
    ENSURE_CLASS(service, [TiBonjourServiceProxy class])
    
    [[service service] startMonitoring];
}

-(void)stopMonitoringService:(id)arg
{
    ENSURE_ARRAY(arg)
    
    id service = [arg objectAtIndex:0];
    ENSURE_CLASS(service, [TiBonjourServiceProxy class])
    
    [[service service] stopMonitoring];
}

-(void)searchDomains:(id)unused
{
    //[self performSelectorInBackground:@selector(runSearch) withObject:nil];
    [domainBrowser searchForBrowsableDomains];
}

-(void)stopDomainSearch:(id)unused
{
    [domainBrowser stop];
}

#pragma mark Delegate methods (NSNetServiceBrowser)

#pragma mark Domain management

-(void)netServiceBrowser:(NSNetServiceBrowser*)browser didFindDomain:(NSString*)domain moreComing:(BOOL)more
{
    [domains addObject:domain];
    
    if (!more) {
        [self fireEvent:@"foundDomains"
             withObject:domains];
    }
}

-(void)netServiceBrowser:(NSNetServiceBrowser*)browser didRemoveDomain:(NSString*)domain moreComing:(BOOL)more
{
    [domains removeObject:domain];
    
    if (!more) {
        [self fireEvent:@"removedDomains"
             withObject:domains];
    }
}

#pragma mark Search management

-(void)netServiceBrowserWillSearch:(NSNetServiceBrowser*)browser
{
    [self fireEvent:@"willSearch"
         withObject:nil];
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict
{
    [self fireEvent:@"didNotSearch"
         withObject:[BonjourModule stringForErrorCode:[[errorDict objectForKey:NSNetServicesErrorCode] intValue]]];
}

-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser*)browser
{
    [self fireEvent:@"stoppedSearch"
         withObject:nil];
}

@end
