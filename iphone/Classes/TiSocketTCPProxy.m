/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiSocketTCPProxy.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netdb.h>

#pragma mark Forward declarations

// Size of the read buffer; ideally should be a multiple of 1024 (1k), up to 4096 (4k, page size)
const unsigned int bufferSize = 4096;

// TODO: Add sockaddr for better error reporting about which remote host disconnected -
// We can get that data from the 'address' passed to handleSocketConnection.  Maybe this
// will be useful in some situations.
// IN FACT: This might be useful in Bonjour communication!  Add this feature when bonjour is finished.
typedef struct {
    CFReadStreamRef inputStream;
    CFWriteStreamRef outputStream;
	
	NSMutableArray* writeBuffer;
    NSUInteger bufferPos;
} SocketStreams;

void handleSocketConnection(CFSocketRef socket, CFSocketCallBackType type,
							CFDataRef address, const void* data, void* info);

void handleReadData(CFReadStreamRef input, 
                    CFStreamEventType event, 
                    void* info);
void handleWriteData(CFWriteStreamRef input, 
                     CFStreamEventType event, 
                     void* info);

NSString* getStreamError(CFTypeRef stream,
                         CFErrorRef(*getError)(CFTypeRef));

const CFOptionFlags readStreamEventFlags = 
	kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered;

const CFOptionFlags writeStreamEventFlags =
    kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred;

@implementation TiSocketTCPProxy

#pragma mark Private

#define VALID [[self isValid:nil] boolValue]

-(NSMutableDictionary*)remoteSocketDictionary
{
    return remoteSocketDictionary;
}

-(NSMutableArray*)readBuffer
{
    return readBuffer;
}

-(NSLock*)readLock 
{
	return readLock;
}

-(NSRecursiveLock*)writeLock
{
    return writeLock;
}

-(void)toggleActiveSocket:(int)remoteSocket
{
    activeSockets ^= remoteSocket;
}

-(void)closeRemoteSocket:(CFSocketNativeHandle)remoteSocket
{
    NSNumber* remoteSocketObject = [NSNumber numberWithInt:remoteSocket];
    NSData* socketStreamsObject = [remoteSocketDictionary objectForKey:remoteSocketObject];
    SocketStreams* streams = (SocketStreams*)[socketStreamsObject bytes];
    
    if (streams->inputStream) {
        CFReadStreamClose(streams->inputStream);
        CFRelease(streams->inputStream);
    }
    if (streams->outputStream) {
        CFWriteStreamClose(streams->outputStream);
        CFRelease(streams->outputStream);
    }
    
    if ([streams->writeBuffer count] > 0) {
        [self toggleActiveSocket:remoteSocket];
    }
    
    [streams->writeBuffer release];

    close(remoteSocket);
    [remoteSocketDictionary removeObjectForKey:remoteSocketObject];
}

#pragma mark Public

-(id)init
{
    if (self = [super init]) {
        socket = NULL;
        remoteSocketDictionary = [[NSMutableDictionary alloc] init];
        
        readBuffer = [[NSMutableArray alloc] init];
        
        readLock = [[NSLock alloc] init];
        writeLock = [[NSRecursiveLock alloc] init];
        
        mode = READ_WRITE_MODE;
        activeSockets = 0;
    }
    
    return self;
}

-(void)dealloc
{
    [self close:nil];
    
    [hostName release];
    [readBuffer release];
    [remoteSocketDictionary release];
	[readLock release];
	[writeLock release];
	
    [super dealloc];
}

-(NSNumber*)mode
{
    return [NSNumber numberWithInt:mode];
}

-(void)setMode:(NSNumber*)mode_
{
    switch ([mode_ intValue]) {
        case READ_MODE:
        case WRITE_MODE:
        case READ_WRITE_MODE:
            break;
        default:
            [self throwException:TiExceptionRangeError 
                       subreason:@"Invalid socket mode" 
                        location:CODELOCATION];
    }
    
    mode = [mode_ intValue];
}

-(NSString*)hostName
{
    return hostName;
}

-(void)setHostName:(NSString*)hostName_
{
    if (hostName == hostName_) {
        return;
    }
    [hostName release];
    hostName = [hostName_ retain];
}

-(NSNumber*)port
{
    return [NSNumber numberWithInt:port];
}

-(void)setPort:(NSNumber*)port_
{
    port = [port_ intValue];
}

-(NSNumber*)dataAvailable:(id)unused
{
    return [NSNumber numberWithBool:([readBuffer count] != 0)];
}

-(NSNumber*)hasActiveSockets:(id)unused
{
    return [NSNumber numberWithInt:activeSockets];
}

-(NSNumber*)isValid:(id)unused
{
    if (socket) {
        return [NSNumber numberWithBool:CFSocketIsValid(socket)];
    }
    return [NSNumber numberWithBool:false];
}

-(void)open:(id)unused
{
    if (VALID) {
        [self throwException:@"Socket already opened"
                   subreason:nil
                    location:CODELOCATION];
    }
    
    if (hostName == nil) {
        [self throwException:@"Host is null"
                   subreason:nil
                    location:CODELOCATION];
    }
    
    CFSocketContext socketContext;
    socketContext.version = 0;
    socketContext.info = self;
    socketContext.retain = NULL;
    socketContext.release = NULL;
    socketContext.copyDescription = NULL;
    
    // SocketContext is copied
    socket = CFSocketCreate(kCFAllocatorDefault,
							PF_INET,
							SOCK_STREAM,
							IPPROTO_TCP,
							kCFSocketAcceptCallBack,
							handleSocketConnection,
							&socketContext);
    
    if (!socket) {
        [self throwException:[NSString stringWithFormat:@"Failed to create socket: %d", errno]
                   subreason:nil
                    location:CODELOCATION];
    }
    
    struct sockaddr_in address;
    struct hostent *host;
    
    memset(&address, 0, sizeof(address)); // THIS is the finnicky bit: sockaddr_in needs to have 8 bytes of 0 at the end to be compatible with sockaddr
    address.sin_len = sizeof(address);
    address.sin_port = htons(port);
    address.sin_family = AF_INET;
	
    host = gethostbyname([hostName cStringUsingEncoding:[NSString defaultCStringEncoding]]); 
    if (host == NULL) {
        CFSocketInvalidate(socket);
        CFRelease(socket);
        socket = NULL;
        
        [self throwException:[NSString stringWithFormat:@"Couldn't resolve host %@: %d", hostName, h_errno]
                   subreason:nil
                    location:CODELOCATION];
    }
    memcpy(&address.sin_addr.s_addr, host->h_addr_list[0], host->h_length);
    
    CFDataRef addressData = CFDataCreate(kCFAllocatorDefault,
                                         (UInt8*)&address,
                                         sizeof(address));
    
    CFSocketError sockError = CFSocketSetAddress(socket,
												 addressData);
    switch (sockError) {
        case kCFSocketError: {
            CFSocketInvalidate(socket);
            CFRelease(socket);
            socket = NULL;
    
            CFRelease(addressData);
            
            [self throwException:[NSString stringWithFormat:@"Failed to connect to %@:%d: %d", hostName, port, errno]
                       subreason:nil
                        location:CODELOCATION];
            break;
		}
	}
    
    CFRelease(addressData);
    
    //[self performSelectorInBackground:@selector(runSocket) withObject:nil];
    
    CFRunLoopSourceRef socketRunLoop = CFSocketCreateRunLoopSource(kCFAllocatorDefault,
                                                                   socket,
                                                                   1);
    CFRunLoopAddSource(CFRunLoopGetMain(),
                       socketRunLoop,
                       kCFRunLoopCommonModes);
    CFRelease(socketRunLoop); 
}

-(void)close:(id)unused
{
    if (!VALID) {
        [self throwException:@"Socket is not open"
                   subreason:nil
                    location:CODELOCATION];
    }
    
    NSEnumerator* keys = [[remoteSocketDictionary allKeys] objectEnumerator];
    id remoteSocketObject;
    
    // Shut down all of the streams and remote connections
    while ((remoteSocketObject = [keys nextObject])) {
        CFSocketNativeHandle remoteSocket = [remoteSocketObject intValue];
        [self closeRemoteSocket:remoteSocket];
    }
    [readBuffer removeAllObjects];
    
    if (socket) {
        CFSocketInvalidate(socket);
        CFRelease(socket);
    }
    
    socket = NULL;
}

-(TiBlob*)read:(id)unused
{
    if (!(mode & READ_MODE)) {
        [self throwException:@"Socket does not support reading"
                   subreason:nil
                    location:CODELOCATION];
    }
    else if (!VALID) {
        [self throwException:@"Socket is not open"
                   subreason:nil
                    location:CODELOCATION];
    }

    [readLock lock];
    
    if ([[self dataAvailable:nil] boolValue]) {
        TiBlob* dataBlob = [[[TiBlob alloc] initWithData:[readBuffer objectAtIndex:0] 
                                                mimetype:@"application/octet-stream"] autorelease];
        [readBuffer removeObjectAtIndex:0];

        [readLock unlock];
        
        return dataBlob;
    }
    
    [readLock unlock];
    
	return nil;
}

-(void)write:(id)args;
{
    if (!(mode & WRITE_MODE)) {
        [self throwException:@"Socket does not support writing"
                   subreason:nil
                    location:CODELOCATION];
    }
    else if (!VALID) {
        [self throwException:@"Socket is invalid"
                   subreason:nil
                    location:CODELOCATION];
    }
    
    NSData* data = nil;
    
    id arg = [args objectAtIndex:0];
    if ([arg isKindOfClass:[TiBlob class]]) {
        data = [arg data];
    }
    else if ([arg isKindOfClass:[NSString class]]) {
        data = [NSData dataWithBytes:[arg UTF8String] length:[arg length]+1];
    }
    else {
        NSString* errorStr = [NSString stringWithFormat:@"expected: %@ or %@, was: %@", [TiBlob class], [NSString class], [arg class]];
        THROW_INVALID_ARG(errorStr)
    }
    
    [writeLock lock];

    NSEnumerator* keyEnum = [[remoteSocketDictionary allKeys] objectEnumerator];
    NSNumber* key;
    
    while ((key = [keyEnum nextObject])) {
        NSData* streamData = [remoteSocketDictionary objectForKey:key];
        SocketStreams* streams = (SocketStreams*)[streamData bytes];
        [streams->writeBuffer addObject:data];
        [self toggleActiveSocket:[key intValue]];
    
        if (CFWriteStreamCanAcceptBytes(streams->outputStream)) {
            handleWriteData(streams->outputStream,
                            kCFStreamEventCanAcceptBytes,
                            self);
        }
    }
    
    [writeLock unlock];
}

@end


#pragma mark Socket data handling

void handleSocketConnection(CFSocketRef socket, CFSocketCallBackType type, 
							CFDataRef address, const void* data, void* info) {
    switch (type) {
        case kCFSocketAcceptCallBack: {
            TiSocketTCPProxy* hostSocket = (TiSocketTCPProxy*)info;
			CFSocketNativeHandle sock = *(CFSocketNativeHandle*)data;
            SocketStreams streams;
			
			streams.inputStream = NULL;
			streams.outputStream = NULL;
			streams.writeBuffer = [[NSMutableArray alloc] init];
			streams.bufferPos = 0;
            
            SocketMode mode = [[hostSocket mode] intValue];
            CFStreamCreatePairWithSocket(kCFAllocatorDefault,
                                         sock,
                                         (mode & READ_MODE) ? &streams.inputStream : NULL,
                                         (mode & WRITE_MODE) ? &streams.outputStream : NULL);
            
            NSData* streamData = [NSData dataWithBytes:&streams length:sizeof(SocketStreams)];
            [[hostSocket remoteSocketDictionary] setObject:streamData forKey:[NSNumber numberWithInt:sock]];
            
			CFStreamClientContext context;
			context.version = 0;
			context.info = hostSocket;
			context.retain = NULL;
			context.release = NULL;
			context.copyDescription = NULL;
			
            if (mode & READ_MODE) {
                CFReadStreamSetClient(streams.inputStream, readStreamEventFlags, handleReadData, &context);
                CFReadStreamScheduleWithRunLoop(streams.inputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
                CFReadStreamOpen(streams.inputStream);
            }
        
            if (mode & WRITE_MODE) {
                CFWriteStreamSetClient(streams.outputStream, writeStreamEventFlags, handleWriteData, &context);
                CFWriteStreamScheduleWithRunLoop(streams.outputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
                CFWriteStreamOpen(streams.outputStream);
            }
            
            break;
        }
    }
}


void handleReadData(CFReadStreamRef input,
					CFStreamEventType event,
					void* info)
{
    TiSocketTCPProxy* hostSocket = (TiSocketTCPProxy*)info;
    CFSocketNativeHandle remoteSocket;
    CFDataRef remoteSocketData = CFReadStreamCopyProperty(input, kCFStreamPropertySocketNativeHandle);
	if (remoteSocketData == NULL) {
		// A truely bizarre scenario.. but it could happen!  If it does, the stream is orphaned from the remote socket somehow,
		// or things were never properly initialized.. the only cleanup we can do is on the given input.
		// TODO: Is this even the right thing to do?
        
        NSString* error = getStreamError(input, (CFErrorRef(*)(CFTypeRef))CFReadStreamCopyError);

		CFReadStreamClose(input);
		CFRelease(input);

        [hostSocket fireEvent:@"readError"
                   withObject:error];
        
        return;
	}
    CFDataGetBytes(remoteSocketData, CFRangeMake(0, CFDataGetLength(remoteSocketData)), (UInt8*)&remoteSocket);
    CFRelease(remoteSocketData);
    
	switch (event) {
		case kCFStreamEventEndEncountered: {
            [hostSocket closeRemoteSocket:remoteSocket];
			break;
		}
        // There's not very much information you can get out of an error like this, other than
        // that it occurred.  It's not recoverable without the direct stream information, most likely.
		case kCFStreamEventErrorOccurred: {
            NSString* error = getStreamError(input, (CFErrorRef(*)(CFTypeRef))CFReadStreamCopyError);
            
            [hostSocket closeRemoteSocket:remoteSocket];
            
            [hostSocket fireEvent:@"readError"
                       withObject:error];
            
			break;
		}
		// This event is NOT necessarily fired until all current available data has been read.  Gotta clear that buffer first!
		case kCFStreamEventHasBytesAvailable: {
            [[hostSocket readLock] lock];
			
			while (CFReadStreamHasBytesAvailable(input)) {
                UInt8* buffer = malloc(bufferSize * sizeof(UInt8));
				CFIndex bytesRead = CFReadStreamRead(input, buffer, bufferSize);
                // TODO: Does this cause a kCFStreamEventErrorOccurred?  If so, we may run into weird problems.
                if (bytesRead == -1) {
                    free(buffer);
                    NSString* error = getStreamError(input, (CFErrorRef(*)(CFTypeRef))CFReadStreamCopyError);
                    
                    [hostSocket closeRemoteSocket:remoteSocket];
                    [hostSocket fireEvent:@"readError"
                               withObject:error];
                    
                    break;
                }
                NSData* data = [NSData dataWithBytesNoCopy:buffer length:bytesRead];
                [[hostSocket readBuffer] addObject:data];
			}
			[[hostSocket readLock] unlock];
            
            [hostSocket fireEvent:@"newData"
                       withObject:nil];
			break;
		}
	}
}

void handleWriteData(CFWriteStreamRef output,
                     CFStreamEventType event,
                     void* info)
{
    TiSocketTCPProxy* hostSocket = (TiSocketTCPProxy*)info;
    CFSocketNativeHandle remoteSocket;
    CFDataRef remoteSocketData = CFWriteStreamCopyProperty(output, kCFStreamPropertySocketNativeHandle);
	if (remoteSocketData == NULL) {
		// A truely bizarre scenario.. but it could happen!  If it does, the stream is orphaned from the remote socket somehow,
		// or things were never properly initialized.. the only cleanup we can do is on the given input.

        NSString* error = getStreamError(output, (CFErrorRef(*)(CFTypeRef))CFReadStreamCopyError);
		
		CFWriteStreamClose(output);
		CFRelease(output);
        
        [hostSocket fireEvent:@"writeError"
                   withObject:error];
        
        return;
	}
    CFDataGetBytes(remoteSocketData, CFRangeMake(0, CFDataGetLength(remoteSocketData)), (UInt8*)&remoteSocket);
    CFRelease(remoteSocketData);
    
    switch (event) {
        // Let the user handle error recovery, etc...
		case kCFStreamEventErrorOccurred: {
            NSString* error = getStreamError(output, (CFErrorRef(*)(CFTypeRef))CFReadStreamCopyError);
            [hostSocket closeRemoteSocket:remoteSocket];
            
            [hostSocket fireEvent:@"writeError"
                       withObject:error];
            
			break;
		}
		case kCFStreamEventCanAcceptBytes: {
            SocketStreams* streams = 
                (SocketStreams*)[[[hostSocket remoteSocketDictionary] objectForKey:[NSNumber numberWithInt:remoteSocket]] bytes];
            if ([streams->writeBuffer count] == 0) {
                break;
            }
            
            do {
                CFIndex wroteBytes = 0;
                NSData* data = [streams->writeBuffer objectAtIndex:0];
                
                const UInt8* startPos = [data bytes] + streams->bufferPos;
                CFIndex length = [data length] - streams->bufferPos;
                
                wroteBytes = CFWriteStreamWrite(streams->outputStream, startPos, length);
                
                if (wroteBytes == -1) {
                    NSString* error = getStreamError(output, (CFErrorRef(*)(CFTypeRef))CFReadStreamCopyError);
                    [hostSocket closeRemoteSocket:remoteSocket];
                    
                    [hostSocket fireEvent:@"writeError"
                               withObject:error];
                    
                    break;
                }
                
                if (wroteBytes != length) {
                    streams->bufferPos += wroteBytes;
                }
                else {
                    [streams->writeBuffer removeObjectAtIndex:0];
                    streams->bufferPos = 0;
                }
            } while (streams->bufferPos == 0 && [streams->writeBuffer count] > 0);
            
            break;
		}
	}
}

NSString* getStreamError(CFTypeRef stream,
                         CFErrorRef(*getError)(CFTypeRef))
{
    CFErrorRef CFerror = getError(stream);
    CFStringRef errorStr = CFErrorCopyDescription(CFerror);
    
    NSString* error = [NSString stringWithFormat:@"ERROR %d: %@", CFErrorGetCode(CFerror), [NSString stringWithString:(NSString*)errorStr]];
    
    CFRelease(CFerror);
    CFRelease(errorStr);
    
    return error;
}
