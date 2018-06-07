//
//  CustomButton.swift
//  ARKitCarGeolocation
//
//  Created by Michael Shields on 6/7/18.
//  Copyright © 2018 Esteban Herrera. All rights reserved.
//

import Foundation
import UIKit

enum CustomButtonType: Int {
    case refreshButton
}

class CustomButton: UIButton {
    
    var type: CustomButtonType?
    var color: UIColor?
    
    override func draw(_ rect: CGRect) {
        
        self.titleLabel?.text = ""
        
        switch type! {
        case .refreshButton:
            ARPOIUI.drawIconRefresh(frame: rect, color: color ?? .white, down: self.isHighlighted)
            return
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            super.isHighlighted = isHighlighted
            self.setNeedsDisplay()
        }
    }
}

