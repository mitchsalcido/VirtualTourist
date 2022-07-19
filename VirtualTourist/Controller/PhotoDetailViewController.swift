//
//  PhotoDetailViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/30/22.
//
/*
 About PhotoDetailViewController:
 Display a Photo in an imageView and set title to Photo title
 */

import UIKit

class PhotoDetailViewController: UIViewController {

    // ref to Photo
    var photo:Photo!
    
    // ref to imageView to display photo
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // verify good phoyo and title. Display
        if let imageData = photo.imageData, let title = photo.title {
            imageView.image = UIImage(data: imageData)
            self.title = title
        }
    }
}
