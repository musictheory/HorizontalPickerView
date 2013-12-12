/*
    Copyright (c) 2013, musictheory.net, LLC
    All rights reserved.

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

#import "ViewController.h"
#import "HorizontalPickerView.h"


static CGImageRef sCreateImage(CGPoint offset, BOOL opaque, CGSize size, CGFloat scale, void (^callback)(CGContextRef))
{
    UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextTranslateCTM(context, offset.x, offset.y);

    if (callback) callback(context);

    CGImageRef result = context ? CGBitmapContextCreateImage(context) : NULL;

    UIGraphicsEndImageContext();

    return result;
}


static UIImage *sMakeImage(CGSize size, BOOL opaque, CGFloat scale, void (^callback)(CGContextRef))
{
    if (size.width < 1 || size.height < 1) return nil;

    CGImageRef image  = sCreateImage(CGPointZero, opaque, size, scale, callback);
    UIImage   *result = nil;
    
    if (scale < 1.0) {
        scale = [[UIScreen mainScreen] scale];
    }
    
    if (image) {
        result = [UIImage imageWithCGImage:image scale:scale orientation:UIImageOrientationUp];
        CFRelease(image);
    }

    return result;
}



@interface ViewController () <HorizontalPickerViewDelegate>
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [_topPicker setDelegate:self];
    [_bottomPicker setDelegate:self];
}




- (NSInteger) numberOfChoicesInPickerView:(HorizontalPickerView *)pickerView
{
    if (pickerView == _topPicker) {
        return 16;
    } else if (pickerView == _bottomPicker) {
        return 8;
    }

    return 0;
}


- (CGFloat) pointsPerChoiceInPickerView:(HorizontalPickerView *)pickerView
{
    return 72;
}


- (UIImage *) pickerView:(HorizontalPickerView *)pickerView imageForChoiceAtIndex:(NSInteger)index
{
    return sMakeImage(CGSizeMake(64, 64), 0, NO, ^(CGContextRef context) {
        UIColor *color = (index % 2) ^ (pickerView == _topPicker) ? [UIColor redColor] : [UIColor blackColor];
        
        NSString *indexAsString = [NSString stringWithFormat:@"%ld", (long)index];
        
        NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
        [ps setAlignment:NSTextAlignmentCenter];
        
        NSDictionary *attributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:32],
            NSForegroundColorAttributeName: color,
            NSParagraphStyleAttributeName: ps
        };
        
        [indexAsString drawInRect:CGRectMake(0, 0, 64, 64) withAttributes:attributes];
    });
}


@end
