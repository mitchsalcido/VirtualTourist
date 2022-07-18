//
//  PhotoDetailViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/30/22.
//
/*
 About PhotoDetailViewController:
 */

import UIKit

class PhotoDetailViewController: UIViewController {

    var photo:Photo!
    
    @IBOutlet weak var imageView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let imageData = photo.imageData, let title = photo.title {
            imageView.image = UIImage(data: imageData)
            self.title = title
        }
    }
}
