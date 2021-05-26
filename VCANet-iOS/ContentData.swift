//
//  ContentData.swift
//  ALBCSIRS-iOS-SwiftUI
//
//  Created by Chuanlong Li on 2021/3/31.
//

import SwiftUI
import Vision


@propertyWrapper
struct EqualOrLess {
    private var number: Int
    private var maximum: Int
    var wrappedValue: Int {
        get { return number }
        set { number = newValue > 0 ? min(newValue, maximum) : 0 }
    }
        
    init(wrappedValue: Int, maximum: Int) {
        self.maximum = maximum
        number = wrappedValue > 0 ? min(wrappedValue, maximum) : 0
    }
    
}


let urls = [Bundle.main.url(forResource: "41295", withExtension: ".png")!,
            Bundle.main.url(forResource: "97", withExtension: ".png")!,
            Bundle.main.url(forResource: "39976", withExtension: ".png")!,
            Bundle.main.url(forResource: "41080", withExtension: ".png")!,
            Bundle.main.url(forResource: "41863", withExtension: ".png")!,
            Bundle.main.url(forResource: "42053", withExtension: ".png")!,
            Bundle.main.url(forResource: "42067", withExtension: ".png")!,
]


class ContentData: ObservableObject {
    
    @Published var detailImage: UIImage?
    private(set) var backgroundImage: UIImage?
    
    @EqualOrLess(wrappedValue: 2, maximum: urls.count-1) private(set) var currentURLIndex: Int
    
    private var imageModel = try! VCANet_Preview(configuration: .init())
    
    // MARK: - Set up vision request
    private lazy var visionRequest: VNCoreMLRequest = {
        do {
            let visionModel = try VNCoreMLModel(for: imageModel.model)
            let request = VNCoreMLRequest(model: visionModel)
            return request
        } catch {
            fatalError("Could not load Vision ML model: \(error)")
        }
    }()

    init() {
        self.getImage(url: urls[currentURLIndex])
    }
    
    private func getImage(url: URL) {
        self.detailImage = try? UIImage(data: Data(contentsOf: url))
        self.backgroundImage = try? UIImage(data: Data(contentsOf: url))
    }
    
    func analyze() {
        // MARK: - Vision Predict
        let pixelBuffer = self.detailImage!.pixelBufferGray(width: 192, height: 224)!
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try imageRequestHandler.perform([visionRequest])
        } catch {
            print(error)
        }
        
        guard let observations = visionRequest.results as? [VNPixelBufferObservation] else {
            fatalError("Unexpected result type from VNCoreMLRequest")
        }

        let maskPixelBuffer = observations[0].pixelBuffer
        var maskImage = UIImage(pixelBuffer: maskPixelBuffer)
        maskImage = maskImage?.maskWithColor(color: .yellow)
        let maskedImage = mergeMaskAndBackground(mask: maskImage!, background: self.backgroundImage!, size: CGSize(width: self.backgroundImage!.size.width, height: self.backgroundImage!.size.height))
        self.detailImage = maskedImage
    }
    
    func resetImage() {
        self.detailImage = self.backgroundImage
    }
               
    func nextImage() {
        self.currentURLIndex += 1
        self.getImage(url: urls[currentURLIndex])
    }
    
    func previousImage() {
        self.currentURLIndex -= 1
        self.getImage(url: urls[currentURLIndex])
    }
}
