//
//  CGImage+EdgeSmoothing.swift
//  photo-editor
//
//  Created by Bogdan Redkin on 19.10.2021.
//  Copyright © 2021 Bogdan Redkin. All rights reserved.
//

import CoreGraphics
import MetalPetal

extension CGImage {
    
    func edgeSmoothing(context: MTIContext) -> MTIImage? {
        let commandQueue = context.commandQueue
        let device = context.device
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let median = MPSImageMedian(device: device, kernelDiameter: 15)
        // kernelDiameter：Diameter of pixels around the target to be median

        do {
            let srcTex =  try context.textureLoader.newTexture(with: self, options: [ .SRGB: false ])
        
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: srcTex.pixelFormat,
                                                                width: srcTex.width,
                                                                height: srcTex.height,
                                                                mipmapped: false)
            desc.pixelFormat = .rgba8Unorm
            desc.usage = [.shaderRead, .shaderWrite]

            let medTex = device.makeTexture(descriptor: desc)!

            median.encode(commandBuffer: commandBuffer, sourceTexture: srcTex, destinationTexture: medTex)

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            return MTIImage(texture: medTex, alphaType: .alphaIsOne)
        } catch {
            print("error: \(error)")
            return nil
        }
    }

}
