//
//  CvCamera.h
//  AVCaptureSession
//
//  Created by qq on 21/10/2016.
//  Copyright © 2016 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus

#import <opencv2/opencv.hpp>
#import <opencv2/highgui/ios.h>

#endif

@protocol CvCameraDelegate <NSObject>

@optional
#ifdef __cplusplus
- (void)processImage:(cv::Mat &)matImage;
#endif

@end

@class AVCaptureVideoPreviewLayer;
@interface CvCamera : NSObject

- (void)start;
- (void)stop;

- (void)startRecord;
- (void)stopRecord;

- (void)switchCamera;

- (void)takePhoto:(void (^)(UIImage *image))success;

@property (nonatomic, weak) id<CvCameraDelegate> delegate;

// preview
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

@property (nonatomic, assign) BOOL recording;

@property (nonatomic, strong) NSURL *assetUrl;

@end
