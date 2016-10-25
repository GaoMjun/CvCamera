//
//  CvCamera.m
//  AVCaptureSession
//
//  Created by qq on 21/10/2016.
//  Copyright © 2016 GitHub. All rights reserved.
//

#import "CvCamera.h"

#ifdef __cplusplus

using namespace std;
using namespace cv;

#endif

@interface CvCamera () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

// session
@property (nonatomic, strong) AVCaptureSession *captureSession;

// video
@property (nonatomic, strong) AVCaptureDevice *videoCaptureDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *videoCaptureDeviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *captureVideoDataOutput;
@property (nonatomic, strong) AVCaptureConnection *captureVideoDataOutputConnection;

// audio
@property (nonatomic, strong) AVCaptureDevice *audioCaptureDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *audioCaptureDeviceInput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *captureAudioDataOutput;
@property (nonatomic, strong) AVCaptureConnection *captureAudioDataOutputConnection;

// photo
@property (nonatomic, strong) AVCaptureStillImageOutput *captureStillImageOutput;
@property (nonatomic, strong) AVCaptureConnection *captureStillImageOutputConnection;

// preview
//@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

// asset writer
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *videoAssetWriterInput;
@property (nonatomic, strong) AVAssetWriterInput *audioAssetWriterInput;
//@property (nonatomic, strong) NSURL *assetUrl;

//@property (nonatomic, assign) BOOL recording;

@end

@implementation CvCamera


- (void)configureSession {
    self.captureSession = [[AVCaptureSession alloc] init];
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    }
}

- (void)configureVideoWithCameraPosition:(AVCaptureDevicePosition)position {
    self.videoCaptureDevice = [self cameraWithPosition:position];
    self.videoCaptureDevice.activeVideoMinFrameDuration = CMTimeMake(1, 30);
    self.videoCaptureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, 30);
    self.videoCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.videoCaptureDevice error:nil];
    
    if ([self.captureSession canAddInput:self.videoCaptureDeviceInput]) {
        [self.captureSession addInput:self.videoCaptureDeviceInput];
    }
    
    self.captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.captureVideoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    self.captureVideoDataOutput.videoSettings = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                                            forKey: (id)kCVPixelBufferPixelFormatTypeKey];
    if ([self.captureSession canAddOutput:self.captureVideoDataOutput]) {
        [self.captureSession addOutput:self.captureVideoDataOutput];
        [self.captureVideoDataOutput setSampleBufferDelegate:self queue:dispatch_queue_create("captureVideoDataOutputQueue", DISPATCH_QUEUE_SERIAL)];
    }
    
    self.captureVideoDataOutputConnection = [self.captureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    self.captureVideoDataOutputConnection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    if (position == AVCaptureDevicePositionFront) {
        self.captureVideoDataOutputConnection.videoMirrored = YES;
    }
}

- (void)configureAudio {
    self.audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    self.audioCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioCaptureDevice error:nil];
    
    if ([self.captureSession canAddInput:self.audioCaptureDeviceInput]) {
        [self.captureSession addInput:self.audioCaptureDeviceInput];
    }
    
    self.captureAudioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    if ([self.captureSession canAddOutput:self.captureAudioDataOutput]) {
        [self.captureSession addOutput:self.captureAudioDataOutput];
        [self.captureAudioDataOutput setSampleBufferDelegate:self queue:dispatch_queue_create("captureAudioDataOutputQueue", DISPATCH_QUEUE_SERIAL)];
    }
    
    self.captureAudioDataOutputConnection = [self.captureAudioDataOutput connectionWithMediaType:AVMediaTypeAudio];
}

- (void)configurePreview {
    self.captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    self.captureVideoPreviewLayer.frame = [UIScreen mainScreen].bounds;
    self.captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.captureVideoPreviewLayer.connection.videoOrientation = self.captureVideoDataOutputConnection.videoOrientation;
}

- (void)configurePhoto {
    self.captureStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    self.captureStillImageOutput.highResolutionStillImageOutputEnabled = YES;
    if ([self.captureSession canAddOutput:self.captureStillImageOutput]) {
        [self.captureSession addOutput:self.captureStillImageOutput];
    }
    self.captureStillImageOutputConnection = [self.captureStillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    self.captureStillImageOutputConnection.videoOrientation = self.captureVideoDataOutputConnection.videoOrientation;
    if (self.videoCaptureDevice.position == AVCaptureDevicePositionFront) {
        self.captureStillImageOutputConnection.videoMirrored = YES;
    }
}

- (void)configureAssetWriter {
    NSString *tmpPath = [NSString stringWithFormat:@"%@out.mp4", NSTemporaryDirectory()];
    self.assetUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@out.mp4", NSTemporaryDirectory()]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
    }
    
    self.assetWriter = [AVAssetWriter assetWriterWithURL:self.assetUrl fileType:AVFileTypeMPEG4 error:nil];
    
    NSDictionary *videoOutputSettings = [self.captureVideoDataOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4];
    self.videoAssetWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoOutputSettings];
    self.videoAssetWriterInput.expectsMediaDataInRealTime = YES;
//    self.videoAssetWriterInput.transform = CGAffineTransformMakeRotation(M_PI_2);
    if ([self.assetWriter canAddInput:self.videoAssetWriterInput]) {
        [self.assetWriter addInput:self.videoAssetWriterInput];
    }
    
    NSDictionary *audioOutputSettings = [self.captureAudioDataOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:AVFileTypeAppleM4V];
    self.audioAssetWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
    self.audioAssetWriterInput.expectsMediaDataInRealTime = YES;
    if ([self.assetWriter canAddInput:self.audioAssetWriterInput]) {
        [self.assetWriter addInput:self.audioAssetWriterInput];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self configureSession];
        
        [self configureVideoWithCameraPosition:AVCaptureDevicePositionBack];
        
        [self configureAudio];
        
        [self configurePhoto];
        
        [self configurePreview];
        
        [self configureAssetWriter];
    }
    return self;
}

- (void)startRecord {
    self.recording = YES;
}

- (void)stopRecord {
    self.recording = NO;
    
    if (self.assetWriter.status == AVAssetWriterStatusWriting) {
        NSLog(@"%ld", (long)self.assetWriter.status);
        [self.videoAssetWriterInput markAsFinished];
        [self.audioAssetWriterInput markAsFinished];
        
        [self.assetWriter finishWritingWithCompletionHandler:^{
            NSLog(@"finishWritingWithCompletionHandler");
        }];
    }
}

- (void)start {
    if (self.captureSession) {
        [self.captureSession startRunning];
    }
}

- (void)stop {
    if (self.captureSession) {
        [self.captureSession stopRunning];
    }
}

#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if (self.recording) {
//        NSLog(@"%ld", (long)self.assetWriter.status);
        
        @synchronized (self) {
            if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
                
                [self.assetWriter startWriting];
//                NSLog(@"%ld", (long)self.assetWriter.status);
                [self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
//                NSLog(@"%ld", (long)self.assetWriter.status);
            }
        }
        
        if (self.assetWriter.status == AVAssetWriterStatusWriting) {
            
            if (connection == self.captureVideoDataOutputConnection) {
                NSLog(@"video data output");
                if (self.videoAssetWriterInput.readyForMoreMediaData) {
                    [self.videoAssetWriterInput appendSampleBuffer:sampleBuffer];
                }
                
            } else if (connection == self.captureAudioDataOutputConnection) {
                NSLog(@"audio data output");
                if (self.audioAssetWriterInput.readyForMoreMediaData) {
                    [self.audioAssetWriterInput appendSampleBuffer:sampleBuffer];
                }
                
            }
        }
    }
    if (self.delegate) {
        if (connection == self.captureVideoDataOutputConnection) {
            
            if ([_delegate respondsToSelector:@selector(processImage:)]) {
                
                CVPixelBufferRef imageBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
                
                CVPixelBufferLockBaseAddress(imageBuffer, 0);

                void *bufferAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
                size_t width = CVPixelBufferGetWidth(imageBuffer);
                size_t height = CVPixelBufferGetHeight(imageBuffer);
                size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
                
                // delegate image processing to the delegate
                cv::Mat matImage((int)height, (int)width, CV_8UC4, bufferAddress, bytesPerRow);
                cv::resize(matImage, matImage, cv::Size(matImage.cols/10, matImage.rows/10), 0, 0, CV_INTER_LINEAR);
                cv::cvtColor(matImage, matImage, CV_BGRA2GRAY);
                
                [_delegate processImage:matImage];
                
                CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
            }
        }
    }
}

/*
- (CGImageRef)imageFromPixelBuffer:(CVPixelBufferRef)imageBuffer
{
    void *baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    return newImage;
}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image
{
    
    CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width,
                                          frameSize.height,  kCVPixelFormatType_32ARGB, (CFDictionaryRef) CFBridgingRetain(options),
                                          &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, frameSize.width,
                                                 frameSize.height, 8, 4*frameSize.width, rgbColorSpace,
                                                 kCGImageAlphaPremultipliedFirst);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}
*/

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices)
        
        if (device.position == position ) {
            
            return device;
        }
    
    return nil;
}

- (void)switchCamera {
    [self.captureSession beginConfiguration];
    
    [self.captureSession removeInput:self.videoCaptureDeviceInput];
    [self.captureSession removeInput:self.audioCaptureDeviceInput];
    
    [self.captureSession removeOutput:self.captureVideoDataOutput];
    [self.captureSession removeOutput:self.captureAudioDataOutput];
    [self.captureSession removeOutput:self.captureStillImageOutput];
    
    if (self.videoCaptureDevice.position != AVCaptureDevicePositionFront) {
        [self configureVideoWithCameraPosition:AVCaptureDevicePositionFront];
    } else {
        [self configureVideoWithCameraPosition:AVCaptureDevicePositionBack];
    }
    
    [self configureAudio];
    
    [self configurePhoto];
    
    [self configureAssetWriter];
    
    [self.captureSession commitConfiguration];
}

- (void)takePhoto:(void (^)(UIImage *image))success {

    if (self.captureStillImageOutput) {

        if (self.captureStillImageOutputConnection.enabled) {
            
            [self.captureStillImageOutput captureStillImageAsynchronouslyFromConnection:self.captureStillImageOutputConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                
                if (!error) {
                    NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                    UIImage *image = [[UIImage alloc] initWithData:imageData];
                    success(image);
                } else {
                    NSLog(@"%@", error);
                }
            }];
        }
    }
}

@end
