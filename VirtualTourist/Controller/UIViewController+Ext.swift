//
//  UIViewController+Ext.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 7/1/22.
//
/*
 About UIViewController+Ext:
 */

import UIKit

extension UIViewController {

    func showOKAlert(error:LocalizedError? = nil) {
        let title = error?.localizedDescription ?? "Unknown Error"
        showOKAlert(title: title)
    }
    
    func showOKAlert(title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
}
