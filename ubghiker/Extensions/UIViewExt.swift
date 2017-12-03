//
//  UIViewExt.swift
//  ubghiker
//
//  Created by sanchez on 03.12.17.
//  Copyright © 2017 KOT. All rights reserved.
//

import UIKit

extension UIView {
    func fadeTo(alphaValue: CGFloat, withDuration duration: TimeInterval) {
        UIView.animate(withDuration: duration) {
            self.alpha = alphaValue
        }
    }
    
    func bindToKeyboard() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChange(_:)),
                                               name: NSNotification.Name.UIKeyboardWillChangeFrame,
                                               object: nil)
    }
    
    @objc func keyboardWillChange(_ notification: Notification) {
        let duration = notification.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! Double
        let curve = notification.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! UInt
        let curFrame = (notification.userInfo![UIKeyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        let targetFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let deltaY = targetFrame.origin.y - curFrame.origin.y
        
        UIView.animateKeyframes(withDuration: duration,
                                delay: 0.0,
                                options: UIViewKeyframeAnimationOptions(rawValue: curve),
                                animations: { self.frame.origin.y += deltaY },
                                completion: nil)
    }
}
