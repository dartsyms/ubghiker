//
//  HomeVC.swift
//  ubghiker
//
//  Created by sanchez on 02.12.17.
//  Copyright © 2017 KOT. All rights reserved.
//

import UIKit
import MapKit
import RevealingSplashView

class HomeVC: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionBtn: RoundedShadowButton!
    
    var delegate: CenterVCDelegate?
    
    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!,
                                                  iconInitialSize: CGSize(width: 80, height: 80),
                                                  backgroundColor: UIColor.white)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        
        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()
        
        revealingSplashView.heartAttack = true
    }
    
    @IBAction func actionBtnWasPressed(_ sender: UIButton) {
        actionBtn.animateButton(shouldLoad: true, withMessage: "REQUEST RIDE")
    }
    
    @IBAction func menuBtnWasPressed(_ sender: UIButton) {
        delegate?.toggleLeftPanel()
    }
    
}

