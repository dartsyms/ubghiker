//
//  HomeVC.swift
//  ubghiker
//
//  Created by sanchez on 02.12.17.
//  Copyright © 2017 KOT. All rights reserved.
//

import UIKit
import MapKit

class HomeVC: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionBtn: RoundedShadowButton!
    
    var delegate: CenterVCDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
    }
    
    @IBAction func actionBtnWasPressed(_ sender: UIButton) {
        actionBtn.animateButton(shouldLoad: true, withMessage: "REQUEST RIDE")
    }
    
    @IBAction func menuBtnWasPressed(_ sender: UIButton) {
        delegate?.toggleLeftPanel()
    }
    
}

