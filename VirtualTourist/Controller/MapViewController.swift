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
        
        guard let annotation = view.annotation as? FlickrAnnotation else {
            return
        }
        
        if control == view.leftCalloutAccessoryView {
            dataController.deleteObject(object: annotation.album)
            mapView.removeAnnotation(annotation)
        } else {
            performSegue(withIdentifier: "AlbumSegueID", sender: annotation.album)
        }
    }
}

// MARK: Segue
extension MapViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AlbumSegueID" {
            let controller = segue.destination as! AlbumViewController
            controller.album = sender as? Album
        }
    }
}

// MARK: Helpers
extension MapViewController {
    
    fileprivate func loadAnnotations() {
        
        mapView.removeAnnotations(mapView.annotations)
        
        var albums:[Album] = []
        let fetchRequest:NSFetchRequest<Album> = NSFetchRequest(entityName: "Album")
        do {
            albums = try dataController.viewContext.fetch(fetchRequest)
        } catch {
            showOKAlert(error: error)
        }
        
        for album in albums {
            let coordinate = CLLocationCoordinate2D(latitude: album.latitude, longitude: album.longitude)
            let annotation = FlickrAnnotation(coordinate: coordinate)
            annotation.title = album.name
            annotation.album = album
            mapView.addAnnotation(annotation)
            
            if !album.flickDownloadComplete {
                dataController.resumeFlickDownload(album: album)
            }
        }
    }
    
    fileprivate func newAnnotation(_ coordinate: CLLocationCoordinate2D) {
        let annotation = FlickrAnnotation(coordinate: coordinate)
        
        let location = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
        FlickrAPI.reverseGeoCode(location: location) { name, error in
            
            if let name = name {
                annotation.title = name
            } else {
                annotation.title = "Unknown"
            }
            self.mapView.addAnnotation(annotation)
            
            let album = Album(context: self.dataController.viewContext)
            album.longitude = coordinate.longitude
            album.latitude = coordinate.latitude
            album.name = annotation.title
            annotation.album = album
            if let _ = try? self.dataController.viewContext.save() {}
            
            self.dataController.reloadAlbum(album: album) { error in
                if let error = error {
                    self.showOKAlert(error: error)
                }
            }
        }
    }
}
