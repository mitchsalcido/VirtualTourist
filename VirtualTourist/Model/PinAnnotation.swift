//
//  PinAnnotation.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/27/22.
//

import Foundation
import MapKit
import CoreData

class PinAnnotation: NSObject, MKAnnotation {
    
    var pin:Pin!

    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}
