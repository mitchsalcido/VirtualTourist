//
//  FlickDetailViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/30/22.
//

import UIKit

class FlickDetailViewController: UIViewController {

    var flick: [UIImage:String]!
    
    @IBOutlet weak var imageView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let image = flick.keys.first, let title = flick.values.first {
            imageView.image = image
            self.title = title
        }
    }
}
