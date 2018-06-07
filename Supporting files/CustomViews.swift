//
//  CustomViews.swift
//  ARKitCarGeolocation
//
//  Created by Michael Shields on 6/7/18.
//  Copyright © 2018 Esteban Herrera. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Pass through view

class PassThroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for subview in subviews {
            if !subview.isHidden && subview.alpha > 0 && subview.isUserInteractionEnabled && subview.point(inside: convert(point, to: subview), with: event) {
                return true // child is eligible
            }
        }
        return false // child not eligible, forward touch
    }
}
