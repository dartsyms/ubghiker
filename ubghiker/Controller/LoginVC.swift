//
//  LoginVC.swift
//  ubghiker
//
//  Created by sanchez on 03.12.17.
//  Copyright © 2017 KOT. All rights reserved.
//

import UIKit
import Firebase

class LoginVC: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var emailField: RoundedCornerTextField!
    @IBOutlet weak var passwordField: RoundedCornerTextField!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var authBtn: RoundedShadowButton!
    
    private var isNewUser = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emailField.delegate = self
        passwordField.delegate = self
        view.bindToKeyboard()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(sender:)))
        self.view.addGestureRecognizer(tap)
    }
    
    @objc func handleScreenTap(sender: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    func checkOrUpdateUser(withInfo user: User?) {
        if let user = user {
            if self.segmentedControl.selectedSegmentIndex == 0 {
                let userData = ["provider": user.providerID] as [String: Any]
                DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: false)
            } else {
                let userData = ["provider": user.providerID,
                                "userIsDriver": true,
                                "isPickupModeEnabled": false,
                                "driverIsOnTrip": false] as [String: Any]
                DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: true)
            }
        }
    }
    
    func checkAuthError(withInfo error: Error?) {
        if let errorCode = AuthErrorCode(rawValue: error!._code) {
            switch errorCode {
            case .invalidEmail:
                print("Email is invalid. Please try again.")
            case .emailAlreadyInUse:
                print("This email is already in use. Please try another one.")
            case .wrongPassword:
                print("That was a wrong password!")
            case .userNotFound:
                isNewUser = true
            default:
                print("An unexpected error occurred. Please try again later.")
            }
        }
    }

    @IBAction func cancelBtnWasPressed(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func authBtnWasPressed(_ sender: UIButton) {
        guard let email = emailField?.text, emailField?.text != "" else { return }
        guard let pass = passwordField?.text, passwordField?.text != "" else { return }
        authBtn.animateButton(shouldLoad: true, withMessage: nil)
        self.view.endEditing(true)
        
        Auth.auth().signIn(withEmail: email, password: pass) { (user, error) in
            if error == nil {
                self.checkOrUpdateUser(withInfo: user)
                self.dismiss(animated: true, completion: nil)
            } else {
                self.checkAuthError(withInfo: error)
                if self.isNewUser {
                    Auth.auth().createUser(withEmail: email, password: pass, completion: { (user, error) in
                        if error != nil {
                            self.checkAuthError(withInfo: error)
                        } else {
                            self.checkOrUpdateUser(withInfo: user)
                            self.dismiss(animated: true, completion: nil)
                        }
                    })
                }
            }
        }
    }
    
}
