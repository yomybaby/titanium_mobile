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
    
    searchError = nil;
    searching = NO;
    searchCondition = [[NSCondition alloc] init];
}

-(void)_destroy
{
    [domains release];
    [domainBrowser release];
    [searchCondition release];
    
    [super _destroy];
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

-(void)searchDomains:(id)unused
{
    RELEASE_TO_NIL(searchError);
    [domainBrowser searchForBrowsableDomains];
    
    if (!searching && !searchError) {
        [searchCondition lock];
        [searchCondition wait];
        [searchCondition unlock];
    }
    
    if (searchError) {
        [self throwException:[@"Failed to search: " stringByAppendingString:searchError]
                   subreason:nil
                    location:CODELOCATION];        
    }
}

-(void)stopDomainSearch:(id)unused
{
    [domainBrowser stop];
    
    if (searching) {
        [searchCondition lock];
        [searchCondition wait];
        [searchCondition unlock];
    }
    
    [domains removeAllObjects];
}

-(NSNumber*)isSearching:(id)unused
{
    return [NSNumber numberWithBool:searching];
}

#pragma mark Private

-(void)setSearchError:(NSString*)error
{
    if (searchError != error) {
        [searchError release];
        searchError = [error retain];
    }
}

#pragma mark Delegate methods (NSNetServiceBrowser)

#pragma mark Domain management

-(void)netServiceBrowser:(NSNetServiceBrowser*)browser didFindDomain:(NSString*)domain moreComing:(BOOL)more
{
    [domains addObject:domain];
    
    if (!more) {
        [self fireEvent:@"updatedDomains"
             withObject:[NSDictionary dictionaryWithObject:[[domains copy] autorelease]
                                                    forKey:@"domains"]];
    }
}

-(void)netServiceBrowser:(NSNetServiceBrowser*)browser didRemoveDomain:(NSString*)domain moreComing:(BOOL)more
{
    [domains removeObject:domain];
    
    if (!more) {
        [self fireEvent:@"updatedDomains"
             withObject:[NSDictionary dictionaryWithObject:[[domains copy] autorelease]
                                                    forKey:@"domains"]];
    }
}

#pragma mark Search management

-(void)netServiceBrowserWillSearch:(NSNetServiceBrowser*)browser
{
    searching = YES;
    
    [searchCondition lock];
    [searchCondition signal];
    [searchCondition unlock];
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict
{
    [self setSearchError:[BonjourModule stringForErrorCode:[[errorDict objectForKey:NSNetServicesErrorCode] intValue]]];
    
    [searchCondition lock];
    [searchCondition signal];
    [searchCondition unlock];
}

-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser*)browser
{
    searching = NO;
    
    [searchCondition lock];
    [searchCondition signal];
    [searchCondition unlock];
}

@end
