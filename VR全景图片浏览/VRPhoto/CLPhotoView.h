//
//  CLPhotoView.h
//  VR全景图片浏览
//
//  Created by tusm on 2017/3/5.
//  Copyright © 2017年 cleven. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <CoreMotion/CoreMotion.h>

@interface CLPhotoView : GLKView
///  传过来的VR全景图片
@property (nonatomic,copy)NSString *photoURL;

@end
