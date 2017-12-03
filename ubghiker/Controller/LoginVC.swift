//
//  LoginVC.swift
//  ubghiker
//
//  Created by sanchez on 03.12.17.
//  Copyright © 2017 KOT. All rights reserved.
//

import UIKit

class LoginVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.bindToKeyboard()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(sender:)))
        self.view.addGestureRecognizer(tap)
    }
    
    @objc func handleScreenTap(sender: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }

    @IBAction func cancelBtnWasPressed(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    

}
