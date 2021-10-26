#import "CPAObserver.h"
#import "CPAManager.h"

@implementation CPAObserver

- (id)init {
    self.preferences = [[HBPreferences alloc] initWithIdentifier:@"love.litten.copypastapreferences"];
    [[self preferences] registerBool:&enableRegex default:NO forKey:@"enableRegex"];
    [[self preferences] registerObject:&regexExpression default:nil forKey:@"regexExpression"];
    [[self preferences] registerInteger:&regexType default:0 forKey:@"regexType"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pasteboardUpdated) name:UIPasteboardChangedNotification object:nil];

    return self;

}

- (void)pasteboardUpdated {

    // accessing [UIPasteboard generalPasteboard] sometimes causes another UIPasteboardChangedNotification to be sent
    // to prevent crashes due to an infinite recursion, we need to remove the observer while calling it
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSString* content = [[UIPasteboard generalPasteboard] string];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pasteboardUpdated) name:UIPasteboardChangedNotification object:nil];
    if (!content || content == nil || content == NULL) {
        return;
    }

    if ([[content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]==0) {
        return;
    }

    if (self.lastContent && [self.lastContent isEqualToString:content]) return;
    self.lastContent = content;

    NSString* appName = ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]) ?: @"";
    NSString* bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];

    if(enableRegex){
        // added NSRegularExpressionDotMatchesLineSeparators since that's the most common convention
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:regexExpression options:NSRegularExpressionDotMatchesLineSeparators error:nil];

        NSArray* matches = [regex matchesInString:content options:0 range:NSMakeRange(0, [content length])];
        NSMutableString* filteredContent =  [NSMutableString stringWithString:@""];

        // regexType can be 0, 1, 2, 3
        // 0: Save when match
        // 1: Save when not match
        // 2: Include Only Matche
        // 3: Exclude All But Matches

        // if there are no matches, the regex doesn't matter, so just add the original
        if(matches == nil || [matches count] == 0){
            if (regexType != 0) {
                [[CPAManager sharedInstance] addItem:[CPAItem itemWithContent:content title:appName bundleId:bundleIdentifier]];
            }
            return;
        }


        if(regexType == 0) {
            // 0: Save when match
            [[CPAManager sharedInstance] addItem:[CPAItem itemWithContent:content title:appName bundleId:bundleIdentifier]];
            return;
        } else if (regexType == 1) {
            // 1: Save when not match
            return;
        } else if (regexType == 2) {
            for (NSTextCheckingResult *match in matches) { // iterate through macthes and add the parts that match
                NSRange matchRange = [match range];
                [filteredContent appendString:[content substringWithRange:matchRange]];
            }
        } else {
            for (NSTextCheckingResult *match in matches) { // iterate through the matches and remove the parts that match
                NSRange matchRange = [match range];
                [filteredContent appendString:[content stringByReplacingCharactersInRange:matchRange withString:@""]];
            }
        }
        if([filteredContent length] == 0) return; // don't add anything to the list
        [[CPAManager sharedInstance] addItem:[CPAItem itemWithContent:filteredContent title:appName bundleId:bundleIdentifier]];
    } else {
        [[CPAManager sharedInstance] addItem:[CPAItem itemWithContent:content title:appName bundleId:bundleIdentifier]];
    }

}

@end