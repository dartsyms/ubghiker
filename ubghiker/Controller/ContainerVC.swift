//
//  ContainerVC.swift
//  ubghiker
//
//  Created by sanchez on 03.12.17.
//  Copyright © 2017 KOT. All rights reserved.
//

import UIKit
import QuartzCore

enum SlideOutState {
    case collapsed
    case leftPanelExpanded
}

enum ShowWhichVC {
    case homeVC
}

var showVC: ShowWhichVC = .homeVC

class ContainerVC: UIViewController {
    
    var homeVC: HomeVC!
    var leftVC: LeftSidePanelVC!
    var containerVC: UIViewController!
    var currentState: SlideOutState = .collapsed {
        didSet {
            let showCondition = (currentState != .collapsed)
            shouldShowShadowForCenterViewController(showCondition)
        }
    }
    
    var isStatusBarHidden = false
    let centerPanelExpandedOffset: CGFloat = 160
    
    var tap: UITapGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        initScreen(withContentsOf: showVC)
    }
    
    func initScreen(withContentsOf screen: ShowWhichVC) {
        var presentingController: UIViewController
        showVC = screen
        if homeVC == nil {
            homeVC = UIStoryboard.homeVC()
            homeVC.delegate = self
        }
        presentingController = homeVC
        if let container = containerVC {
            container.view.removeFromSuperview()
            container.removeFromParentViewController()
        }
        containerVC = presentingController
        view.addSubview(containerVC.view)
        addChildViewController(containerVC)
        containerVC.didMove(toParentViewController: self)
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return UIStatusBarAnimation.slide
    }
    
    override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }

}

extension ContainerVC: CenterVCDelegate {
    func toggleLeftPanel() {
        let notExpanded = (currentState != .leftPanelExpanded)
        if notExpanded {
            addLeftPanelViewController()
        }
        animateLeftPanel(shouldExpand: notExpanded)
    }
    
    func addLeftPanelViewController() {
        if leftVC == nil {
            leftVC = UIStoryboard.leftViewController()
            addChildSidePanelViewController(leftVC!)
        }
    }
    
    @objc func animateLeftPanel(shouldExpand: Bool) {
        if shouldExpand {
            isStatusBarHidden = !isStatusBarHidden
            animateStatusBar()
            showWhiteCoverView()
            currentState = .leftPanelExpanded
            animateCenterPanelXPosition(targetPosition: containerVC.view.frame.width - centerPanelExpandedOffset)
        } else {
            isStatusBarHidden = !isStatusBarHidden
            animateStatusBar()
            hideWhiteCoverView()
            animateCenterPanelXPosition(targetPosition: 0, completion: { (finished) in
                if finished {
                    self.currentState = .collapsed
                    self.leftVC = nil
                }
            })
        }
    }
    
    func animateCenterPanelXPosition(targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animate(withDuration: 0.5,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0,
                       options: .curveEaseInOut,
                       animations: { self.containerVC.view.frame.origin.x = targetPosition },
                       completion: completion)
    }
    
    func animateStatusBar() {
        UIView.animate(withDuration: 0.5,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0,
                       options: .curveEaseInOut,
                       animations: { self.setNeedsStatusBarAppearanceUpdate() })
    }
    
    func showWhiteCoverView() {
        let whiteCoverView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        whiteCoverView.alpha = 0.0
        whiteCoverView.backgroundColor = UIColor.white
        whiteCoverView.tag = 22
        self.containerVC.view.addSubview(whiteCoverView)
        whiteCoverView.fadeTo(alphaValue: 0.75, withDuration: 0.2)
        tap = UITapGestureRecognizer(target: self, action: #selector(animateLeftPanel(shouldExpand:)))
        tap?.numberOfTapsRequired = 1
        self.containerVC.view.addGestureRecognizer(tap)
    }
    
    func hideWhiteCoverView() {
        containerVC.view.removeGestureRecognizer(tap)
        for subview in self.containerVC.view.subviews {
            if subview.tag == 22 {
                UIView.animate(withDuration: 0.2,
                               animations: { subview.alpha = 0.0 },
                               completion: { (finished) in
                                subview.removeFromSuperview()
                })
            }
        }
    }
    
    func shouldShowShadowForCenterViewController(_ condition: Bool) {
        if condition {
            containerVC.view.layer.shadowOpacity = 0.6
        } else {
            containerVC.view.layer.shadowOpacity = 0.0
        }
    }
    
    func addChildSidePanelViewController(_ sidePanelController: LeftSidePanelVC) {
        view.insertSubview(sidePanelController.view, at: 0)
        addChildViewController(sidePanelController)
        sidePanelController.didMove(toParentViewController: self)
    }
}

private extension UIStoryboard {
    class func mainStoryboard() -> UIStoryboard {
        return UIStoryboard(name: MAIN_STORYBOARD, bundle: Bundle.main)
    }
    
    class func leftViewController() -> LeftSidePanelVC? {
        return mainStoryboard().instantiateViewController(withIdentifier: VC_LEFT_PANEL) as? LeftSidePanelVC
    }
    
    class func homeVC() -> HomeVC? {
        return mainStoryboard().instantiateViewController(withIdentifier: VC_HOME) as? HomeVC
    }
}
