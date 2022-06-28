//
//  FlickrAnnotation.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/27/22.
//

import Foundation
import MapKit

class FlickrAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    var photosURLString:[String] = []
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}