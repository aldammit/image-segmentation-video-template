//
//  VideoProcessingViewController.swift
//  video-effect-test-task
//
//  Created by Bogdan Redkin on 02/03/2023.
//

import UIKit
import MetalPetal
import AVKit

class VideoProcessingViewController: UIViewController {

    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var renderContext = try! MTIContext(device: MTLCreateSystemDefaultDevice()!)
    private var segmentationManager: SegmentationManager
    private var videoWriter: VideoWriter?
    private var acitivityIndicator = UIActivityIndicatorView(style: .medium)
    
    init(segmentationManager: SegmentationManager) {
        self.segmentationManager = segmentationManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground

        view.addSubview(acitivityIndicator)
        acitivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        acitivityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        acitivityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        acitivityIndicator.startAnimating()
        acitivityIndicator.hidesWhenStopped = true
        
        initialVideoSetup()
        fillVideoWriterWithImages()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.layer.bounds
    }
    
    private func initialVideoSetup() {
        guard let cacheUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }

        let videoPath: URL
        if #available(iOS 16.0, *) {
            videoPath = cacheUrl.appending(component: "test-\(Date().timeIntervalSince1970).mov", directoryHint: .notDirectory)
        } else {
            videoPath = cacheUrl.appendingPathComponent("test-\(Date().timeIntervalSince1970).mov", isDirectory: false)
        }
        videoWriter = VideoWriter(url: videoPath, width: 2000, height: 2921, sessionStartTime: .zero, isRealTime: false, queue: .main)
    }
    
    private func fillVideoWriterWithImages() {
        generateImages { [weak self] result in
            guard
                let self,
                let videoWriter = self.videoWriter
            else { print("error"); return }
            
            var metadataWaitList: [(UIImage, Float)] = []
            var isSubscribed: Bool = false
            
            func addImage(image: UIImage, at time: Float) {
                if videoWriter.writerInput.isReadyForMoreMediaData {
                    let result = videoWriter.add(image: image, presentationTime: CMTime(value: Int64(time * 1000), timescale: 1000))
                    if !result {
                        print("error")
                    }
                } else {
                    print("can't write image")
                    metadataWaitList.append((image, time))
                    guard isSubscribed == false else { return }
                    isSubscribed = true
                    videoWriter.writerInput.requestMediaDataWhenReady(on: .main) {
                        while videoWriter.writerInput.isReadyForMoreMediaData {
                            guard let metadata = metadataWaitList.first else { return }
                            print("start to write metadata with time: \(metadata.1)")

                            let result = videoWriter.add(image: metadata.0, presentationTime: CMTime(value: Int64(metadata.1 * 1000), timescale: 1000))
                            
                            if !result {
                                print("error")
                            } else {
                                metadataWaitList.removeFirst()
                                print("success")
                                if metadataWaitList.isEmpty {
                                    self.makeVideo()
                                }
                            }
                        }
                    }
                }
            }

            addImage(image: result[0], at: .zero)
            addImage(image: result[1], at: 1.575)
            addImage(image: result[2], at: 1.825)
            addImage(image: result[3], at: 2.392)
            addImage(image: result[4], at: 3.092)
            addImage(image: result[5], at: 3.258)
            addImage(image: result[6], at: 3.392)
            addImage(image: result[7], at: 4.008)
            addImage(image: result[8], at: 4.050)
            addImage(image: result[9], at: 4.058)
            addImage(image: result[10], at: 4.060)
            addImage(image: result[11], at: 4.175)
            addImage(image: result[12], at: 4.180)
            addImage(image: result[13], at: 4.200)
            addImage(image: result[14], at: 4.300)
            addImage(image: result[15], at: 4.400)
            addImage(image: result[16], at: 4.425)
            addImage(image: result[17], at: 4.558)
            addImage(image: result[18], at: 4.8)
            addImage(image: result[19], at: 5.108)
            addImage(image: result[20], at: 5.425)
            addImage(image: result[21], at: 5.558)
            addImage(image: result[22], at: 5.942)
            addImage(image: result[23], at: 5.992)
            addImage(image: result[24], at: 6.608)
            addImage(image: result[25], at: 6.658)
            addImage(image: result[26], at: 6.892)
            addImage(image: result[27], at: 7.458)
            addImage(image: result[28], at: 7.592)
            addImage(image: result[29], at: 10.058)
            addImage(image: result[30], at: 10.258)
            addImage(image: result[31], at: 10.493)

            guard metadataWaitList.isEmpty else { return }
            self.makeVideo()
        }
    }
    
    private func makeVideo() {
        videoWriter?.finish { [weak self] asset in
            guard let self, let asset else { return }
            let composition = AVMutableComposition()
            guard
                let audioUrl = Bundle.main.url(forResource: "music", withExtension: "aac"),
                let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                let assetTrack = asset.tracks(withMediaType: .video).first
            else {
                print("Something is wrong with the asset.")
                return
            }
            let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
            do {
                try compositionTrack.insertTimeRange(timeRange, of: assetTrack, at: .zero)

                let audioAsset = AVURLAsset(url: audioUrl)
                if
                    let audioAssetTrack = audioAsset.tracks(withMediaType: .audio).first,
                    let compositionAudioTrack = composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: 0
                    ) {
                    try compositionAudioTrack.insertTimeRange(
                        timeRange,
                        of: audioAssetTrack,
                        at: .zero
                    )
                }
            } catch {
                print(error)
                return
            }

            compositionTrack.preferredTransform = assetTrack.preferredTransform
            let videoSize: CGSize = assetTrack.naturalSize
            let videoComposition = AVMutableVideoComposition()
            let mainInstruction = AVMutableVideoCompositionInstruction()
            mainInstruction.timeRange = CMTimeRangeMake(
                start: .zero,
                duration: asset.duration
            )
            let videoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: assetTrack)
            mainInstruction.layerInstructions = [videoLayerInstruction]

            videoComposition.instructions = [mainInstruction]
            videoComposition.renderSize = videoSize
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

            
            self.acitivityIndicator.stopAnimating()
            self.player = AVPlayer(playerItem: AVPlayerItem(asset: composition))
            self.playerLayer = AVPlayerLayer(player: self.player)
            guard let player = self.player, let playerLayer = self.playerLayer else { return }
            playerLayer.frame = self.view.bounds
            
            do {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.ambient)
                try AVAudioSession.sharedInstance().setActive(true)
                player.play()
            } catch {
                print("error: \(error)")

            }
            print("status: \(player.status)")
            self.view.layer.addSublayer(playerLayer)
        }
    }

    
    private func generateImages(completionHandler: @escaping ([UIImage]) -> Void) {
        var resultMtiImages: [MTIImage] = []
        var segmentedImages: [SegmentationManagerResult.Segments] = []
        let group = DispatchGroup()
        for i in 2...9 {
            group.enter()
            segmentationManager.getSegments(by: "image-\(i)", context: renderContext) { result in
                switch result {
                case .success(let segments):
                    segmentedImages.append(segments)
                case .failure(let error):
                    print("error: \(error)")
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            print("segmented images: \(segmentedImages)")
            let targetSize = CGSize(width: 2000, height: 2900)//self.view.bounds.inset(by: self.view.safeAreaInsets).size * UIScreen.main.nativeScale
            
            let layerCompositionFilter = MultilayerCompositingFilter()
            layerCompositionFilter.inputBackgroundImage = MTIImage(color: .black, sRGB: false, size: targetSize)
            
            func fillResultImages() {
                if let output = layerCompositionFilter.outputImage {
                    resultMtiImages.append(output)
                }
            }
            
            func croppedImage(image: MTIImage) -> MTIImage {
                let targetFrame = AVMakeRect(aspectRatio: targetSize, insideRect: CGRect(origin: .zero, size: image.size))
                return image.cropped(to: MTICropRegion(bounds: targetFrame, unit: .pixel)) ?? image
            }
            
            func appendLayer(image: MTIImage, fillResult: Bool = true, frame: CGRect = .init(origin: .zero, size: .init(width: 1, height: 1)), layoutUnit: MTILayer.LayoutUnit = .fractionOfBackgroundSize) {
                layerCompositionFilter.layers.append(.content(croppedImage(image: image)).frame(frame, layoutUnit: layoutUnit))
                if fillResult {
                    fillResultImages()
                }
            }
            
            func insertLayer(image: MTIImage, index: Int, fillResult: Bool = true, frame: CGRect = .init(origin: .zero, size: .init(width: 1, height: 1)), layoutUnit: MTILayer.LayoutUnit = .fractionOfBackgroundSize) {
                layerCompositionFilter.layers.insert(.content(croppedImage(image: image)).frame(frame, layoutUnit: layoutUnit), at: index)
                if fillResult {
                    fillResultImages()
                }
            }
            
            appendLayer(image: segmentedImages[4].sourceImage)
            appendLayer(image: segmentedImages[7].extractedPerson, frame: .init(x: 0.01, y: .zero, width: 0.95, height: 0.95))
            insertLayer(image: segmentedImages[7].background, index: 1)
            layerCompositionFilter.layers.removeAll()
            appendLayer(image: segmentedImages[7].sourceImage) //2.392
            appendLayer(image: segmentedImages[6].extractedPerson) //3.092
            insertLayer(image: segmentedImages[6].background, index: 1) //3.258
            
            layerCompositionFilter.layers.removeAll()
            appendLayer(image: segmentedImages[6].sourceImage) //3.392
            
            appendLayer(image: segmentedImages[5].extractedPerson) //4.008
            
            let maxScaleLevel = 7
            
            for i in 0 ... maxScaleLevel {
                let originalSize = segmentedImages[5].extractedPerson.size
                let scaledSize = originalSize.scale(1.1 + i.cgFloat * 0.15)
                if
                    let scaledMaskImage = segmentedImages[5].extractedPerson.resized(to: scaledSize, resizingMode: .scale)?.cropped(to: CGRect(
                        x: CGFloat((scaledSize.width - originalSize.width) / 2),
                        y: CGFloat((scaledSize.height - originalSize.height) / 2),
                        width: originalSize.width,
                        height: originalSize.height
                    )) {
                    let scaledMask = MTIMask(content: scaledMaskImage, component: .alpha, mode: .normal)
                    let maskBlendFilter = MTIBlendWithMaskFilter()
                    maskBlendFilter.inputBackgroundImage = MTIImage(color: .clear, sRGB: false, size: targetSize)
                    if i % 2 == 0 {
                        maskBlendFilter.inputImage = croppedImage(image: segmentedImages[6].sourceImage)
                    } else {
                        maskBlendFilter.inputImage = croppedImage(image: segmentedImages[5].sourceImage)
                    }
                    maskBlendFilter.inputMask = scaledMask
                    if let output = maskBlendFilter.outputImage {
                        insertLayer(image: output, index: layerCompositionFilter.layers.count - (1 + i)) //4.058, 4.175, 4.425
                    }
                }
            }
            
            appendLayer(image: segmentedImages[5].background) //4.558
            appendLayer(image: segmentedImages[5].sourceImage) //4.8
            
            layerCompositionFilter.layers.append(.content(croppedImage(image: segmentedImages[3].background)).frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1.05, height: 1.05), layoutUnit: .fractionOfBackgroundSize).rotation(0.15)) //5.108
            fillResultImages()
            layerCompositionFilter.layers.append(.content(croppedImage(image: segmentedImages[3].background)).frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1.025, height: 1.025), layoutUnit: .fractionOfBackgroundSize).rotation(0.15)) //5.425
            fillResultImages()
            layerCompositionFilter.layers.append(.content(croppedImage(image: segmentedImages[3].background)).frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .fractionOfBackgroundSize).rotation(0.15)) //5.558
            fillResultImages()

            appendLayer(image: segmentedImages[3].extractedPerson) //5.942
            appendLayer(image: segmentedImages[3].background) //5.992
            
            appendLayer(image: segmentedImages[1].extractedPerson) //6.608
            appendLayer(image: segmentedImages[1].background) //6.658
            appendLayer(image: segmentedImages[1].sourceImage) //6.892
            
            let originalPersonSize = segmentedImages[2].extractedPerson.size
            let scaledPersonSize = originalPersonSize.scale(1.3)
            appendLayer(image: segmentedImages[2].extractedPerson, frame: CGRect(
                x: -(scaledPersonSize.width - originalPersonSize.width) / 2,
                y: -(scaledPersonSize.height - originalPersonSize.height) / 2,
                width: scaledPersonSize.width,
                height: scaledPersonSize.height
            ), layoutUnit: .pixel) //7.458
            insertLayer(image: segmentedImages[2].background, index: layerCompositionFilter.layers.count - 1) //7.592
            appendLayer(image: segmentedImages[2].sourceImage) //7.908
            
            appendLayer(image: segmentedImages[0].background, frame: .init(x: -0.05, y: -0.05, width: 1.1, height: 1.1)) //10.058
            appendLayer(image: segmentedImages[0].background, frame: .init(x: -0.02, y: -0.02, width: 1.04, height: 1.04)) //10.258
            appendLayer(image: segmentedImages[0].sourceImage) //10.493

            var resultImages: [UIImage] = []
            
            for resultMtiImage in resultMtiImages {
                do {
                    let resultCGImage = try self.renderContext.makeCGImage(from: resultMtiImage)
                    let resultUIImage = UIImage(cgImage: resultCGImage)
                    resultImages.append(resultUIImage)
                } catch {
                    print("error")
                }
            }
            print("resultImages count: \(resultImages.count)")
            completionHandler(resultImages)
        }
    }
}
