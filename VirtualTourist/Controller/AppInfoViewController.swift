//
//  AppInfoViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 7/6/22.
//
/*
 About AppInfoViewController:
 Present controller with views showing app info and instructions
 */

import UIKit

class AppInfoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // dismiss
    @IBAction func doneButtonPressed(_ sender: Any) {
        dismiss(animated: true)
    }
}
