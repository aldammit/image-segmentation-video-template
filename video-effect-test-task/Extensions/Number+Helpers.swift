//
//  Number+Helpers.swift
//  telegram-contest
//
//  Created by Bogdan Redkin on 11/10/2022.
//

import Foundation

extension Int {
    func interpolate(to: Int, progress: CGFloat) -> Int {
        guard progress >= 0.0 && progress <= 1.0 else { return self }
        return self + Int(CGFloat(to - self) * progress)
    }
    
    var float: Float {
        return Float(self)
    }
    
    var double: Double {
        return Double(self)
    }
    
    var cgFloat: CGFloat {
        return CGFloat(self)
    }
    
    var string: String {
        return String(describing: self)
    }
    
    static func extract(from string: String) -> Int? {
        return Int(string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
    }
}

extension Float {
    
    var int: Int {
        return Int(self)
    }
    
    var double: Double {
        return Double(self)
    }
    
    var cgFloat: CGFloat {
        return CGFloat(self)
    }
    
    var string: String {
        return String(describing: self)
    }
}

extension Double {
    var float: Float {
        return Float(self)
    }
    
    var int: Int {
        return Int(self)
    }
    
    var cgFloat: CGFloat {
        return CGFloat(self)
    }
    
    var string: String {
        return String(describing: self)
    }
}

extension CGFloat {
    func interpolate(to: CGFloat, progress: CGFloat) -> CGFloat {
        guard progress >= 0.0 && progress <= 1.0 else { return self }
        return self + (to - self) * progress
    }
    
    var int: Int {
        return Int(self)
    }
    
    var double: Double {
        return Double(self)
    }
    
    var float: Float {
        return Float(self)
    }
    
    var string: String {
        return String(describing: self)
    }
    
}
