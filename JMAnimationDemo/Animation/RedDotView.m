//
//  RedDotView.m
//  JMAnimationDemo
//
//  Created by jm on 16/3/16.
//  Copyright © 2016年 JM. All rights reserved.
//

#import "RedDotView.h"

@implementation RedDotView {
    NSMutableDictionary *_separateBlockDictionary;//存储 view 消失时触发的 block 的字典
    UIPanGestureRecognizer *_gesture;//手势监控。
    UIBezierPath *_cutePath;//画黏贴效果的贝塞尔曲线
    UIColor *_fillColorForCute;//填充黏贴效果的颜色
    UIView *_touchView;//被手势拖动的 view
    UIColor *_bubbleColor;//黏贴效果的颜色
    CGFloat _bubbleWidth;//被拖动的 view 的最小边长
    UIImageView *_prototypeView; //替换被拖动 view 的 imageView
    UILabel *_bubbleLabel;
    
    CGFloat _R1, _R2, _X1, _X2, _Y1, _Y2;
    CGFloat _centerDistance;
    CGFloat _maxDistance;
    CGFloat _cosDigree;
    CGFloat _sinDigree;
    //圆的关键点 A,B,E 是初始位置上圆的左右后三点，C，D,F 是移动位置上的圆的三点，O，P两个圆之间画弧线所需要的点，_pointTemp是辅助点。
    CGPoint _pointA, _pointB, _pointC, _pointD, _pointE, _pointF, _pointO, _pointP, _pointTemp, _pointTemp2;
    //画圆弧的辅助点
    CGPoint _pointDF1, _pointDF2, _pointFC1, _pointFC2, _pointBE1, _pointBE2, _pointEA1, _pointEA2;
    CGFloat _offset1, _offset2;
    CGFloat _percentage;
    
    CGPoint _deviationPoint;
    CGPoint _oldBackViewCenter;
    CAShapeLayer *_shapeLayer;
}

- (instancetype)initWithMaxDistance:(CGFloat)maxDistance bubbleColor:(UIColor *)bubbleColor {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        _bubbleColor = bubbleColor;
        _maxDistance = maxDistance;
        _prototypeView = [[UIImageView alloc] init];
        _separateBlockDictionary = [[NSMutableDictionary alloc] init];
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)attach:(UIView *)item withSeparateBlock:(SeparateBlock)separateBlock {
    NSValue *viewValue = [NSValue valueWithNonretainedObject:item];
    if (!_separateBlockDictionary[viewValue]) {
        UIPanGestureRecognizer *gesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragGesture:)];
        item.userInteractionEnabled = YES;
        [item addGestureRecognizer:gesture];
    }
    if (separateBlock) {
        [_separateBlockDictionary setObject:separateBlock forKey:[NSValue valueWithNonretainedObject:item]];
    } else {
        SeparateBlock block = ^BOOL(UIView *view) {
            return NO;
        };
        [_separateBlockDictionary setObject:block forKey:[NSValue valueWithNonretainedObject:item]];
    }
}

- (void)setUp {
    [[[UIApplication sharedApplication].delegate window] addSubview:self];
    _prototypeView.image = [self getImageFromView:_touchView];
    _bubbleWidth = MIN(_touchView.frame.size.width, _touchView.frame.size.height) - 1;
    _centerDistance = 0;
    CGPoint animationViewOrigin = [_touchView convertPoint:CGPointMake(0, 0) toView:self];
    _prototypeView.frame = CGRectMake(animationViewOrigin.x, animationViewOrigin.y, _touchView.frame.size.width, _touchView.frame.size.height);
    [self addSubview:_prototypeView];
    _oldBackViewCenter = CGPointMake(animationViewOrigin.x + _touchView.frame.size.width/2, animationViewOrigin.y + _touchView.frame.size.height/2);
    NSLog(@"_oldBackViewCenter%f, %f", _oldBackViewCenter.x, _oldBackViewCenter.y);
    _fillColorForCute = _bubbleColor;
    _touchView.hidden = YES;
    self.userInteractionEnabled = YES;
    
    _shapeLayer = [CAShapeLayer layer];
    _R2 = _bubbleWidth/2;
    _R1 = _bubbleWidth/2;
    
    _X1 = _oldBackViewCenter.x;
    _Y1 = _oldBackViewCenter.y;
    _X2 = _prototypeView.center.x;
    _Y2 = _prototypeView.center.y;
    
    _pointA = CGPointMake(_X1 - _R1, _Y1);
    _pointB = CGPointMake(_X1 + _R1, _Y1);
    _pointC = CGPointMake(_X2 + _R2, _Y2);
    _pointD = CGPointMake(_X2 - _R2, _Y2);
    _pointO = CGPointMake(_X1 - _R1, _Y1);
    _pointP = CGPointMake(_X2 + _R2, _Y2);
}

- (void)handleDragGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint dragPoint = [gesture locationInView:self];
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _touchView = gesture.view;
        CGPoint dragPountInView = [gesture locationInView:gesture.view];
        _deviationPoint = CGPointMake(dragPountInView.x - gesture.view.frame.size.width/2, dragPountInView.y - gesture.view.frame.size.height/2);
        [self setUp];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        _prototypeView.center =  CGPointMake(dragPoint.x - _deviationPoint.x, dragPoint.y - _deviationPoint.y);
        if (_centerDistance > _maxDistance) {
            _fillColorForCute = [UIColor clearColor];
            [_shapeLayer removeFromSuperlayer];
        }
        [self drawRect];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        _fillColorForCute = [UIColor clearColor];
        [_shapeLayer removeFromSuperlayer];
        if (_centerDistance > _maxDistance) {
            SeparateBlock block = _separateBlockDictionary[[NSValue valueWithNonretainedObject:_touchView]];
            if (block) {
                BOOL animationEnable = block(_touchView);
                if (animationEnable) {
                    [_prototypeView removeFromSuperview];
                    [self explosion:_prototypeView.center radius:_bubbleWidth];
                } else {
                    [self springBack:_prototypeView point:_oldBackViewCenter];
                }
            }
        } else {
            [self springBack:_prototypeView point:_oldBackViewCenter];
        }
    }
}

- (void)drawRect {
    _X1 = _oldBackViewCenter.x;
    _Y1 = _oldBackViewCenter.y;
    _X2 = _prototypeView.center.x;
    _Y2 = _prototypeView.center.y;
    
    _centerDistance = sqrtf((_X2 - _X1)*(_X2 - _X1) + (_Y2 - _Y1)*(_Y2 - _Y1));
    if (_centerDistance == 0) {
        _cosDigree = 1;
        _sinDigree = 0;
    } else {
        _cosDigree = (_Y2 - _Y1)/_centerDistance;
        _sinDigree = (_X2 - _X1)/_centerDistance;
    }
     _percentage = _centerDistance/_maxDistance;
    _R1 = (2 - _percentage)*_bubbleWidth/4;
    
    _pointA = CGPointMake(_X1 - _R1*_cosDigree, _Y1 + _R1*_sinDigree);
    _pointB = CGPointMake(_X1 + _R1*_cosDigree, _Y1 - _R1*_sinDigree);
    _pointE = CGPointMake(_X1 - _R1*_sinDigree, _Y1 - _R1*_cosDigree);
    _pointC = CGPointMake(_X2 + _R2*_cosDigree, _Y2 - _R2*_sinDigree);
    _pointD = CGPointMake(_X2 - _R2*_cosDigree, _Y2 + _R2*_sinDigree);
    _pointF = CGPointMake(_X2 + _R2*_sinDigree, _Y2 + _R2*_cosDigree);
    //offset 指的是 _pointA-_pointEA2,_pointEA1-_pointE... 的距离，当该值设置为正方形边长的 1/3.6 倍时，画出来的圆弧近似贴合 1/4 圆。
    _offset1 = _R1*2/3.6;
    _offset2 = _R2*2/3.6;
    
    _pointEA2 = CGPointMake(_pointA.x - _offset1*_sinDigree, _pointA.y - _offset1*_cosDigree);
    _pointEA1 = CGPointMake(_pointE.x - _offset1*_cosDigree, _pointE.y + _offset1*_sinDigree);
    _pointBE2 = CGPointMake(_pointE.x + _offset1*_cosDigree, _pointE.y - _offset1*_sinDigree);
    _pointBE1 = CGPointMake(_pointB.x - _offset1*_sinDigree, _pointB.y - _offset1*_cosDigree);
    
    _pointFC2 = CGPointMake(_pointC.x + _offset2*_sinDigree, _pointC.y + _offset2*_cosDigree);
    _pointFC1 = CGPointMake(_pointF.x + _offset2*_cosDigree, _pointF.y - _offset2*_sinDigree);
    _pointDF2 = CGPointMake(_pointF.x - _offset2*_cosDigree, _pointF.y + _offset2*_sinDigree);
    _pointDF1 = CGPointMake(_pointD.x + _offset2*_sinDigree, _pointD.y + _offset2*_cosDigree);
    
    _pointTemp = CGPointMake(_pointD.x + _percentage*(_pointC.x - _pointD.x), _pointD.y + _percentage*(_pointC.y - _pointD.y));//关键点
    _pointTemp2 = CGPointMake(_pointD.x + (1 - _percentage)*(_pointC.x - _pointD.x), _pointD.y + (1 - _percentage)*(_pointC.y - _pointD.y));
    _pointO = CGPointMake(_pointA.x + (_pointTemp.x - _pointA.x)/2, _pointA.y + (_pointTemp.y - _pointA.y)/2);
    _pointP = CGPointMake(_pointB.x + (_pointTemp2.x - _pointB.x)/2, _pointB.y + (_pointTemp2.y - _pointB.y)/2);
    
    _cutePath = [UIBezierPath bezierPath];
    [_cutePath moveToPoint:_pointB];
    [_cutePath addCurveToPoint:_pointE controlPoint1:_pointBE1 controlPoint2:_pointBE2];
    [_cutePath addCurveToPoint:_pointA controlPoint1:_pointEA1 controlPoint2:_pointEA2];
    [_cutePath addQuadCurveToPoint:_pointD controlPoint:_pointO];
    
    [_cutePath addCurveToPoint:_pointF controlPoint1:_pointDF1 controlPoint2:_pointDF2];
    [_cutePath addCurveToPoint:_pointC controlPoint1:_pointFC1 controlPoint2:_pointFC2];
    [_cutePath addQuadCurveToPoint:_pointB controlPoint:_pointP];
    
    if (_centerDistance < _maxDistance) {
        _shapeLayer.path = [_cutePath CGPath];
        _shapeLayer.fillColor = [_fillColorForCute CGColor];
        [self.layer insertSublayer:_shapeLayer below:_prototypeView.layer];
    }
}

//爆炸效果
- (void)explosion:(CGPoint)explosionPoint radius:(CGFloat)radius {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (int i = 1; i < 6; i++) {
        UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"red_dot_image_%d", i]];
        [array addObject:image];
    }
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.frame = CGRectMake(0, 0, radius*2, radius*2);
    imageView.center = explosionPoint;
    imageView.animationImages = array;
    [imageView setAnimationDuration:0.25];
    [imageView setAnimationRepeatCount:1];
    [imageView startAnimating];
    [self addSubview:imageView];
    [self performSelector:@selector(explosionComplete) withObject:nil afterDelay:0.25 inModes:@[NSDefaultRunLoopMode]];
}

//爆炸动画结束
- (void)explosionComplete {
    _touchView.hidden = YES;
    [self removeFromSuperview];
}

//回弹效果
- (void)springBack:(UIView *)view point:(CGPoint)point {
    [UIView animateWithDuration:0.5 delay:0.0 usingSpringWithDamping:0.2 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        view.center = point;
    } completion:^(BOOL finished) {
        if (finished) {
            _touchView.hidden = NO;
            self.userInteractionEnabled = NO;
            [view removeFromSuperview];
            [self removeFromSuperview];
        }
    }];
}

- (UIImage *)getImageFromView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, UIScreen.mainScreen.scale);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)dealloc {
    NSLog(@"dealloc");
}

@end
