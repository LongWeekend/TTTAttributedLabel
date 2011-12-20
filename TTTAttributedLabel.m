// TTTAttributedLabel.m
//
// Copyright (c) 2011 Mattt Thompson (http://mattt.me)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "TTTAttributedLabel.h"

#define kTTTLineBreakWordWrapTextWidthScalingFactor (M_PI / M_E)

static inline CGPoint CGPointConvertFromCoreTextPointInRect(CGPoint point, CGRect rect) {
  // e.g. rect: (0,0),(100,200).  CGPoint (80,130) in CoreText (bottom left origin) would be 
  // CGPoint(80,70) in iOS (top left origin) coords.
  return CGPointMake(point.x, rect.size.height - point.y);
}

static inline CGPoint CGPointConvertToCoreTextPointInRect(CGPoint point, CGRect rect) {
  // Magically, these functions are inverse, so you can actually use the same function to toggle between.
  return CGPointConvertFromCoreTextPointInRect(point, rect);
}

static inline CTTextAlignment CTTextAlignmentFromUITextAlignment(UITextAlignment alignment) {
	switch (alignment) {
		case UITextAlignmentLeft: return kCTLeftTextAlignment;
		case UITextAlignmentCenter: return kCTCenterTextAlignment;
		case UITextAlignmentRight: return kCTRightTextAlignment;
		default: return kCTNaturalTextAlignment;
	}
}

static inline CTLineBreakMode CTLineBreakModeFromUILineBreakMode(UILineBreakMode lineBreakMode) {
	switch (lineBreakMode) {
		case UILineBreakModeWordWrap: return kCTLineBreakByWordWrapping;
		case UILineBreakModeCharacterWrap: return kCTLineBreakByCharWrapping;
		case UILineBreakModeClip: return kCTLineBreakByClipping;
		case UILineBreakModeHeadTruncation: return kCTLineBreakByTruncatingHead;
		case UILineBreakModeTailTruncation: return kCTLineBreakByTruncatingTail;
		case UILineBreakModeMiddleTruncation: return kCTLineBreakByTruncatingMiddle;
		default: return 0;
	}
}

static inline NSTextCheckingType NSTextCheckingTypeFromUIDataDetectorType(UIDataDetectorTypes dataDetectorType) {
    NSTextCheckingType textCheckingType = 0;
    if (dataDetectorType & UIDataDetectorTypeAddress) {
        textCheckingType |= NSTextCheckingTypeAddress;
    }
    
    if (dataDetectorType & UIDataDetectorTypeCalendarEvent) {
        textCheckingType |= NSTextCheckingTypeDate;
    }
    
    if (dataDetectorType & UIDataDetectorTypeLink) {
        textCheckingType |= NSTextCheckingTypeLink;
    }
    
    if (dataDetectorType & UIDataDetectorTypePhoneNumber) {
        textCheckingType |= NSTextCheckingTypePhoneNumber;
    }
    
    return textCheckingType;
}

static inline NSDictionary * NSAttributedStringAttributesFromLabel(TTTAttributedLabel *label) {
    NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionary]; 
    
    CTFontRef font = CTFontCreateWithName((CFStringRef)label.font.fontName, label.font.pointSize, NULL);
    [mutableAttributes setObject:(id)font forKey:(NSString *)kCTFontAttributeName];
    CFRelease(font);
    
    [mutableAttributes setObject:(id)[label.textColor CGColor] forKey:(NSString *)kCTForegroundColorAttributeName];
    
    CTTextAlignment alignment = CTTextAlignmentFromUITextAlignment(label.textAlignment);
    // REVIEW: Mark Makdad - Dec 17 2011 - This line doesn't do exactly what UILabel does with this info.  It should only
    // be applied to the last line if numLines = 0
    CTLineBreakMode lineBreakMode = CTLineBreakModeFromUILineBreakMode(label.lineBreakMode);
    CGFloat lineSpacing = label.leading;
    CGFloat lineHeightMultiple = label.lineHeightMultiple;
    CGFloat topMargin = label.textInsets.top;
    CGFloat bottomMargin = label.textInsets.bottom;
    CGFloat leftMargin = label.textInsets.left;
    CGFloat rightMargin = label.textInsets.right;
    CGFloat firstLineIndent = label.firstLineIndent + leftMargin;
    CTParagraphStyleSetting paragraphStyles[9] = {
		{.spec = kCTParagraphStyleSpecifierAlignment, .valueSize = sizeof(CTTextAlignment), .value = (const void *)&alignment},
        {.spec = kCTParagraphStyleSpecifierLineBreakMode, .valueSize = sizeof(CTLineBreakMode), .value = (const void *)&lineBreakMode},
        {.spec = kCTParagraphStyleSpecifierLineSpacing, .valueSize = sizeof(CGFloat), .value = (const void *)&lineSpacing},
        {.spec = kCTParagraphStyleSpecifierLineHeightMultiple, .valueSize = sizeof(CGFloat), .value = (const void *)&lineHeightMultiple},
        {.spec = kCTParagraphStyleSpecifierFirstLineHeadIndent, .valueSize = sizeof(CGFloat), .value = (const void *)&firstLineIndent},
        {.spec = kCTParagraphStyleSpecifierParagraphSpacingBefore, .valueSize = sizeof(CGFloat), .value = (const void *)&topMargin},
        {.spec = kCTParagraphStyleSpecifierParagraphSpacing, .valueSize = sizeof(CGFloat), .value = (const void *)&bottomMargin},
        {.spec = kCTParagraphStyleSpecifierHeadIndent, .valueSize = sizeof(CGFloat), .value = (const void *)&leftMargin},
        {.spec = kCTParagraphStyleSpecifierTailIndent, .valueSize = sizeof(CGFloat), .value = (const void *)&rightMargin},
	};
	CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(paragraphStyles, 9);
	[mutableAttributes setObject:(id)paragraphStyle forKey:(NSString *)kCTParagraphStyleAttributeName];
	CFRelease(paragraphStyle);
    
    return [NSDictionary dictionaryWithDictionary:mutableAttributes];
}

@interface TTTAttributedLabel ()
@property (readwrite, nonatomic, copy) NSAttributedString *attributedText;
@property (readwrite, nonatomic, copy) NSAttributedString *resizedAttributedText; 
@property (readwrite, nonatomic, assign) CTFramesetterRef framesetter;
@property (readwrite, nonatomic, assign) CTFramesetterRef highlightFramesetter;
@property (readwrite, nonatomic, retain) NSDataDetector *dataDetector;
@property (readwrite, nonatomic, retain) NSArray *links;
@property (readwrite, nonatomic, retain) UITapGestureRecognizer *tapGestureRecognizer;

- (void)commonInit;
- (void)setNeedsFramesetter;
- (NSMutableAttributedString *) inheritedAttributedString;
- (CFRange) fullTextCFRange;
- (void)detectLinksInString:(NSString *)text;
- (NSArray *)detectedLinksInString:(NSString *)string range:(NSRange)range error:(NSError **)error;
- (void)addLinkWithTextCheckingResult:(NSTextCheckingResult *)result;
- (NSTextCheckingResult *)linkAtCharacterIndex:(CFIndex)idx;
- (NSTextCheckingResult *)linkAtPoint:(CGPoint)p;
- (NSUInteger)characterIndexAtPoint:(CGPoint)p;
- (void)drawFramesetter:(CTFramesetterRef)framesetter textRange:(CFRange)textRange inRect:(CGRect)rect context:(CGContextRef)c;
- (NSAttributedString *) attributedTextToDisplay;
- (CGFloat) fontScaleFactor;
@end

@implementation TTTAttributedLabel
@dynamic text;
@synthesize attributedText = _attributedText;
@synthesize resizedAttributedText = _resizedAttributedText;
@synthesize framesetter = _framesetter;
@synthesize highlightFramesetter = _highlightFramesetter;
@synthesize delegate = _delegate;
@synthesize dataDetectorTypes = _dataDetectorTypes;
@synthesize dataDetector = _dataDetector;
@synthesize links = _links;
@synthesize linkAttributes = _linkAttributes;
@synthesize shadowRadius = _shadowRadius;
@synthesize leading = _leading;
@synthesize lineHeightMultiple = _lineHeightMultiple;
@synthesize firstLineIndent = _firstLineIndent;
@synthesize textInsets = _textInsets;
@synthesize verticalAlignment = _verticalAlignment;
@synthesize tapGestureRecognizer = _tapGestureRecognizer;
@synthesize shouldResizeMultilineTextToFit = _shouldResizeMultilineTextToFit;

#pragma mark - Class Plumbing

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    
    [self commonInit];
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }
    
    [self commonInit];
    
    // TODO: This line is still a bit of a hack but it's what creates attributedText out of text stored in a nib.
    self.text = self.text;
    
    return self;
}

- (void)commonInit {
    self.dataDetectorTypes = UIDataDetectorTypeNone;
    self.links = [NSArray array];
    
    NSMutableDictionary *mutableLinkAttributes = [NSMutableDictionary dictionary];
    [mutableLinkAttributes setValue:(id)[[UIColor blueColor] CGColor] forKey:(NSString*)kCTForegroundColorAttributeName];
    [mutableLinkAttributes setValue:[NSNumber numberWithBool:YES] forKey:(NSString *)kCTUnderlineStyleAttributeName];
    self.linkAttributes = [NSDictionary dictionaryWithDictionary:mutableLinkAttributes];
    
    self.textInsets = UIEdgeInsetsZero;
    
    self.userInteractionEnabled = YES;
    self.tapGestureRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)] autorelease];
    [self.tapGestureRecognizer setDelegate:self];
    [self addGestureRecognizer:self.tapGestureRecognizer];
}

- (void)dealloc {
    if (_framesetter) CFRelease(_framesetter);
    if (_highlightFramesetter) CFRelease(_highlightFramesetter);
    
    [_attributedText release];
    [_resizedAttributedText release];
    [_dataDetector release];
    [_links release];
    [_linkAttributes release];
    [_tapGestureRecognizer release];
    [super dealloc];
}

#pragma mark - Setters & Getters

- (void)setResizedAttributedText:(NSAttributedString *)text {
    // Quick return on re-nil'ing, same text as before
    BOOL isNil = (self.resizedAttributedText == nil && text == nil);
    BOOL isSame = ([text isEqualToAttributedString:self.resizedAttributedText]);
    if (isNil || isSame) {
        return;
    }
  
    [_resizedAttributedText release];
    _resizedAttributedText = [text copy];
    
    [self setNeedsFramesetter];
}

- (void)setNeedsFramesetter {
    _needsFramesetter = YES;
}

- (CTFramesetterRef)framesetter {
    // If we have been explicitly instructed to recreate, or we don't have one, make a new framesetter
    if (_needsFramesetter || _framesetter == nil) {
        @synchronized(self) {
            if (_framesetter) CFRelease(_framesetter);

            // self.inheritedAttributedString muxes the label's properties with the attributed text set by the user,
            // with the latter taking priority in case of a conflict
            self.framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.inheritedAttributedString);
          
            // _needsFramesetter was set to YES because something changed; clear our cached highlight one as well.
            if (_highlightFramesetter) CFRelease(_highlightFramesetter);
            self.highlightFramesetter = nil;
          
            _needsFramesetter = NO;
        }
    }
    return _framesetter;
}

- (CTFramesetterRef)highlightFramesetter {
    if (self.highlightedTextColor == nil) {
        [NSException raise:NSInternalInconsistencyException format:@"Cannot call -highlightFramesetter w/o setting a highlightedTextColor"];
    }
  
    if (_highlightFramesetter == nil) {
        @synchronized(self) {
            // This method muxes the label's properties with the attributed text set by the user
            NSMutableAttributedString *attrString = self.inheritedAttributedString;
          
            // Add the highlighted text color - overriding everything (label settings, attr string settings)
            [attrString addAttribute:(NSString *)kCTForegroundColorAttributeName value:(id)[self.highlightedTextColor CGColor] range:NSMakeRange(0, attrString.length)];
            self.highlightFramesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attrString);
        }
    }
    return _highlightFramesetter;
}

#pragma mark - Public Methods

- (void)setDataDetectorTypes:(UIDataDetectorTypes)dataDetectorTypes {
    [self willChangeValueForKey:@"dataDetectorTypes"];
    _dataDetectorTypes = dataDetectorTypes;
    [self didChangeValueForKey:@"dataDetectorTypes"];
    
    if (self.dataDetectorTypes != UIDataDetectorTypeNone) {
        self.dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeFromUIDataDetectorType(self.dataDetectorTypes) error:nil];
      
        // Now re-parse our links, since we are detecting types now
        [self detectLinksInString:self.text];
    }
}

- (void)detectLinksInString:(NSString *)text {
    self.links = [NSArray array];
    if (self.dataDetectorTypes != UIDataDetectorTypeNone) {
        NSArray *detectedLinks = [self detectedLinksInString:text range:NSMakeRange(0, [text length]) error:nil];
        for (NSTextCheckingResult *result in detectedLinks) {
            [self addLinkWithTextCheckingResult:result];
        }
    }
}

- (NSArray *)detectedLinksInString:(NSString *)string range:(NSRange)range error:(NSError **)error {
    if (!string || !self.dataDetector) {
        return [NSArray array];
    }
    
    NSMutableArray *mutableLinks = [NSMutableArray array];
    [self.dataDetector enumerateMatchesInString:string options:0 range:range usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [mutableLinks addObject:result];
    }];
    
    return (NSArray *)mutableLinks;
}

- (void)addLinkWithTextCheckingResult:(NSTextCheckingResult *)result attributes:(NSDictionary *)attributes {
    self.links = [self.links arrayByAddingObject:result];
    
    if (attributes) {
        NSMutableAttributedString *mutableAttributedString = [[[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText] autorelease];
        [mutableAttributedString addAttributes:attributes range:result.range];
        self.text = mutableAttributedString;
    }
}

- (void)addLinkWithTextCheckingResult:(NSTextCheckingResult *)result {
    [self addLinkWithTextCheckingResult:result attributes:self.linkAttributes];
}

- (void)addLinkToURL:(NSURL *)url withRange:(NSRange)range {
    [self addLinkWithTextCheckingResult:[NSTextCheckingResult linkCheckingResultWithRange:range URL:url]];
}

- (void)addLinkToAddress:(NSDictionary *)addressComponents withRange:(NSRange)range {
    [self addLinkWithTextCheckingResult:[NSTextCheckingResult addressCheckingResultWithRange:range components:addressComponents]];
}

- (void)addLinkToPhoneNumber:(NSString *)phoneNumber withRange:(NSRange)range {
    [self addLinkWithTextCheckingResult:[NSTextCheckingResult phoneNumberCheckingResultWithRange:range phoneNumber:phoneNumber]];
}

- (void)addLinkToDate:(NSDate *)date withRange:(NSRange)range {
    [self addLinkWithTextCheckingResult:[NSTextCheckingResult dateCheckingResultWithRange:range date:date]];
}

- (void)addLinkToDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone duration:(NSTimeInterval)duration withRange:(NSRange)range {
    [self addLinkWithTextCheckingResult:[NSTextCheckingResult dateCheckingResultWithRange:range date:date timeZone:timeZone duration:duration]];
}

#pragma mark - Private Methods

- (NSMutableAttributedString *) inheritedAttributedString {
    // Get the original string
    NSAttributedString *originalAttrString = [self attributedTextToDisplay];
    NSRange fullRange = NSMakeRange(0,[originalAttrString length]);
    
    // Initialize a new mutable attributed string & add the label's attributes to it
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:[originalAttrString string]];
    [attrString addAttributes:NSAttributedStringAttributesFromLabel(self) range:fullRange];
    
    // Now add the original attributed text's attributes on top (override) the UILabel options
    [originalAttrString enumerateAttributesInRange:fullRange options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        [attrString addAttributes:attrs range:range];
    }];
    return [attrString autorelease];
}

- (CFRange) fullTextCFRange {
    return CFRangeMake(0, [[self text] length]);
}

- (NSTextCheckingResult *)linkAtCharacterIndex:(CFIndex)idx {
    for (NSTextCheckingResult *result in self.links) {
        NSRange range = result.range;
        if (range.location <= idx && idx <= range.location + range.length) {
            return result;
        }
    }
    
    return nil;
}

- (NSTextCheckingResult *)linkAtPoint:(CGPoint)p {
    // Don't do anything if there are no links.
    if ([self.links count] == 0) {
        return nil;
    }
  
    CFIndex idx = [self characterIndexAtPoint:p];
    return [self linkAtCharacterIndex:idx];
}

- (NSUInteger)characterIndexAtPoint:(CGPoint)p {
    // Quick return if point isn't in this view's bounds
    if (!CGRectContainsPoint(self.bounds, p)) {
        return NSNotFound;
    }
    
    // Quick return if point is outside of rect used for drawing text
    CGRect textRect = [self textRectForBounds:self.bounds limitedToNumberOfLines:self.numberOfLines];
    if (!CGRectContainsPoint(textRect, p)) {
        return NSNotFound;
    }
  
    // OK, convert tap coordinates (origin at top left) to CT coordinates (origin at bottom left)
    CGPoint coreTextPoint = CGPointConvertToCoreTextPointInRect(p, textRect);
    
    CFIndex idx = NSNotFound;
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, textRect);
    CTFrameRef frame = CTFramesetterCreateFrame(self.framesetter, [self fullTextCFRange], path, NULL);
    CFArrayRef lines = CTFrameGetLines(frame);
    NSUInteger numberOfLines = CFArrayGetCount(lines);
    CGPoint lineOrigins[numberOfLines];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), lineOrigins);
    NSUInteger lineIndex;
  
    // Loop through each line of text to find out which line the point would be located in
    for (lineIndex = 0; lineIndex < (numberOfLines - 1); lineIndex++) {
        CGPoint lineOrigin = lineOrigins[lineIndex];
        if (lineOrigin.y < coreTextPoint.y) {
            break;
        }
    }

    // Convert CT coordinates to line-relative coordinates
    CGPoint lineOrigin = lineOrigins[lineIndex];
    CGPoint relativePoint = CGPointMake(coreTextPoint.x - lineOrigin.x, coreTextPoint.y - lineOrigin.y);
  
    // And now finally get the index of the character
    CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
    idx = CTLineGetStringIndexForPosition(line, relativePoint);
    
    CFRelease(frame);
    CFRelease(path);
        
    return idx;
}

- (void)drawFramesetter:(CTFramesetterRef)framesetter textRange:(CFRange)textRange inRect:(CGRect)rect context:(CGContextRef)c {
    CGMutablePathRef path = CGPathCreateMutable();
    
    CGPathAddRect(path, NULL, rect);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, textRange, path, NULL);    
    
    if (self.numberOfLines == 0) {
        // Draw the whole frame; we don't care if it doesn't fit or not; numLines = 0 is "best effort"
        CTFrameDraw(frame, c);
    } else {
        CFArrayRef lines = CTFrameGetLines(frame);
        NSUInteger numberOfLines = MIN(self.numberOfLines, CFArrayGetCount(lines));

        CGPoint lineOrigins[numberOfLines];
        CTFrameGetLineOrigins(frame, CFRangeMake(0, numberOfLines), lineOrigins);
        
        for (NSUInteger lineIndex = 0; lineIndex < numberOfLines; lineIndex++) {
            CGPoint lineOrigin = lineOrigins[lineIndex];
            // The lineOrigin values provided by CTFrameGetLineOrigins will be based in CoreText's
            // coordinate system; we are now drawing in an iOS context.  Adding rect.origin.y makes
            // the verticalAlignment positioning work as expected.  In addition, the glyphs will
            // actually be drawn upside down, but we've applied a CTM transform to the context in drawTextInRect:
            CGContextSetTextPosition(c, lineOrigin.x, lineOrigin.y + rect.origin.y);
            CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
            CTLineDraw(line, c);
        }
    }
    
    CFRelease(frame);
    CFRelease(path);
}

- (NSAttributedString *) attributedTextToDisplay {
  if (self.resizedAttributedText) {
      return self.resizedAttributedText;
  } else {
      return self.attributedText;
  }
}

- (CGFloat) fontScaleFactor {
    CGFloat scaleFactor = 1.0f;
    if (self.numberOfLines == 1 && self.adjustsFontSizeToFitWidth) {
        // This behavior matches the UILabel's behavior
        CGFloat textWidth = [self sizeThatFits:CGSizeZero].width;
        if ((textWidth > self.frame.size.width) && (textWidth > 0.0f)) {
            scaleFactor = (self.frame.size.width / textWidth);
        }
    } else if (self.numberOfLines > 1 && self.shouldResizeMultilineTextToFit) {
        // shouldResizeMultilineTextToFit is a bool on this class that enables more funky text layouts
        CGFloat textWidth = [self sizeThatFits:CGSizeZero].width;
        CGFloat availableWidth = self.frame.size.width * self.numberOfLines;
        if (self.lineBreakMode == UILineBreakModeWordWrap) {
            // Can someone explain what this magic sauce does?
            textWidth *= kTTTLineBreakWordWrapTextWidthScalingFactor;
        }
        if ((textWidth > availableWidth) && (textWidth > 0.0f)) {
            scaleFactor = (availableWidth / textWidth);
        }
    }
    return scaleFactor;
}

#pragma mark - UILabel

- (void)setText:(id)text {
    // If the user passed a string, call this setter again passing a blank attributed string
    if ([text isKindOfClass:[NSString class]]) {
        NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:text];
        [self setText:[attrString autorelease]];
        return;
    }
    else if ([text isKindOfClass:[NSAttributedString class]] == NO) {
        [NSException raise:NSGenericException format:@"setText: only receives NSString or NSAttributedString instances."];
    }
    
    // If it's the same string as before, quick return
    if ([text isEqualToAttributedString:self.attributedText]) {
        return;
    }
    
    // Actually update the value, with KVC calls in case anyone cares (but this property isn't publicly exposed?)
    [self willChangeValueForKey:@"attributedText"];
    [_attributedText release];
    _attributedText = [text copy];
    [self didChangeValueForKey:@"attributedText"];
    
    [self setNeedsFramesetter];
    [self detectLinksInString:[text string]];
    [super setText:[text string]];
}

// When UILabel properties change, our "muxed" attributed string may also change; reset the framesetter
- (void)setFont:(UIFont *)font {
    [super setFont:font];
    [self setNeedsFramesetter];
}

- (void)setTextColor:(UIColor *)textColor {
    [super setTextColor:textColor];
    [self setNeedsFramesetter];
}

- (void)setHighlightedTextColor:(UIColor *)highlightedTextColor {
    [super setHighlightedTextColor:highlightedTextColor];
    [self setNeedsFramesetter];
}

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines {
    // By default, the text will take the full bounds
    CGRect textRect = bounds;

    // Check the text size to see if the above assumption is reasonable
    CFRange fitRange;
    CGSize textSize = CTFramesetterSuggestFrameSizeWithConstraints(self.framesetter, [self fullTextCFRange], NULL, bounds.size, &fitRange);

    // If the textRect is larger than the suggested size, we will have open space, so alignment begins to matter.
    if (textSize.height < bounds.size.height) {
        CGFloat yOffset = 0.0f;
        switch (self.verticalAlignment) {
            case TTTAttributedLabelVerticalAlignmentTop:
                // CoreText's coordinate y-axis is backwards from iOS, so "top of bounds" means having an offset (starting from bottom)
                yOffset = (bounds.size.height - textSize.height);
                break;
            case TTTAttributedLabelVerticalAlignmentCenter:
                yOffset = (bounds.size.height - textSize.height) / 2.0f;
                break;
            case TTTAttributedLabelVerticalAlignmentBottom:
                break;
        }
        
        textRect.origin = CGPointMake(bounds.origin.x, ceilf(bounds.origin.y + yOffset));
        textRect.size = CGSizeMake(bounds.size.width, ceilf(textSize.height));
    }
    return textRect;
}


- (NSAttributedString *)resizeAttributedText:(NSAttributedString *)attributedString withScale:(CGFloat)scale {
  NSMutableAttributedString *mutableAttributedString = [[attributedString mutableCopy] autorelease];
  [mutableAttributedString enumerateAttribute:(NSString *)kCTFontAttributeName inRange:NSMakeRange(0, [mutableAttributedString length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
    CTFontRef font = (CTFontRef)value;
    if (font) {
      CGFloat scaledFontSize = floorf(CTFontGetSize(font) * scale);
      CTFontRef scaledFont = CTFontCreateCopyWithAttributes(font, fmaxf(scaledFontSize, self.minimumFontSize), NULL, NULL);
      CFAttributedStringSetAttribute((CFMutableAttributedStringRef)mutableAttributedString, CFRangeMake(range.location, range.length), kCTFontAttributeName, scaledFont);
      CFRelease(scaledFont);
    } else {
      // TODO: add a font with the size that fits
    }
  }];
  return mutableAttributedString;
}

- (void)drawTextInRect:(CGRect)rect {
    // Get the graphics context and push the state so we are a good CoreGraphics citizen
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSaveGState(c);

    // Inverts the CTM to match iOS coordinates - otherwise text draws upside-down.
    // CoreText's (from Mac OSX) system is different)
    CGContextSetTextMatrix(c, CGAffineTransformIdentity);
    CGContextTranslateCTM(c, rect.origin.x, rect.origin.y);
    CGContextScaleCTM(c, 1.0f, -1.0f);
    CGContextTranslateCTM(c, rect.origin.x, - (rect.origin.y + rect.size.height));
    
    // If we have a font scale != 1.0f, adjust the font size to fit width.
    CGFloat fontScaleFactor = [self fontScaleFactor];
    if (fontScaleFactor < 1.0f) {
        self.resizedAttributedText = [self resizeAttributedText:self.attributedText withScale:fontScaleFactor];
    } else {
        self.resizedAttributedText = nil;
    }
  
    // First, re-position the rect of the text to match the vertical alignment setting.
    CFRange range = [self fullTextCFRange];
    CGRect textRect = [self textRectForBounds:rect limitedToNumberOfLines:self.numberOfLines];
  
    // Second, trace the shadow before the actual text, if we have one
    if (self.shadowColor && !self.highlighted) {
        CGContextSetShadowWithColor(c, self.shadowOffset, self.shadowRadius, [self.shadowColor CGColor]);
    }
    
    // Finally, draw the text or highlighted text itself
    if (self.highlightedTextColor && self.highlighted) {
        [self drawFramesetter:self.highlightFramesetter textRange:range inRect:textRect context:c];
    } else {
        [self drawFramesetter:self.framesetter textRange:range inRect:textRect context:c];
    }  
    CGContextRestoreGState(c);
}

#pragma mark - UIView

- (CGSize)sizeThatFits:(CGSize)size {    
    CFRange rangeToSize = [self fullTextCFRange];
    
    // Default constraint (numberOfLines = 0) -- fixed width, but infinite height
    CGSize constraints = CGSizeMake(size.width, CGFLOAT_MAX);
    
    if (self.numberOfLines == 1) {
        // If there is one line, the size that fits is the full width of the line
        constraints = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
    } else if (self.numberOfLines > 1) {
        // If the line count of the label more than 1, limit the range to size to the number of lines that have been set
        CGPathRef path = CGPathCreateWithRect(CGRectMake(0.0f, 0.0f, self.bounds.size.width, CGFLOAT_MAX), NULL);
        CTFrameRef frame = CTFramesetterCreateFrame(self.framesetter, CFRangeMake(0, 0), path, NULL);
        CFArrayRef lines = CTFrameGetLines(frame);
        
        if (CFArrayGetCount(lines) > 0) {
            NSInteger lastVisibleLineIndex = MIN(self.numberOfLines, CFArrayGetCount(lines)) - 1;
            CTLineRef lastVisibleLine = CFArrayGetValueAtIndex(lines, lastVisibleLineIndex);
            
            CFRange rangeToLayout = CTLineGetStringRange(lastVisibleLine);
            rangeToSize = CFRangeMake(0, rangeToLayout.location + rangeToLayout.length);
        }
        
        CFRelease(frame);
        CFRelease(path);
    }
    
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(self.framesetter, rangeToSize, NULL, constraints, NULL);
    
    return CGSizeMake(ceilf(suggestedSize.width), ceilf(suggestedSize.height));
}

#pragma mark - UIGestureRecognizer

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // In case the user adds multiple gesture recognizers on this class, we only want to pay attention to this one.
    if (gestureRecognizer == self.tapGestureRecognizer) {
        // This class can only ever receive gesture touches if attributedText (i.e. possibly a link?) is set
        return ([self linkAtPoint:[touch locationInView:self]] != nil);
    } else {
        // The default behavior for this delegate callback, if not implemented, is yes.  So we'll return that.
        return YES;
    }
}

- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer state] != UIGestureRecognizerStateEnded) {
        return;
    }
    
    NSTextCheckingResult *result = [self linkAtPoint:[gestureRecognizer locationInView:self]];
    if (!result || !self.delegate) {
        return;
    }
    
    switch (result.resultType) {
        case NSTextCheckingTypeLink:
            if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithURL:)]) {
                [self.delegate attributedLabel:self didSelectLinkWithURL:result.URL];
            }
            break;
        case NSTextCheckingTypeAddress:
            if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithAddress:)]) {
                [self.delegate attributedLabel:self didSelectLinkWithAddress:result.addressComponents];
            }
            break;
        case NSTextCheckingTypePhoneNumber:
            if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithPhoneNumber:)]) {
                [self.delegate attributedLabel:self didSelectLinkWithPhoneNumber:result.phoneNumber];
            }
            break;
        case NSTextCheckingTypeDate:
            if (result.timeZone && [self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithDate:timeZone:duration:)]) {
                [self.delegate attributedLabel:self didSelectLinkWithDate:result.date timeZone:result.timeZone duration:result.duration];
            } else if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithDate:)]) {
                [self.delegate attributedLabel:self didSelectLinkWithDate:result.date];
            }
            break;
    }
}

@end
