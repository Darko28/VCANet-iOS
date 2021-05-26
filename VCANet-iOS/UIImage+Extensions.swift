/*
  Copyright (c) 2017-2021 M.I. Hollemans

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.
*/

#if canImport(UIKit)

import UIKit
import CoreGraphics
import ImageIO
import Accelerate.vImage


extension UIImage {
    
  /**
    Rotates the image around its center.

    - Parameter degrees: Rotation angle in degrees.
    - Parameter keepSize: If true, the new image has the size of the original
      image, so portions may be cropped off. If false, the new image expands
      to fit all the pixels.
  */
  @nonobjc public func rotated(by degrees: CGFloat, keepSize: Bool = true) -> UIImage {
    let radians = degrees * .pi / 180
    let newRect = CGRect(origin: .zero, size: size).applying(CGAffineTransform(rotationAngle: radians))

    // Trim off the extremely small float value to prevent Core Graphics from rounding it up.
    var newSize = keepSize ? size : newRect.size
    newSize.width = floor(newSize.width)
    newSize.height = floor(newSize.height)

    return UIGraphicsImageRenderer(size: newSize).image { rendererContext in
      let context = rendererContext.cgContext
      context.setFillColor(UIColor.black.cgColor)
      context.fill(CGRect(origin: .zero, size: newSize))
      context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
      context.rotate(by: radians)
      let origin = CGPoint(x: -size.width / 2, y: -size.height / 2)
      draw(in: CGRect(origin: origin, size: size))
    }
  }
}

#endif

extension UIImage {
    
    func maskWithColor(color: UIColor) -> UIImage? {
        
        let maskingColors: [CGFloat] = [1, 255, 1, 255, 1, 255]
        let bounds = CGRect(origin: .zero, size: size)
        
        let maskImage = cgImage!
        var outImage: UIImage?
        
        // make sure image has no alpha channel
        let rFormat = UIGraphicsImageRendererFormat()
        rFormat.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: rFormat)
        let noAlphaImage = renderer.image { context in
            self.draw(at: .zero)
        }
        
        let noAlphaCGRef = noAlphaImage.cgImage
        if let imgRefCopy = noAlphaCGRef?.copy(maskingColorComponents: maskingColors) {
            
            let rFormat = UIGraphicsImageRendererFormat()
            rFormat.opaque = false
            let renderer = UIGraphicsImageRenderer(size: size, format: rFormat)
            
            outImage = renderer.image(actions: { context in
                context.cgContext.translateBy(x: 0, y: self.size.height)
                context.cgContext.scaleBy(x: 1, y: -1)
                context.cgContext.clip(to: bounds, mask: maskImage)
                context.cgContext.translateBy(x: -1, y: -1)
                context.cgContext.setFillColor(color.cgColor)
                context.cgContext.fill(bounds)
                context.cgContext.draw(imgRefCopy, in: bounds)
            })
        }
        
        return outImage
    }
}

// MARK: Various kinds of image resizing techniques

//import func AVFoundation.AVMakeRect
//let rect = AVMakeRect(aspectRatio: image.size, insideRect: imageView.bounds)
extension UIImage {
    
    /**
      Resizes the image by drawing to a UIGraphicsImageRenderer

      - Parameter scale: If this is 1, `newSize` is the size in pixels.
    */
    @nonobjc public func resized(to newSize: CGSize, scale: CGFloat = 1) -> UIImage {
      let format = UIGraphicsImageRendererFormat.default()
      format.scale = scale
      let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
      let image = renderer.image { _ in
        draw(in: CGRect(origin: .zero, size: newSize))
      }
      return image
    }
    
    /**
            Resize the image by drawing to a Core Graphics context
     */
    
    func resizedImageUsingCoreGraphics(for size: CGSize) -> UIImage? {
        let image = self.cgImage
        let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: image!.bitsPerComponent, bytesPerRow: Int(size.width), space: image?.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: image!.bitmapInfo.rawValue)
        context?.interpolationQuality = .high
        context?.draw(image!, in: CGRect(origin: .zero, size: size))
        
        guard let scaledImage = context?.makeImage() else { return nil }
        
        return UIImage(cgImage: scaledImage)
    }

    /**
            Creating a thumbnail with Image I/O
     */
    func resizedImageWithImageIO(at url: URL, for size: CGSize) -> UIImage? {
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height)
        ]
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        return UIImage(cgImage: image)
    }
    
    /**
            Lanczos Resampling with Core Image
     */
    func resizedImageWithCoreImage(at url: URL, scale: CGFloat, aspectRatio: CGFloat) -> UIImage? {
        
        let sharedContext = CIContext(options: [.useSoftwareRenderer : false])  // expensive operation, should be cached outside the func for repeated resizing
        guard let image = CIImage(contentsOf: url) else {
            return nil
        }
        
        let filter = CIFilter(name: "CILanczosScaleTransform")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(scale, forKey: kCIInputScaleKey)
        filter?.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
        
        guard let outputCIImage = filter?.outputImage,
              let outputCGImage = sharedContext.createCGImage(outputCIImage, from: outputCIImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage)
    }
        
    /**
            Image Scaling with vImage image-processing sub-framework
     */
    func resizedImageWithVImage(at url: URL, for size: CGSize) -> UIImage? {
        
        // Decode the source image
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        
        // Define the image format
        var format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: nil, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue), version: 0, decode: nil, renderingIntent: .defaultIntent)
        var error: vImage_Error
        
        // Create and initialize the source buffer
        var sourceBuffer = vImage_Buffer()
        defer { sourceBuffer.data.deallocate() }
        error = vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, image, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        
        // Create and initialize the destination buffer
        var destinationBuffer = vImage_Buffer()
        error = vImageBuffer_Init(&destinationBuffer, vImagePixelCount(size.height), vImagePixelCount(size.width), format.bitsPerPixel, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        
        // Scale the image
        error = vImageScale_ARGB8888(&sourceBuffer, &destinationBuffer, nil, vImage_Flags(kvImageHighQualityResampling))
        guard error == kvImageNoError else { return nil }
        
        // Create a CGImage from the destination buffer
        guard let resizedImage = vImageCreateCGImageFromBuffer(&destinationBuffer, &format, nil, nil, vImage_Flags(kvImageNoAllocate), &error)?.takeRetainedValue(),
              error == kvImageNoError else {
            return nil
        }
        
        return UIImage(cgImage: resizedImage)
    }
}
