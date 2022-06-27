//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//

import UIKit
import MapKit

class MapViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        FlickrAPI.textSearchFlickr(text: "Mitch") { success, error in
        }
    }
}

