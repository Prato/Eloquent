//
//  IndexingManager.h
//  Eloquent
//
//  Created by Manfred Bergmann on 28.05.07.
//  Copyright 2007 mabe. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CocoLogger/CocoLogger.h>
#import <SwordModule.h>
#import <Indexer.h>

@class SwordManager;

@interface IndexingManager : NSObject {
	NSString *baseIndexPath;
    
    /** interval in seconds for timer to fire */
    int interval;
    
    /** this indexing manager has a dedicated SwordManager instance */
    SwordManager *swordManager;
    
    NSLock *indexCheckLock;
}

@property (retain, readwrite) NSString *baseIndexPath;
@property (retain, readwrite) SwordManager *swordManager;
@property (readwrite) int interval;

/**
 \brief singleton convenient allocator and getter of instance
 */
+ (IndexingManager *)sharedManager;

// init
- (id)init;

/**
 calling this method will trigger checking for modules that do not have a valid index
 in a separate thread.
 */
- (void)triggerBackgroundIndexCheck;

/**
\brief returns the path of the index folder for the given module name
 @return NSString that is autoreleased
 */
- (NSString *)indexPathForModuleName:(NSString *)aModName textType:(NSString *)aModType;

/**
 \brief returns the path of the index folder for the given module name
 @return NSString that is autoreleased
 */
- (NSString *)indexFolderPathForModuleName:(NSString *)aModName;

/**
\brief checks whether an index already exists for the given module name and type
 @param[in] modName: the name of the module.
 @param[in] modType: the type of the module. depending on this, more than one index may be created for the module.
 @return: YES/NO
 */
- (BOOL)indexExistsForModuleName:(NSString *)modName;

@end
