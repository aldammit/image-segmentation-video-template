//
//  ViewController.swift
//  video-effect-test-task
//
//  Created by Bogdan Redkin on 20/02/2023.
//

import UIKit

class ViewController: UIViewController {
    
    private var useVisionSwitch: UISwitch = UISwitch(frame: .zero)
    private var startButton = UIButton(type: .custom)
    private var segmentationManager: SegmentationManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        useVisionSwitch.addTarget(self, action: #selector(useVisionSwitchValueChanged), for: .valueChanged)
        view.addSubview(useVisionSwitch)
        useVisionSwitch.translatesAutoresizingMaskIntoConstraints = false

        let useVisionLabel = UILabel()
        useVisionLabel.text = "Enable image segmentation using Vision API"
        useVisionLabel.textColor = .label
        useVisionLabel.numberOfLines = 0
        useVisionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(useVisionLabel)
        
        startButton = UIButton(type: .custom)
        startButton.setTitle("Generate video", for: .normal)
        startButton.setTitleColor(.label, for: .normal)
        startButton.setTitleColor(.secondaryLabel, for: .highlighted)
        startButton.setTitleColor(.secondaryLabel, for: .disabled)
        startButton.addTarget(self, action: #selector(startButtonTouchUpInside), for: .touchUpInside)
        view.addSubview(startButton)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(
            [
                view.centerXAnchor.constraint(equalTo: startButton.centerXAnchor),
                view.centerYAnchor.constraint(equalTo: startButton.centerYAnchor),
                startButton.widthAnchor.constraint(equalToConstant: 200),
                startButton.heightAnchor.constraint(equalToConstant: 50),
                view.centerXAnchor.constraint(equalTo: useVisionSwitch.centerXAnchor, constant: -100),
                startButton.bottomAnchor.constraint(equalTo: useVisionSwitch.topAnchor, constant: -50),
                useVisionSwitch.centerYAnchor.constraint(equalTo: useVisionLabel.centerYAnchor),
                useVisionSwitch.leftAnchor.constraint(equalTo: useVisionLabel.rightAnchor, constant: 12),
                useVisionLabel.widthAnchor.constraint(equalToConstant: 200)
            ]
        )
    }
    
    @objc func useVisionSwitchValueChanged() {
        updateSegmentationManager()
    }
    
    @objc func startButtonTouchUpInside() {
        print("start")
        if segmentationManager == nil {
            updateSegmentationManager {
                self.startButtonTouchUpInside()
            }
            return
        }
        guard let segmentationManager else { fatalError("segmentation manager didn't load") }
        let videoProcessingVC = VideoProcessingViewController(segmentationManager: segmentationManager)
        navigationController?.pushViewController(videoProcessingVC, animated: true)
    }

    private func updateSegmentationManager(completionHandler: (() -> Void)? = nil) {
        if useVisionSwitch.isOn {
            segmentationManager = SegmentationManager(type: .builtIn)
            completionHandler?()
        } else {
            startButton.setTitle("Loading 8bit Model", for: .normal)
            startButton.isEnabled = false
            useVisionSwitch.isEnabled = false
            
            DispatchQueue.global().async { [weak self] in
                guard let self else { return }
                self.segmentationManager = SegmentationManager(type: .segmentation8bit)
                do {
                    try self.segmentationManager?.loadModel()
                    DispatchQueue.main.async {
                        self.startButton.setTitle("Generate video", for: .normal)
                        self.startButton.isEnabled = true
                        self.useVisionSwitch.isEnabled = true
                        completionHandler?()
                    }
                } catch {
                    print("error: \(error)")
                    DispatchQueue.main.async {
                        completionHandler?()
                    }
                }
            }
            
        }
    }
}

