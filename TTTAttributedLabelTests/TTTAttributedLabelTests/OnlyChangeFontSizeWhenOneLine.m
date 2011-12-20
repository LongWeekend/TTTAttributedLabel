//
//  RespectMinFontSize.m
//  TTTAttributedLabelTests
//
//  Created by Mark Makdad on 12/13/11.
//  Copyright (c) 2011 Long Weekend LLC. All rights reserved.
//

#import "OnlyChangeFontSizeWhenOneLine.h"

@implementation OnlyChangeFontSizeWhenOneLine

@synthesize oneLineLabel, twoLineLabel;

- (void) dealloc {
    [oneLineLabel release];
    [twoLineLabel release];
    [super dealloc];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
  
    // Set the attributed string with no attributes
    NSAttributedString *theString = [[[NSAttributedString alloc] initWithString:self.oneLineLabel.text] autorelease];
  
    // Since our attributable string has no attributes, we would expect drawing
    // to look like the UILabel??
    self.oneLineLabel.text = theString;
    self.twoLineLabel.text = theString;
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.oneLineLabel = nil;
    self.twoLineLabel = nil;
}

@end
