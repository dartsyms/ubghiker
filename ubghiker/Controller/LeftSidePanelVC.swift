//
//  LeftSidePanelVC.swift
//  ubghiker
//
//  Created by sanchez on 03.12.17.
//  Copyright © 2017 KOT. All rights reserved.
//

import UIKit

class LeftSidePanelVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func signUpLoginBtnWasPressed(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC") as? LoginVC
        present(loginVC!, animated: true, completion: nil)
    }
    
}
