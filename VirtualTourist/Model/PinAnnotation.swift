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

class PinAnnotation: MKPointAnnotation {
    
    // ref to map pin entity
    var pin:Pin!
}
