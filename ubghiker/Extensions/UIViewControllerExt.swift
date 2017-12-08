//
//  UIViewControllerExt.swift
//  ubghiker
//
//  Created by sanchez on 08.12.17.
//  Copyright © 2017 KOT. All rights reserved.
//

import UIKit

extension UIViewController {
    func shouldPresentLoadingView(_ showStatus: Bool) {
        var fadingView: UIView?
        if showStatus {
            fadingView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
            fadingView?.backgroundColor = UIColor.black
            fadingView?.alpha = 0.0
            fadingView?.tag = 99
            
            let spinner = UIActivityIndicatorView()
            spinner.color = UIColor.white
            spinner.activityIndicatorViewStyle = .whiteLarge
            spinner.center = view.center
            
            fadingView?.addSubview(spinner)
            view.addSubview(fadingView!)
            spinner.startAnimating()
            fadingView?.fadeTo(alphaValue: 0.7, withDuration: 0.2)
        } else {
            for subview in view.subviews {
                if subview.tag == 99 {
                    UIView.animate(withDuration: 0.2,
                                   animations: { subview.alpha = 0.0 },
                                   completion: { (finished) in
                                    subview.removeFromSuperview()
                    })
                }
            }
        }
    }
}
