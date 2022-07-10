//
//  PinAnnotation.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/27/22.
//
/*
 About PinAnnotation:
 Pin annotation model object
 */
import Foundation
import MapKit
import CoreData

class PinAnnotation: NSObject, MKAnnotation {
    
    // ref to map pin entity
    var pin:Pin!

    // protocol attributes
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    // init with coordinate
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}
