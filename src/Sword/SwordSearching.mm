//
//  SwordSearching.m
//  MacSword
//
// Copyright 2008 Manfred Bergmann
// Based on code by Will Thimbleby
//

#import "SwordSearching.h"
#import "CocoLogger/CocoLogger.h"
#import "IndexingManager.h"
#import "Indexer.h"
#import "SearchResultEntry.h"
#import "utils.h"
#import "SwordModule.h"
#import "SwordBible.h"
#import "SwordDictionary.h"
#import "SwordBook.h"
#import "SwordBibleBook.h"

NSString *MacSwordIndexVersion = @"2.5";

@implementation SwordModule(Searching)

/**
 generates a path index for the given VerseKey
 */
+ (NSString *)indexOfVerseKey:(sword::VerseKey *)vk {
    
    // we need this sequence for sorting and narrowing the search result
    NSString *index = [NSString stringWithFormat:@"%003i/%003i/%003i/%003i/%s", 
                       vk->Testament(),
                       vk->Book(),
                       vk->Chapter(),
                       vk->Verse(),
                       vk->getOSISBookName()];
    
    return index;
}

- (BOOL)hasIndex {
    BOOL ret = NO;
    
    [indexLock lock];
    // get IndexingManager
    IndexingManager *im = [IndexingManager sharedManager]; 
    NSString *path = [im indexFolderPathForModuleName:[self name]];
    BOOL isDir;
    
    if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"version.plist"]];
        if(d) {		
            if([[d objectForKey:@"MacSword Index Version"] isEqualToString:MacSwordIndexVersion]) {
                if(([d objectForKey:@"Sword Module Version"] == NULL) ||
                    ([[d objectForKey:@"Sword Module Version"] isEqualToString:[self version]])) {
                    MBLOGV(MBLOG_INFO, @"[SwordSearching -hasIndex] module %@ has valid index", [self name]);
                    ret = YES;
                } else {
                    //index out of date remove it
                    MBLOGV(MBLOG_INFO, @"[SwordSearching -hasIndex] module %@ has no valid index!", [self name]);
                    [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];                
                }
            } else {
                //index out of date remove it
                MBLOGV(MBLOG_INFO, @"[SwordSearching -hasIndex] module %@ has no valid index!", [self name]);
                [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];            
            }
        }		
    }
    [indexLock unlock];
    
	return ret;
}

- (void)createIndex {

	MBLOG(MBLOG_DEBUG, @"[SwordSearching -createIndex]");

	sword::SWKey *savekey = NULL;
	sword::SWKey *searchkey = NULL;
	sword::SWKey textkey;
	
	[moduleLock lock];
	
	// save key information so as not to disrupt original
	// module position
	if (!swModule->getKey()->Persist()) {
        // key does not persist
		savekey = swModule->CreateKey();
		*savekey = *swModule->getKey();
	} else {
		savekey = swModule->getKey();
    }

	searchkey = (swModule->getKey()->Persist()) ? swModule->getKey()->clone() : 0;
	if (searchkey) {
		searchkey->Persist(1);
		swModule->setKey(*searchkey);
	}

	// position module at the beginning
	*swModule = sword::TOP;
    
	// get Indexer
    Indexer *indexer = [Indexer indexerWithModuleName:[self name] 
                                           moduleType:[SwordModule moduleTypeForModuleTypeString:[self typeString]]];
    if(indexer == nil) {
        MBLOG(MBLOG_ERR, @"Could not create Indexer for this module!");
    } else {
        MBLOG(MBLOG_DEBUG, @"[SwordSearching -createIndexAndReportTo:] start indexing...");
        [self indexContentsIntoIndex:indexer];
        [indexer flushIndex];
        [indexer close];
        MBLOG(MBLOG_DEBUG, @"[SwordSearching -createIndexAndReportTo:] stopped indexing");

        // reposition module back to where it was before we were called
        swModule->setKey(*savekey);
        if (!savekey->Persist()) {
            delete savekey;
        }
        if (searchkey) {
            delete searchkey;
        }

        MBLOG(MBLOG_DEBUG, @"end index");
                
        //save version info
        NSString *path = [(IndexingManager *)[IndexingManager sharedManager] indexFolderPathForModuleName:[self name]];        
        NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                           MacSwordIndexVersion, 
                           @"MacSword Index Version", 
                           [self version], 
                           @"Sword Module Version", nil];
        [d writeToFile:[path stringByAppendingPathComponent:@"version.plist"] atomically:NO];
    }
    
    [moduleLock unlock];
}

/** abstract method */
- (void)indexContentsIntoIndex:(Indexer *)indexer {
}

@end

@implementation SwordBible(Searching)

- (void)indexContentsIntoIndex:(Indexer *)indexer {
    
	bool savePEA = swModule->isProcessEntryAttributes();
	swModule->processEntryAttributes(true);
	
    // loop over all books
    for(SwordBibleBook *bb in [self bookList]) {
        
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        const char *cref = [[bb osisName] UTF8String];
        sword::VerseKey	vk;
        sword::ListKey lk = vk.ParseVerseList(cref, vk, true);
        // iterate through keys
        for(lk = sword::TOP; !lk.Error(); lk++) {
            swModule->setKey(lk);
            const char *keyCStr = swModule->getKeyText();
            const char *txtCStr = swModule->StripText();
            NSString *key = @"";
            NSString *txt = @"";
            key = [NSString stringWithUTF8String:keyCStr];
            txt = [NSString stringWithUTF8String:txtCStr];
            NSString *keyIndex = [SwordModule indexOfVerseKey:(sword::VerseKey *)swModule->getKey()];
            
            NSMutableDictionary *propDict = [NSMutableDictionary dictionaryWithCapacity:2];
            if(key == nil) {
                MBLOG(MBLOG_WARN, @"[SwordBible -indexContentsIntoIndex:] key = nil!");
                key = @"";
            }
            if(txt == nil) {
                MBLOG(MBLOG_WARN, @"[SwordBible -indexContentsIntoIndex:] txt = nil!");
                txt = @"";
            }
            
            // additionally save content and key string
            [propDict setObject:txt forKey:IndexPropSwordKeyContent];
            [propDict setObject:key forKey:IndexPropSwordKeyString];                
            
            // build "strong" field
            sword::SWBuf strong;
            sword::AttributeTypeList::iterator words;
            sword::AttributeList::iterator word;
            sword::AttributeValue::iterator strongVal;        
            // what the heck is going on here
            words = swModule->getEntryAttributes().find("Word");
            if (words != swModule->getEntryAttributes().end()) {
                for (word = words->second.begin();word != words->second.end(); word++) {
                    strongVal = word->second.find("Lemma");
                    if (strongVal != word->second.end()) {
                        // cheeze.  skip empty article tags that weren't assigned to any text
                        if (strongVal->second == "G3588") {
                            if (word->second.find("Text") == word->second.end())
                                continue;	// no text? let's skip
                        }
                        strong.append(strongVal->second);
                        strong.append(' ');
                    }
                }
            }
            
            NSMutableString *strongStr = [NSMutableString string];
            if(strong.length() > 0) {
                [strongStr appendString:[NSString stringWithUTF8String:strong.c_str()]];
                [strongStr replaceOccurrencesOfString:@"|x-Strongs:" withString:@" " options:0 range:NSMakeRange(0, [strongStr length])];
                
                // also add to dictionary
                [propDict setObject:strongStr forKey:IndexPropSwordStrongString];
            }
                
            if([txt length] > 0 && [strongStr length] > 0) {
                // index combined with strongs
                NSString *indexContent = [NSString stringWithFormat:@"%@ - %@", txt, strongStr];
                
                // add to index
                [indexer addDocument:keyIndex text:indexContent textType:ContentTextType storeDict:propDict];                
            }
        }
        
		[pool drain];        
    }

	swModule->processEntryAttributes(savePEA);	
}

@end

@implementation SwordDictionary(Searching)

- (void)indexContentsIntoIndex:(Indexer *)indexer {
    
    // get all dict entries
    for(NSString *key in [self allKeys]) {
        NSString *entry = [self entryForKey:key];
        
        if(entry != nil) {
            NSMutableDictionary *propDict = [NSMutableDictionary dictionaryWithCapacity:2];
            // additionally save content
            [propDict setObject:entry forKey:IndexPropSwordKeyContent];
            [propDict setObject:key forKey:IndexPropSwordKeyString];
            
            if([entry length] > 0) {
                // let's add the key also into the searchable content
                NSString *indexContent = [NSString stringWithFormat:@"%@ - %@", key, entry];
                // add content
                [indexer addDocument:key text:indexContent textType:ContentTextType storeDict:propDict];                
            }
        }
    }
}

@end

@implementation SwordBook(Searching)

- (void)indexContentsIntoIndex:(Indexer *)indexer {
    // we start at root
	[self indexContents:nil intoIndex:indexer];
}

- (void)indexContents:(NSString *)treeKey intoIndex:(Indexer *)indexer {
    
    SwordTreeEntry *entry = [(SwordBook *)self treeEntryForKey:treeKey];
    for(NSString *key in [entry content]) {
        
        // get key
        NSArray *stripedAr = [(SwordBook *)self stripedTextForRef:key];
        if(stripedAr != nil) {
            // get content
            NSString *stripped = [(NSDictionary *)[stripedAr objectAtIndex:0] objectForKey:SW_OUTPUT_TEXT_KEY];
            // define properties
            NSMutableDictionary *propDict = [NSMutableDictionary dictionaryWithCapacity:2];
            // additionally save content
            [propDict setObject:stripped forKey:IndexPropSwordKeyContent];
            [propDict setObject:key forKey:IndexPropSwordKeyString];
            
            if([stripped length] > 0) {
                // let's add the key also into the searchable content
                NSString *indexContent = [NSString stringWithFormat:@"%@ - %@", key, stripped];
                
                // add content with key
                [indexer addDocument:key text:indexContent textType:ContentTextType storeDict:propDict];                
            }
        }

        // go deeper
        [self indexContents:key intoIndex:indexer];
	}
}

@end
