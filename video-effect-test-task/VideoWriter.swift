//
//  VideoWriter.swift
//  video-effect-test-task
//
//  Created by Bogdan Redkin on 02/03/2023.
//

import UIKit
import AVFoundation

class VideoWriter {
    fileprivate var writer: AVAssetWriter
    fileprivate var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    fileprivate let queue: DispatchQueue
    static var ciContext = CIContext.init()

    var writerInput: AVAssetWriterInput
    let pixelSize: CGSize
    var lastPresentationTime: CMTime?

    init?(url: URL, width: Int, height: Int, sessionStartTime: CMTime, isRealTime: Bool, queue: DispatchQueue) {
        self.queue = queue
        let outputSettings: [String:Any] = [
            AVVideoCodecKey : AVVideoCodecType.h264,
            AVVideoWidthKey : width,
            AVVideoHeightKey: height,
        ]
        self.pixelSize = CGSize.init(width: width, height: height)
        let input = AVAssetWriterInput.init(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = isRealTime
        guard
            let writer = try? AVAssetWriter.init(url: url, fileType: .mp4),
            writer.canAdd(input),
            sessionStartTime != .invalid
        else {
            return nil
        }
        
        let sourceBufferAttributes: [String:Any] = [
            String(kCVPixelBufferPixelFormatTypeKey) : kCVPixelFormatType_32ARGB,
            String(kCVPixelBufferWidthKey) : width,
            String(kCVPixelBufferHeightKey) : height,
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor.init(assetWriterInput: input, sourcePixelBufferAttributes: sourceBufferAttributes)
        self.pixelBufferAdaptor = pixelBufferAdaptor
        
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: sessionStartTime)
        
        if let error = writer.error {
            NSLog("VideoWriter init: ERROR - \(error)")
            return nil
        }
        
        self.writer = writer
        self.writerInput = input
    }

    func add(image: UIImage, presentationTime: CMTime) -> Bool {
        if self.writerInput.isReadyForMoreMediaData == false {
            return false
        }
        if self.pixelBufferAdaptor.appendPixelBufferForImage(image, presentationTime: presentationTime) {
            self.lastPresentationTime = presentationTime
            return true
        }
        return false
    }
    
    func add(sampleBuffer: CMSampleBuffer) -> Bool {
        if self.writerInput.isReadyForMoreMediaData == false {
            NSLog("VideoWriter: not ready for more data")
            return false
        }

        if self.writerInput.append(sampleBuffer) {
            self.lastPresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            return true
        }
        return false
    }
    
    func finish(_ completionBlock: ((AVURLAsset?)->Void)? = nil) {
        writerInput.markAsFinished()
        writer.finishWriting(completionHandler: {
            self.queue.async {
                guard self.writer.status == .completed else {
                    NSLog("VideoWriter finish: error in finishWriting - \(String(describing: self.writer.error))")
                    completionBlock?(nil)
                    return
                }
                let asset = AVURLAsset.init(url: self.writer.outputURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey : true])
                let duration = CMTimeGetSeconds(asset.duration)

                NSLog("VideoWriter: finishWriting() complete, duration=\(duration)")
                completionBlock?(asset)
            }
        })
    }
}

extension AVAssetWriterInputPixelBufferAdaptor {
    func appendPixelBufferForImage(_ image: UIImage, presentationTime: CMTime) -> Bool {
        var appendSucceeded = false
        
        autoreleasepool {
            guard let pixelBufferPool = self.pixelBufferPool else {
                NSLog("appendPixelBufferForImage: ERROR - missing pixelBufferPool")
                return
            }
                
            let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
            let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                kCFAllocatorDefault,
                pixelBufferPool,
                pixelBufferPointer
            )
            
            if let pixelBuffer = pixelBufferPointer.pointee, status == 0 {
                pixelBuffer.fillPixelBufferFromImage(image)
                appendSucceeded = self.append(pixelBuffer, withPresentationTime: presentationTime)
                if !appendSucceeded {
                    NSLog("VideoWriter appendPixelBufferForImage: ERROR appending")
                }
                pixelBufferPointer.deinitialize(count: 1)
            } else {
                NSLog("VideoWriter appendPixelBufferForImage: ERROR - Failed to allocate pixel buffer from pool, status=\(status)") // -6680 = kCVReturnInvalidPixelFormat
            }
            pixelBufferPointer.deallocate()
        }
        return appendSucceeded
    }
}
