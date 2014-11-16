/*
    Copyright (c) 2013-2014, musictheory.net, LLC

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following condition is met:

    1. Redistributions of source code must retain the above copyright notice, this
       list of conditions and the following disclaimer. 

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
    ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "HorizontalPickerView.h"


static CGFloat sGetScaleFactor()
{
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    return [[UIScreen mainScreen] scale];
#else
    return 1.0;
#endif
}


static UIColor *sGetRGBColor(int rgb, CGFloat alpha)
{
    float r = (((rgb & 0xFF0000) >> 16) / 255.0);
    float g = (((rgb & 0x00FF00) >>  8) / 255.0);
    float b = (((rgb & 0x0000FF) >>  0) / 255.0);

    return [UIColor colorWithRed:r green:g blue:b alpha:alpha];
}


static inline CGFLOAT_TYPE sScaleFloor(CGFLOAT_TYPE x, CGFLOAT_TYPE scaleFactor)
{
    if (!scaleFactor) scaleFactor = sGetScaleFactor();
    return round(x * scaleFactor) / scaleFactor;
}


static inline CGFLOAT_TYPE sScaleCeil( CGFLOAT_TYPE x, CGFLOAT_TYPE scaleFactor)
{
    if (!scaleFactor) scaleFactor = sGetScaleFactor();
    return round(x * scaleFactor) / scaleFactor;
}


@interface HorizontalPickerChoiceView : UIView
@property (nonatomic, weak) HorizontalPickerView *owningPickerView;
@property (nonatomic) NSInteger index;
@end


@implementation HorizontalPickerChoiceView

- (id) initWithOwningPickerView:(HorizontalPickerView *)view
{
    if ((self = [super init])) {
        _index = NSNotFound;
    }
    
    return self;
}


- (void) setNeedsDisplay
{
    [[self layer] setNeedsDisplay];
}


- (void) displayLayer:(CALayer *)layer
{
    HorizontalPickerView *picker = _owningPickerView;
    UIImage *image = [[picker delegate] pickerView:picker imageForChoiceAtIndex:_index];
    
    [layer setContentsScale:[image scale]];
    [layer setContents:(id)[image CGImage]];
    [layer setContentsGravity:kCAGravityCenter];
    [layer setAnchorPoint:CGPointMake(0.5, 0.5)];
    [layer setDoubleSided:NO];
}

@end



@interface HorizontalPickerView () <UIScrollViewDelegate>
@end


@implementation HorizontalPickerView {
    UIScrollView *_scrollView;
    UIView       *_backContainer;
    UIView       *_frontContainer;

    NSArray      *_choiceViews;
    NSInteger     _numberOfChoices;
    NSInteger     _selectedIndex;
    
    NSInteger     _frontIndex;
    BOOL          _needsReload;

    HorizontalPickerChoiceView *_frontLeftView;
    HorizontalPickerChoiceView *_frontRightView;

    UIView       *_coverLeftLine;
    UIView       *_coverRightLine;
}


- (void) _commonInit
{
    _backContainer = [[UIView alloc] initWithFrame:[self bounds]];
    [_backContainer setUserInteractionEnabled:NO];
    [self addSubview:_backContainer];

    _frontContainer = [[UIView alloc] initWithFrame:[self bounds]];
    [_frontContainer setUserInteractionEnabled:NO];
    [_frontContainer setClipsToBounds:YES];
    [_frontContainer setOpaque:YES];
    [_frontContainer setBackgroundColor:[UIColor whiteColor]];
    [self addSubview:_frontContainer];

    _scrollView = [[UIScrollView alloc] initWithFrame:[self bounds]];
    [_scrollView setShowsHorizontalScrollIndicator:NO];
    [_scrollView setShowsVerticalScrollIndicator:NO];
    [_scrollView setDelegate:self];

    _coverLeftLine = [[UIView alloc] initWithFrame:CGRectZero];
    [self addSubview:_coverLeftLine];

    _coverRightLine = [[UIView alloc] initWithFrame:CGRectZero];
    [self addSubview:_coverRightLine];
    
    _frontLeftView = [[HorizontalPickerChoiceView alloc] initWithFrame:CGRectZero];
    [_frontLeftView setUserInteractionEnabled:NO];
    [_frontLeftView setOwningPickerView:self];
    [_frontContainer addSubview:_frontLeftView];

    _frontRightView = [[HorizontalPickerChoiceView alloc] initWithFrame:CGRectZero];
    [_frontRightView setUserInteractionEnabled:NO];
    [_frontRightView setOwningPickerView:self];
    [_frontContainer addSubview:_frontRightView];
    
    [_coverLeftLine  setBackgroundColor:sGetRGBColor(0xc8c7cc, 1.0)];
    [_coverRightLine setBackgroundColor:sGetRGBColor(0xc8c7cc, 1.0)];
    
    [_coverLeftLine  setUserInteractionEnabled:NO];
    [_coverRightLine setUserInteractionEnabled:NO];

    [self addSubview:_scrollView];

    _needsReload = YES;
}


- (id) initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self _commonInit];
    }

    return self;
}



- (id) initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self _commonInit];
    }

    return self;
}


- (void) dealloc
{
    [self _removeAllChoiceViews];
}


- (void) layoutSubviews
{
    [super layoutSubviews];
    
    CGRect selfBounds = [self bounds];
    
    NSInteger savedSelectedIndex = _selectedIndex;
    NSInteger savedFrontIndex    = _frontIndex;

    [_scrollView    setFrame:selfBounds];
    [_backContainer setFrame:selfBounds];
    
    if (_needsReload) {
        [self _reload];
        _needsReload = NO;
    }

    CGFloat pointsPerChoice = [self _pointsPerChoice];

    [_frontContainer setFrame:CGRectMake((selfBounds.size.width / 2) - (pointsPerChoice / 2), 0, pointsPerChoice, selfBounds.size.height)];
    
    CGRect tapeBounds = UIEdgeInsetsInsetRect(selfBounds, UIEdgeInsetsZero);
    
    CGFloat width = pointsPerChoice * _numberOfChoices;
    CGFloat extraSpace = round((selfBounds.size.width - pointsPerChoice) / 2.0);

    [_scrollView setFrame:tapeBounds];
    [_scrollView setContentSize:CGSizeMake(width, tapeBounds.size.height)];
    [_scrollView setContentInset:UIEdgeInsetsMake(0, extraSpace, 0, extraSpace)];
    [_scrollView setContentOffset:CGPointMake([self _contentOffsetXForIndex:savedSelectedIndex], 0) animated:NO];

    CGFloat scale  = [[UIScreen mainScreen] scale];
    CGRect lineFrame = CGRectMake(0, 0, 1.0 / scale, selfBounds.size.height);
    CGFloat leftX  = sScaleCeil( (selfBounds.size.width / 2) - (pointsPerChoice / 2), scale);
    CGFloat rightX = sScaleFloor((selfBounds.size.width / 2) + (pointsPerChoice / 2), scale);
    
    lineFrame.origin.x = leftX;
    [_coverLeftLine  setFrame:lineFrame];

    lineFrame.origin.x = rightX;
    [_coverRightLine setFrame:lineFrame];
    
    _frontIndex = savedFrontIndex;
    [self _updateSublayers];
}


#pragma mark - Private Methods

- (CGFloat) _pointsPerChoice
{
    // '4.3' looks good for both 320 and 1024 pixels across.  I'm sure there is a proper
    // math way of determining this ;)
    //
    return [self bounds].size.width / 4.3;
}


- (void) _reload
{
    _numberOfChoices = [_delegate numberOfChoicesInPickerView:self];

    NSMutableArray *choiceViews = [NSMutableArray arrayWithCapacity:_numberOfChoices];

    for (NSInteger i = 0; i < _numberOfChoices; i++) {
        HorizontalPickerChoiceView *choiceView = [[HorizontalPickerChoiceView alloc] initWithFrame:CGRectZero];
        
        [choiceView setUserInteractionEnabled:NO];
        [choiceView setIndex:i];
        [choiceView setOwningPickerView:self];

        [choiceViews addObject:choiceView];
    }

    [self _removeAllChoiceViews];
    _choiceViews = choiceViews;
}


- (void) _removeAllChoiceViews
{
    [_choiceViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    _choiceViews = nil;
}


- (void) _updateSublayers
{
    CGRect  bounds = [self bounds];
    CGFloat maxX = bounds.size.width;

    CGPoint center = CGPointMake(maxX / 2, bounds.size.height / 2);

    CGFloat xOffset = [_scrollView contentOffset].x + [_scrollView contentInset].left;

    CGFloat pointsPerChoice = [self _pointsPerChoice];

    static CGFloat sWheelSegmentCount   = 12;
    static CGFloat sWheelSegmentSpacing = 0.9;
    static CGFloat sWheelSegmentVisible = 3;    // How many segments are visible to the left/right of 0

    void (^updateChoiceView)(HorizontalPickerChoiceView *, NSInteger) = ^(HorizontalPickerChoiceView *choiceView, NSInteger index) {
        CGFloat offset = index - (xOffset / pointsPerChoice);

        if ((offset < -sWheelSegmentVisible) || (offset > sWheelSegmentVisible)) {
            [choiceView setHidden:YES];

        } else {
            [choiceView setHidden:NO];

            if (![[choiceView layer] contents]) {
                [choiceView setNeedsDisplay];
                [[choiceView layer] displayIfNeeded];
            }

            CATransform3D transform = CATransform3DIdentity;
            
            CGFloat arc     = M_PI * (2.0 * sWheelSegmentSpacing);
            CGFloat radius  = bounds.size.width / 2;
            CGFloat angle   = offset / sWheelSegmentCount * arc;

            transform.m34 = (-1 / 900);

            transform = CATransform3DTranslate(transform, 0, 0, -radius);
            transform = CATransform3DRotate(transform, angle, 0, 1, 0);
            transform = CATransform3DTranslate(transform, 0, 0, radius + FLT_EPSILON);
            
            [[choiceView layer] setPosition:center];
            [[choiceView layer] setTransform:transform];

            if (![choiceView superview]) {
                [_backContainer addSubview:choiceView];
            }

            [choiceView setAlpha:pow(transform.m33, 1.5) * 0.5];
        }
    };

    void (^updateFrontView)(HorizontalPickerChoiceView *, NSInteger) = ^(HorizontalPickerChoiceView *frontView, NSInteger index) {
        if (index < _numberOfChoices && index >= 0) {
            CGFloat offset = (index * pointsPerChoice) - xOffset;
            offset -= [_frontContainer frame].origin.x;
            
            [frontView setIndex:index];
            [frontView setNeedsDisplay];
            
            [frontView setHidden:NO];
            [[frontView layer] setPosition:center];
            [[frontView layer] setTransform:CATransform3DMakeTranslation(offset, 0, 0)];

        } else {
            [frontView setHidden:YES];
        }
    };

    NSInteger i = 0;
    for (HorizontalPickerChoiceView *choiceView in _choiceViews) {
        updateChoiceView(choiceView, i++);
    }

    updateFrontView(_frontLeftView,  _frontIndex);
    updateFrontView(_frontRightView, _frontIndex + 1);
}


- (CGFloat) _contentOffsetXForIndex:(NSInteger)index
{
    CGFloat pointsPerChoice = [self _pointsPerChoice];
    return (index * pointsPerChoice) - [_scrollView contentInset].left;
}


#pragma mark - Public Methods

- (void) reload
{
    _needsReload = YES;
    [self setNeedsLayout];
}


#pragma mark - UIScrollView Delegate

- (void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat pointsPerChoice = [self _pointsPerChoice];

    CGFloat   x     = [scrollView contentOffset].x;
    NSInteger index = round((x  + [scrollView contentInset].left) / pointsPerChoice);

    if      (index < 0)                 index = 0;
    else if (index >= _numberOfChoices) index = (_numberOfChoices - 1);
    
    _frontIndex = floor((x  + [scrollView contentInset].left) / pointsPerChoice);

    BOOL sendValueChanged = NO;

    if (index != _selectedIndex) {
        sendValueChanged = YES;
        _selectedIndex = index;
    }

    [self _updateSublayers];

    if (sendValueChanged) {
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
}


- (void) scrollViewWillEndDragging: (UIScrollView *) scrollView
                      withVelocity: (CGPoint) velocity
               targetContentOffset: (inout CGPoint *) targetContentOffset
{
    CGFloat   x     = targetContentOffset->x;
    NSInteger index = round((x  + [scrollView contentInset].left) / [self _pointsPerChoice]);

    if      (index < 0)                 index = 0;
    else if (index >= _numberOfChoices) index = (_numberOfChoices - 1);

    targetContentOffset->x = [self _contentOffsetXForIndex:index];
}


#pragma mark - Accessors

- (void) setSelectedIndex:(NSInteger)index animated:(BOOL)animated
{
    if (_selectedIndex != index) {
        _selectedIndex = index;
        [_scrollView setContentOffset:CGPointMake([self _contentOffsetXForIndex:_selectedIndex], 0) animated:animated];
    }
}


- (void) setSelectedIndex:(NSInteger)index
{
    [self setSelectedIndex:index animated:NO];
}


- (void) setDelegate:(id<HorizontalPickerViewDelegate>)delegate
{
    if (_delegate != delegate) {
        _delegate = delegate;
        [self setNeedsLayout];
    }
}


@end
