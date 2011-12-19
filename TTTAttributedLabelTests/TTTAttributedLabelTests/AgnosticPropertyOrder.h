//
//  AgnosticPropertyOrder.h
//  TTTAttributedLabelTests
//
//  Created by Mark Makdad on 12/19/11.
//  Copyright (c) 2011 Long Weekend LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TTTAttributedLabel.h"

@interface AgnosticPropertyOrder : UIViewController
@property (retain, nonatomic) IBOutlet TTTAttributedLabel *ourLabel;
- (IBAction)changeColor:(id)sender;
- (IBAction)changeText:(id)sender;
- (IBAction)changeFont:(id)sender;

@end
