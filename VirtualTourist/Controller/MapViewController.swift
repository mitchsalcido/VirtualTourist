//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//

import UIKit
import MapKit

// San Fran: 37.7749° N, -122.4194° W
// Chico CA: 39.73° N, -121.84° W

class MapViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
    }
    
    @IBAction func longPressInMapViewDetected(_ sender: Any) {
        let longPressGr = sender as! UILongPressGestureRecognizer
        if longPressGr.state != .began {
            return
        }
        let pressLocation = longPressGr.location(in: mapView)
        let coordinate = mapView.convert(pressLocation, toCoordinateFrom: mapView)
        let annotation = FlickrAnnotation(coordinate: coordinate)
        annotation.title = "Mitch"
        mapView.addAnnotation(annotation)
        
        imageView.alpha = 0.5
        
        FlickrAPI.geoSearchFlickr(latitude: coordinate.latitude, longitude: coordinate.longitude) { success, error in
            if success {
                
                guard FlickrAPI.flickURLStringArray.count > 0 else {
                    return
                }
                
                annotation.photosURLString = FlickrAPI.flickURLStringArray
                
                let urlString = FlickrAPI.flickURLStringArray[Int.random(in: 0..<FlickrAPI.flickURLStringArray.count)]
                
                guard let url = URL(string: urlString) else {
                    return
                }
                
                FlickrAPI.getFlick(url: url) { image, error in
                    self.imageView.alpha = 1.0
                    self.imageView.image = image
                }
            }
        }
    }
}

extension MapViewController {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reUseID = "pinReuseID"
        let pinView: MKMarkerAnnotationView!
        
        if let pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reUseID) as? MKMarkerAnnotationView {
            pinView.annotation = annotation
            return pinView
        } else {
            pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reUseID)
            pinView.canShowCallout = true
            
            let leftAccessory = UIButton(type: .custom)
            leftAccessory.frame = CGRect(x: 0.0, y: 0.0, width: 22.0, height: 22.0)
            leftAccessory.setImage(UIImage(named: "DeleteAccessoryView"), for: .normal)
            pinView.leftCalloutAccessoryView = leftAccessory
            
            let rightAccessory = UIButton(type: .custom)
            rightAccessory.frame = CGRect(x: 0.0, y: 0.0, width: 22.0, height: 22.0)
            rightAccessory.setImage(UIImage(named: "AlbumAccessoryView"), for: .normal)
            pinView.rightCalloutAccessoryView = rightAccessory
            
            pinView.animatesWhenAdded = true
        }
        
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        guard let annotation = view.annotation as? FlickrAnnotation else {
            return
        }
        if control == view.leftCalloutAccessoryView {
            print("left callout")
            mapView.removeAnnotation(annotation)
        } else {
            print("right callout")
            performSegue(withIdentifier: "AlbumSegueID", sender: annotation.photosURLString)
        }
    }
}

extension MapViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AlbumSegueID" {
            let controller = segue.destination as! AlbumCollectionViewController
            controller.urlStrings = sender as! [String]
            print(sender as! [String])
        }
    }
}
