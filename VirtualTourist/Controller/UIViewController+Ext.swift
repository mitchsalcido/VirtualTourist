//
//  UIViewController+Ext.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 7/1/22.
//

import UIKit

extension UIViewController {

    func showOKAlert(error:Error? = nil) {
        let title = error?.localizedDescription ?? "Unknown Error"
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
}
