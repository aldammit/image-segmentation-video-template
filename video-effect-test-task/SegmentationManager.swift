//
//  SegmentationManager.swift
//
//  Created by Bogdan Redkin on 19.10.2021.
//  Copyright © 2020 Bogdan Redkin. All rights reserved.
//

import MetalPetal
import UIKit
import Vision

public enum SegmentationError: Error, LocalizedError {
    case cgImageNotFound
    case visionRequestNotFound
    case perform
    case graphicsCurrentContextNotFound
    case segmentationmapNotFound
    case maskingImageRetrieved
    case personNotFound
    case unknown

    public var errorDescription: String? {
        switch self {
        case .cgImageNotFound: return "The specified image was not found."
        case .visionRequestNotFound: return "Could not find VNCoreMLRequest in CoreMLManager."
        case .perform: return "Failed to perform VNImageRequestHandler."
        case .graphicsCurrentContextNotFound: return "UIGraphicsGetCurrentContext could not be obtained."
        case .segmentationmapNotFound: return "Could not get segmentation map in SegmentationView."
        case .maskingImageRetrieved: return "The masked image could not be retrieved."
        case .personNotFound: return "The person not found on image"
        case .unknown: return "Unknown error."
        }
    }
}

enum SegmentationType {
    case builtIn
    case segmentation8bit
}

enum SegmentationManagerResult {
    struct Segments {
        let sourceImage: MTIImage
        let background: MTIImage
        let extractedPerson: MTIImage
    }
    case success(segments: Segments)
    case failure(error: Error)
}

final class SegmentationManager {
    private var visionModel: VNCoreMLModel?
    private let type: SegmentationType
    private let queue = DispatchQueue(label: "segmentation.process")
    private lazy var blackBg: MTIImage = .init(color: .black, sRGB: false, size: CGSize(width: 1024, height: 1024))

    init(type: SegmentationType) {
        self.type = type
    }

    deinit {
        print("SegmentationManager deinit")
    }

    func loadModel() throws {
        let model = try segmentation_8bit(configuration: .init()).model
        self.visionModel = try VNCoreMLModel(for: model)
    }

    func getSegments(by imageName: String, context: MTIContext, completionHandler: @escaping ((SegmentationManagerResult) -> Void)) {
        queue.async {
            guard
//                let self,
                let imageUrl = Bundle.main.url(forResource: imageName, withExtension: "jpeg"),
                let sourceUIImg = UIImage(contentsOfFile: imageUrl.path),
                let sourceCGImage = sourceUIImg.cgImage
            else {
                completionHandler(.failure(error: SegmentationError.cgImageNotFound))
                return
            }
            
            var extractedMask: MTIImage
            
            do {
                switch self.type {
                case .segmentation8bit:
                    guard
                        let bgrCGImage = self.revertRedAndBlueChannels(cgImage: sourceCGImage),
                        let visionModel = self.visionModel
                    else {
                        completionHandler(.failure(error: SegmentationError.cgImageNotFound))
                        return
                    }

                    let targetFrame = AVMakeRect(aspectRatio: sourceUIImg.size, insideRect: CGRect(origin: .zero, size: self.blackBg.size))

                    let filter = MultilayerCompositingFilter()
                    filter.inputBackgroundImage = self.blackBg
                    filter.layers = [
                        MultilayerCompositingFilter
                            .Layer(content: MTIImage(cgImage: bgrCGImage, options: [.SRGB: false], isOpaque: true))
                            .frame(targetFrame, layoutUnit: .pixel)
                    ]

                    guard
                        let bgrOutputImage = filter.outputImage,
                        let bgrOutputCGImage = try? context.makeCGImage(from: bgrOutputImage)
                    else {
                        completionHandler(.failure(error: SegmentationError.maskingImageRetrieved))
                        return
                    }

//                    let bgrOutputUIImage = UIImage(cgImage: bgrOutputCGImage)

                    let handler = VNImageRequestHandler(cgImage: bgrOutputCGImage, options: [:])
                    let visionRequest = VNCoreMLRequest(model: visionModel)
                    visionRequest.imageCropAndScaleOption = .scaleFill
                    #if targetEnvironment(simulator)
                        visionRequest.usesCPUOnly = true
                    #endif
                    try handler.perform([visionRequest])
                    guard
                        let observations = visionRequest.results as? [VNPixelBufferObservation],
                        let pixelBuffer = observations.first?.pixelBuffer,
                        let maskImage = self.fillTransparentPixels(buffer: pixelBuffer),
//                        let maskImage = UIImage(pixelBuffer: pixelBuffer),
                        let smoothMaskImage = maskImage.cgImage?.edgeSmoothing(context: context)?.cropped(to: .pixel(targetFrame))
                    else {
                        completionHandler(.failure(error: SegmentationError.maskingImageRetrieved))
                        return
                    }
                    extractedMask = smoothMaskImage
                case .builtIn:
                    let segmentationRequest = VNGeneratePersonSegmentationRequest()
                    segmentationRequest.qualityLevel = .balanced
                    segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
                    #if targetEnvironment(simulator)
                        segmentationRequest.usesCPUOnly = true
                    #endif

                    let handler = VNImageRequestHandler(cgImage: sourceCGImage, options: [:])

                    try handler.perform([segmentationRequest])

                    guard
                        let maskPixelBuffer = segmentationRequest.results?.first?.pixelBuffer,
//                        let maskImage = self.fillTransparentPixels(buffer: maskPixelBuffer),
                        let maskImage = UIImage(pixelBuffer: maskPixelBuffer),
                        let smoothMaskImage = maskImage.cgImage?.edgeSmoothing(context: context)
                    else {
                        completionHandler(.failure(error: SegmentationError.maskingImageRetrieved))
                        return
                    }
                    extractedMask = smoothMaskImage
                }
                
                let sourceMTIImage = MTIImage(cgImage: sourceCGImage, options: [.SRGB: false], isOpaque: true)
                
                let blendWithMaskFilter = MTIBlendWithMaskFilter()
                blendWithMaskFilter.inputBackgroundImage = MTIImage(color: .clear, sRGB: false, size: sourceUIImg.size)
                blendWithMaskFilter.inputImage = sourceMTIImage
                blendWithMaskFilter.inputMask = MTIMask(content: extractedMask, component: .red, mode: .normal)
                let maskResult = blendWithMaskFilter.outputImage
                
                blendWithMaskFilter.inputMask = MTIMask(content: extractedMask, component: .red, mode: .oneMinusMaskValue)
                let backgroundResult = blendWithMaskFilter.outputImage
                                
                if let maskResult, let backgroundResult {
                    completionHandler(.success(
                        segments: SegmentationManagerResult.Segments(
                            sourceImage: sourceMTIImage,
                            background: backgroundResult,
                            extractedPerson: maskResult
                        )
                    ))
//                    let maskResultCGImage = try context.makeCGImage(from: maskResult)
//                    let backgroundResultCGImage = try context.makeCGImage(from: backgroundResult)
//                    let maskResultImage = UIImage(cgImage: maskResultCGImage)
//                    let backgorundResultImage = UIImage(cgImage: backgroundResultCGImage)
//                    print("result: \(backgorundResultImage) \(maskResultImage)")
                }
            } catch {
                completionHandler(.failure(error: SegmentationError.perform))
            }
        }
    }
    
    private func fillTransparentPixels(buffer: CVPixelBuffer) -> UIImage? {
        guard
            let uiImg = UIImage(pixelBuffer: buffer),
            let bytes = uiImg.toByteArrayRGBA()?.map ({ byte in
                if byte > UInt8(1) && byte < UInt8(50) {
                    return UInt8(0)
                } else if byte >= UInt8(50) && byte < UInt8(255){
                    return UInt8(255)
                } else {
                    return byte
                }
            })
        else { return nil }
        return UIImage.fromByteArrayRGBA(bytes, width: uiImg.size.width.int, height: uiImg.size.height.int)
    }
    
    private func revertRedAndBlueChannels(cgImage: CGImage) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
            fatalError("Unable to create CGContext")
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let data = context.data!
        for y in 0 ..< height {
            let row = data.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0 ..< width {
                let index = bytesPerPixel * x
                let blue = row[index]
                let green = row[index + 1]
                let red = row[index + 2]
                row[index] = red
                row[index + 1] = green
                row[index + 2] = blue
            }
        }

        return context.makeImage()
    }
}
