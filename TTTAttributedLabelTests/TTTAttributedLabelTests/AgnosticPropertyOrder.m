//
//  AgnosticPropertyOrder.m
//  TTTAttributedLabelTests
//
//  Created by Mark Makdad on 12/19/11.
//  Copyright (c) 2011 Long Weekend LLC. All rights reserved.
//

#import "AgnosticPropertyOrder.h"

@implementation AgnosticPropertyOrder
@synthesize ourLabel;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
  
  // self.ourLabel.text = @"Text set in code, color green.";
    self.ourLabel.textColor = [UIColor greenColor];
}

#pragma mark - IBActions

- (IBAction)changeColor:(id)sender {
    self.ourLabel.textColor = [UIColor blueColor];
}

- (IBAction)changeText:(id)sender {
    self.ourLabel.text = @"Properties should stay";
}

- (IBAction)changeFont:(id)sender {
    self.ourLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
}

#pragma mark - Class Plumbing

- (void)viewDidUnload
{
  [self setOurLabel:nil];
  [super viewDidUnload];
}

- (void)dealloc {
  [ourLabel release];
  [super dealloc];
}


@end
