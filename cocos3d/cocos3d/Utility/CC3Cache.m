/*
 * CC3Cache.m
 *
 * cocos3d 2.0.0
 * Author: Bill Hollings
 * Copyright (c) 2010-2013 The Brenwill Workshop Ltd. All rights reserved.
 * http://www.brenwill.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * http://en.wikipedia.org/wiki/MIT_License
 * 
 * See header file CC3Cache.h for full API documentation.
 */

#import "CC3Cache.h"
#import "pthread.h"


#pragma mark CC3Cache

@implementation CC3Cache

@synthesize isWeak=_isWeak, typeName=_typeName;

-(void) dealloc {
	[_objectsByName release];
	[_typeName release];
	[self deleteLock];
	[super dealloc];
}

-(void) addObject: (id<CC3Cacheable>) obj {
	if ( !obj ) return;
	NSString* objName = obj.name;
	CC3Assert(objName, @"%@ cannot be added to the %@ cache because its name property is nil.", obj, _typeName);
	CC3Assert( ![self getObjectNamed: objName], @"%@ cannot be added to the %@ cache because the"
			  @" cache already contains a %@ named %@. Remove it first before adding another.",
			  obj, _typeName, _typeName, objName);

	if (_isWeak) obj = [CC3WeakCacheWrapper wrapperWith: obj];

	[self lock];
	[_objectsByName setObject: obj forKey: objName];
	[self unlock];
}

-(id<CC3Cacheable>) getObjectNamed: (NSString*) name {
	[self lock];
	id obj = [_objectsByName objectForKey: name];
	[self unlock];

	if (_isWeak) obj = ((CC3WeakCacheWrapper*)obj).cachedObject;
	return obj;
}

-(void) removeObject: (id<CC3Cacheable>) obj { [self removeObjectNamed: obj.name]; }

-(void) removeObjectNamed: (NSString*) name {
	if ( !name ) return;
	LogRez(@"Removing %@ named %@ from the %@ cache.", _typeName, name, _typeName);

	[self lock];
	[_objectsByName removeObjectForKey: name];
	[self unlock];
}

-(void) removeAllObjects {
	[self lock];
	[_objectsByName removeAllObjects];
	[self unlock];
}

-(void) enumerateObjectsUsingBlock: (void (^) (id<CC3Cacheable> obj, BOOL* stop)) block {
	[self lock];
	[_objectsByName enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL* stop) {
		if (_isWeak) obj = ((CC3WeakCacheWrapper*)obj).cachedObject;
		block(obj, stop);
	}];
	[self unlock];
}

#pragma mark NSLocking implementation

-(void) lock { pthread_mutex_lock(&_mutex); }

-(void) unlock { pthread_mutex_unlock(&_mutex); }

-(void) initLock { pthread_mutex_init(&_mutex, NULL); }

-(void) deleteLock { pthread_mutex_destroy(&_mutex); }


#pragma mark Allocation and initialization

-(id) init { return [self initAsWeakCache: NO forType: @"content"]; }

-(id) initAsWeakCache: (BOOL) isWeak forType: (NSString*) typeName {
	if ( (self = [super init]) ) {
		_objectsByName = [NSMutableDictionary new];		// retained
		_isWeak = isWeak;
		_typeName = typeName;
		[self initLock];
	}
	return self;
}

+(id) weakCacheForType: (NSString*) typeName {
	return [[[self alloc] initAsWeakCache: YES forType: typeName] autorelease];
}

+(id) strongCacheForType: (NSString*) typeName {
	return [[[self alloc] initAsWeakCache: NO forType: typeName] autorelease];
}

@end


#pragma mark CC3WeakCacheWrapper

@implementation CC3WeakCacheWrapper

@synthesize cachedObject=_cachedObject;

-(void) dealloc {
	_cachedObject = nil;	// not retained
	[super dealloc];
}

-(NSString*) name { return _cachedObject.name; }


#pragma mark Allocation and initialization

-(id) initWith: (id<CC3Cacheable>) cachedObject {
	if ( (self = [super init]) ) {
		_cachedObject = cachedObject;	// not retained
	}
	return self;
}

+(id) wrapperWith: (id<CC3Cacheable>) cachedObject {
	return [[[self alloc] initWith: cachedObject] autorelease];
}

@end
