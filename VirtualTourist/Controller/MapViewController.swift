//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//

import UIKit
import MapKit
import CoreData

// San Fran: 37.7749° N, -122.4194° W
// Chico CA: 39.73° N, -121.84° W
class MapViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    var dataController:CoreDataController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        dataController = appDelegate.dataController
        
        let button = UIButton(type: .infoLight)
        button.addTarget(self, action: #selector(appInfoButtonPressed(_:)), for: .touchUpInside)
        let bbi = UIBarButtonItem(customView: button)
        navigationItem.rightBarButtonItem = bbi
        
        loadAnnotations()
    }
    
    @IBAction func longPressInMapViewDetected(_ sender: Any) {
        let longPressGr = sender as! UILongPressGestureRecognizer
        if longPressGr.state != .began {
            return
        }
        let pressLocation = longPressGr.location(in: mapView)
        let coordinate = mapView.convert(pressLocation, toCoordinateFrom: mapView)
        newAnnotation(coordinate)
    }
}

// MARK: MapView Delegate
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
        
        guard let annotation = view.annotation as? PinAnnotation else {
            return
        }
        
        if control == view.leftCalloutAccessoryView {
            dataController.deleteManagedObjects(objects: [annotation.pin]) { error in
                if let error = error {
                    self.showOKAlert(error: error)
                }
            }
            mapView.removeAnnotation(annotation)
        } else {
            performSegue(withIdentifier: "PinSegueID", sender: annotation.pin)
        }
    }
}

// MARK: Segue
extension MapViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PinSegueID" {
            let controller = segue.destination as! PinViewController
            controller.pin = sender as? Pin
        }
    }
}

// MARK: Helpers
extension MapViewController {
    
    fileprivate func loadAnnotations() {
        
        mapView.removeAnnotations(mapView.annotations)
        
        var pins:[Pin] = []
        let fetchRequest:NSFetchRequest<Pin> = NSFetchRequest(entityName: "Pin")
        do {
            pins = try dataController.viewContext.fetch(fetchRequest)
        } catch {
            showOKAlert(error: CoreDataController.CoreDataError.badFetch)
        }
        
        for pin in pins {
            let coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            let annotation = PinAnnotation(coordinate: coordinate)
            annotation.title = pin.name
            annotation.pin = pin
            mapView.addAnnotation(annotation)

            if !pin.photoDownloadComplete && !pin.noPhotosFound {
                dataController.resumePhotoDownload(pin: pin) { error in
                    if let error = error {
                        self.showOKAlert(error: error)
                    }
                }
            }
        }
    }
    
    fileprivate func newAnnotation(_ coordinate: CLLocationCoordinate2D) {
        let annotation = PinAnnotation(coordinate: coordinate)
        
        let location = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
        FlickrAPI.reverseGeoCode(location: location) { name, error in
            
            if let name = name {
                annotation.title = name
            } else {
                annotation.title = "Unknown"
            }
            self.mapView.addAnnotation(annotation)
            
            let pin = Pin(context: self.dataController.viewContext)
            pin.longitude = coordinate.longitude
            pin.latitude = coordinate.latitude
            pin.name = annotation.title
            annotation.pin = pin
            self.dataController.saveContext(context: self.dataController.viewContext) { error in
                if let error = error {
                    self.showOKAlert(error: error)
                }
            }
            
            self.dataController.reloadPin(pin: pin) { error in
                if let error = error {
                    self.showOKAlert(error: error)
                }
            }
        }
    }
    
    @objc func appInfoButtonPressed(_ sender: Any) {
        performSegue(withIdentifier: "AppInfoSegueID", sender: nil)
    }
}
