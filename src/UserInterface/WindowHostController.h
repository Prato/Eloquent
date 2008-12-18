//
//  WindowHostController.h
//  MacSword2
//
//  Created by Manfred Bergmann on 05.11.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ProtocolHelper.h>
#import <Indexer.h>

// toolbar identifiers
#define TB_ADD_BIBLE_ITEM       @"IdAddBible"
#define TB_MODULEINSTALLER_ITEM @"IdModuleInstaller"
#define TB_TOGGLE_MODULES_ITEM  @"IdToggleModules"
#define TB_SEARCH_TYPE_ITEM     @"IdSearchType"
#define TB_SEARCH_TEXT_ITEM     @"IdSearchText"

@class SearchTextObject;
@class LeftSideBarViewController;
@class RightSideBarViewController;

@interface WindowHostController : NSWindowController <NSCoding, SubviewHosting, WindowHosting> {
    // splitView to add and remove modules view. splitview hosts placeHolderView
    IBOutlet NSSplitView *mainSplitView;
    // the contentview of the window
    IBOutlet NSView *view;
    // splitView for placeholderview
    IBOutlet NSSplitView *contentSplitView;
    // placeholder for the main content view
    IBOutlet NSBox *placeHolderView;
    // placeholder for the search options
    IBOutlet NSBox *placeHolderSearchOptionsView;
    // progress indicator
    IBOutlet NSProgressIndicator *progressIndicator;
        
    // our delegate
    id delegate;
    
	// we need a dictionary for all our toolbar identifiers
	NSMutableDictionary *tbIdentifiers;

    // every host has a left side bar view
    LeftSideBarViewController *lsbViewController;
    float lsbWidth;
    BOOL showingLSB;    
    
    // every host has a right side bar view
    RightSideBarViewController *rsbViewController;
    float rsbWidth;
    BOOL showingRSB;

    // search stuff
    NSSearchField *searchTextField;
    NSView *searchOptionsView;
    /** search type segmented control */
    NSSegmentedControl *searchTypeSegControl;
    // selected search type
    SearchType searchType;
    // the search text helper object
    SearchTextObject *currentSearchText;
}

@property (readwrite) id delegate;
@property (readwrite) SearchType searchType;
@property (retain, readwrite) SearchTextObject *currentSearchText;

// methods
- (NSView *)view;
- (void)setView:(NSView *)aView;

// sidebars
- (void)showLeftSideBar;
- (void)hideLeftSideBar;
- (void)showRightSideBar;
- (void)hideRightSideBar;

- (void)setupToolbar;

/** sets the text string into the search text field */
- (void)setSearchText:(NSString *)aString;

/** action of any input to the search text field */
- (void)searchInput:(id)sender;

/** change the module type that is currently displaying */
- (void)adaptUIToCurrentlyDisplayingModuleType;

// WindowHosting
- (ModuleType)moduleType;

// SubviewHosting
- (void)contentViewInitFinished:(HostableViewController *)aView;
- (void)removeSubview:(HostableViewController *)aViewController;

// NSCoding
- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder *)encoder;

@end
