//
//  CenterVCDelegate.swift
//  ubghiker
//
//  Created by sanchez on 03.12.17.
//  Copyright © 2017 KOT. All rights reserved.
//

import UIKit

protocol CenterVCDelegate {
    func toggleLeftPanel()
    func addLeftPanelViewController()
    func animateLeftPanel(shouldExpand: Bool)
}
