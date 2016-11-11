//
//  iCloudDocument.m
//  iCloud Document Sync
//
//  Created by iRare Media. Last updated January 2014.
//  Available on GitHub. Licensed under MIT with Attribution.
//

#import "iCloudDocument.h"

NSFileVersion *laterVersion (NSFileVersion *first, NSFileVersion *second) {
    NSDate *firstDate = first.modificationDate;
    NSDate *secondDate = second.modificationDate;
    return ([firstDate compare:secondDate] != NSOrderedDescending) ? second : first;
}

@implementation iCloudDocument

//----------------------------------------------------------------------------------------------------------------//
//------------  Document Life Cycle ------------------------------------------------------------------------------//
//----------------------------------------------------------------------------------------------------------------//
#pragma mark - Document Life Cycle

- (instancetype)initWithFileURL:(NSURL *)url {
	self = [super initWithFileURL:url];
	if (self) {
		_contents = [[NSData alloc] init];
	}
	return self;
}

- (NSString *)localizedName {
	return [self.fileURL lastPathComponent];
}

- (NSString *)stateDescription {
    if (!self.documentState) return @"Document state is normal";
    
    NSMutableString *string = [NSMutableString string];
    if ((self.documentState & UIDocumentStateNormal) != 0) [string appendString:@"Document state is normal"];
    if ((self.documentState & UIDocumentStateClosed) != 0) [string appendString:@"Document is closed"];
    if ((self.documentState & UIDocumentStateInConflict) != 0) [string appendString:@"Document is in conflict"];
    if ((self.documentState & UIDocumentStateSavingError) != 0) [string appendString:@"Document is experiencing saving error"];
    if ((self.documentState & UIDocumentStateEditingDisabled) != 0) [string appendString:@"Document editing is disbled"];
    
    return string;
}

//----------------------------------------------------------------------------------------------------------------//
//------------  Loading and Saving -------------------------------------------------------------------------------//
//----------------------------------------------------------------------------------------------------------------//
#pragma mark - Loading and Saving

- (id)contentsForType:(NSString *)typeName error:(NSError **)outError {
    if (!self.contents) {
        self.contents = [[NSData alloc] init];
    }
    
	return self.contents;
}

- (BOOL)loadFromContents:(id)fileContents ofType:(NSString *)typeName error:(NSError **)outError {
    if ([fileContents length] > 0) {
        self.contents = [[NSData alloc] initWithData:fileContents];
    } else {
        self.contents = [[NSData alloc] init];
    }
    
    return YES;
}

- (void)setDocumentData:(NSData *)newData {
    NSData *oldData = self.contents;
    self.contents = [newData copy];
        
    // Register the undo operation
    [self.undoManager setActionName:@"Data Change"];
    [self.undoManager registerUndoWithTarget:self selector:@selector(setDocumentData:) object:oldData];
}

//----------------------------------------------------------------------------------------------------------------//
//------------  Error Handling ----------------------------------------------------------------------------------//
//----------------------------------------------------------------------------------------------------------------//
#pragma mark - Loading and Saving

- (void)handleError:(NSError *)error userInteractionPermitted:(BOOL)userInteractionPermitted {
    [super handleError:error userInteractionPermitted:userInteractionPermitted];
	NSLog(@"[iCloudDocument] %@", error);
    
    if ([self.delegate respondsToSelector:@selector(iCloudDocumentErrorOccured:)]) [self.delegate iCloudDocumentErrorOccured:error];
}

- (void) accommodatePresentedItemDeletionWithCompletionHandler: (void (^) (NSError *errorOrNil)) completionHandler
{
    UIDocument* presentedDocument = self;
    [presentedDocument closeWithCompletionHandler: ^(BOOL success) {
        NSError* error = nil;
        if (!success)
        {
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"Could not close document that is being deleted on another device",
                                      NSLocalizedDescriptionKey, nil];
            error = [NSError errorWithDomain: @"some_suitable_domain"
                                        code: 101
                                    userInfo: userInfo];
        }
        
        completionHandler(error);  // run the passed in completion handler (required)
        
        dispatch_async(dispatch_get_main_queue(), ^
                       {
                           //[super accommodatePresentedItemDeletionWithCompletionHandler:completionHandler];
                           
                           NSDictionary *userInfo = [NSDictionary dictionaryWithObject:self forKey:@"document"];
                           [[NSNotificationCenter defaultCenter] postNotificationName: @"documentDeletedOnAnotherDevice"
                                                                               object: self
                                                                             userInfo: userInfo];
                       });
    }];
}
@end

