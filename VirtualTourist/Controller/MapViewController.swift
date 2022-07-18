//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//
/*
 About MapViewController:
 Presents a mapView that allows the user to long-touch and place a dragable annotation view. Placement of annotation invokes the downloading of a Flickr geosearched album of random photos in the annotation geographic region.
 The annotations provide accessory views that allow user to delete the annotation or navigate to a view controller with a collection view that displays downloaded photos.
 */

import UIKit
import MapKit
import CoreData

// San Fran: 37.7749° N, -122.4194° W
// Chico CA: 39.73° N, -121.84° W
class MapViewController: UIViewController, MKMapViewDelegate {

    // ref to mapView
    @IBOutlet weak var mapView: MKMapView!
    
    // ref to CoreData stack
    var dataController:CoreDataController!
    
    /*
     ref to dragAnnotation. This annotation is used to track initial placement during long-touch gesture. The annotation tracks ubsequent state changes to gesture.
     */
    var dragAnnotation:PinAnnotation!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // retrieve dataController
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        dataController = appDelegate.dataController
        
        // info button to navigate to AppInfo
        let button = UIButton(type: .infoLight)
        button.addTarget(self, action: #selector(appInfoButtonPressed(_:)), for: .touchUpInside)
        let bbi = UIBarButtonItem(customView: button)
        navigationItem.rightBarButtonItem = bbi
        
        // retrieve saved Pins (photo albums)
        loadAnnotations()
    }
    
    // handle long-touch gesture (placement of Pin)
    @IBAction func longPressInMapViewDetected(_ sender: Any) {
        
        // retreive location of touch
        let longPressGr = sender as! UILongPressGestureRecognizer
        let pressLocation = longPressGr.location(in: mapView)
        let coordinate = mapView.convert(pressLocation, toCoordinateFrom: mapView)
        
        /*
         To implement dragging effect, the dragAnnotation tracks the state of the gesture, moving to new coordinate as touch location changes. When gesture ends, the annotation is placed and configured.
         */
        switch longPressGr.state {
        case .began:
            // place a new PinAnnotation
            dragAnnotation = PinAnnotation()
            dragAnnotation.coordinate = coordinate
            mapView.addAnnotation(dragAnnotation)
        case .changed:
            // move annotation as touch location changes
            dragAnnotation.coordinate = coordinate
        case .ended:
            // complete gesture by placing/configuring annotation
            configureAnnotation(dragAnnotation)
        default:
            break
        }
    }
}

// MARK: MapView Delegate
extension MapViewController {
    
    // handle creation of annotationView
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reUseID = "pinReuseID"
        let pinView: MKMarkerAnnotationView!
        
        // dequeue or create new if nil
        if let pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reUseID) as? MKMarkerAnnotationView {
            pinView.annotation = annotation
            return pinView
        } else {
            pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reUseID)
            pinView.canShowCallout = true
            
            // left accessory...delete photo album
            let leftAccessory = UIButton(type: .custom)
            leftAccessory.frame = CGRect(x: 0.0, y: 0.0, width: 22.0, height: 22.0)
            leftAccessory.setImage(UIImage(named: "DeleteAccessoryView"), for: .normal)
            pinView.leftCalloutAccessoryView = leftAccessory
            
            // right accessory...navigate to photo album, PinViewController
            let rightAccessory = UIButton(type: .custom)
            rightAccessory.frame = CGRect(x: 0.0, y: 0.0, width: 22.0, height: 22.0)
            rightAccessory.setImage(UIImage(named: "AlbumAccessoryView"), for: .normal)
            pinView.rightCalloutAccessoryView = rightAccessory
            
            pinView.animatesWhenAdded = true
        }
        return pinView
    }
    
    // handle callout accessory tap
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        // verify valid annotation
        guard let annotation = view.annotation as? PinAnnotation else {
            return
        }
        
        if control == view.leftCalloutAccessoryView {
            // left accessory. Delete annotation (and Pin/Photos)
            dataController.deleteManagedObjects(objects: [annotation.pin]) { error in
                if let error = error {
                    self.showOKAlert(error: error)
                }
            }
            mapView.removeAnnotation(annotation)
        } else {
            // right accessory. Navigate to PinViewController to view photos
            performSegue(withIdentifier: "PinSegueID", sender: annotation.pin)
        }
    }
}

// MARK: Segue
extension MapViewController {
    
    // handle segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PinSegueID" {
            // assign Pin to controller
            let controller = segue.destination as! PinViewController
            controller.pin = sender as? Pin
        }
    }
}

// MARK: Helpers
extension MapViewController {
    
    // handle loading persisted Pins
    fileprivate func loadAnnotations() {
        /*
         Retrieve persisted Pin managed objects and create annotations to add to mapView. For Pins with incomplete photo downloads, resume downloading remaining photos
         */
        
        // removing existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // fetch persisted Pin managed objects into an array
        var pins:[Pin] = []
        let fetchRequest:NSFetchRequest<Pin> = NSFetchRequest(entityName: "Pin")
        do {
            pins = try dataController.viewContext.fetch(fetchRequest)
        } catch {
            showOKAlert(error: CoreDataController.CoreDataError.badFetch)
        }
        
        // iterate and configure annotations using Pin attributes
        for pin in pins {
            let coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            let annotation = PinAnnotation()
            annotation.coordinate = coordinate
            annotation.title = pin.name
            annotation.pin = pin
            mapView.addAnnotation(annotation)

            // test for Pins with incomplete downloads. Resume downloading photos
            if !pin.photoDownloadComplete && !pin.noPhotosFound {
                dataController.resumePhotoDownload(pin: pin) { error in
                    if let error = error {
                        self.showOKAlert(error: error)
                    }
                }
            }
        }
    }
    
    // configure a new annotation that was placed on mapView
    fileprivate func configureAnnotation(_ annotation:PinAnnotation) {
        
        /*
         For a newly placed annotation, perform a reverse geocode to retrieve a string representing a location name (i.e. name of city, state, region, etc). In completion, create a new Pin object, configure, and save to store.
         */
        
        // retrieve location from annotation and invoke geocoding
        let coordinate = annotation.coordinate
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        FlickrAPI.reverseGeoCode(location: location) { name, error in
            
            // test for a valid location name. "Unknown" if no valid name string found
            if let name = name {
                annotation.title = name
            } else {
                annotation.title = "Unknown"
            }

            // create Pin managed object, configure and save
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
            
            // load a new set of photos for Pin/location
            self.dataController.reloadPin(pin: pin) { error in
                if let error = error {
                    self.showOKAlert(error: error)
                }
            }
        }
    }
    
    // navigate to AppInfoViewController
    @objc func appInfoButtonPressed(_ sender: Any) {
        performSegue(withIdentifier: "AppInfoSegueID", sender: nil)
    }
}
