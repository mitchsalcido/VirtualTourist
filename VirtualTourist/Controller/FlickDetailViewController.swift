//
//  FlickDetailViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/30/22.
//

import UIKit

class FlickDetailViewController: UIViewController {

    var flick:Flick!
    
    @IBOutlet weak var imageView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let imageData = flick.imageData, let title = flick.title {
            imageView.image = UIImage(data: imageData)
            self.title = title
        }
    }
}
