//
//  Utils.swift
//  ALBCSIRS-iOS-UIKit
//
//  Created by Chuanlong Li on 2021/3/5.
//

import Foundation
import UIKit


// MARK: - Merge Mask and Background
public func mergeMaskAndBackground(mask: UIImage, background: UIImage, size: CGSize) -> UIImage? {
    // Merge two images
    let sizeImage = size
    UIGraphicsBeginImageContext(sizeImage)
    
    let areaSize = CGRect(x: 0, y: 0, width: sizeImage.width, height: sizeImage.height)
    
    // background
//        let bg = cropImageToSquare(image: background)
//        bg?.draw(in: areaSize)
    background.draw(in: areaSize)
    // mask
    mask.draw(in: areaSize)
//        mask.draw(in: areaSize, blendMode: .sourceIn, alpha: 1)
    
    let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return newImage
}
