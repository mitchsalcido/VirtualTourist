//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//

import UIKit
import MapKit

// San Fran: 37.7749° N, -122.4194° W
class MapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        FlickrAPI.geoSearchFlickr(latitude: 37.775, longitude: -122.42) { success, error in
            if success {
                for url in FlickrAPI.flickURLArray {
                    print(url)
                }
            }
        }
        /*
        FlickrAPI.textSearchFlickr(text: "California") { success, error in
            if success {
                for url in FlickrAPI.flickURLArray {
                    print(url)
                }
            }
        }
         */
    }
}

