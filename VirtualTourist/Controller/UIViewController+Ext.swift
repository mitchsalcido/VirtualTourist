//
//  UIViewController+Ext.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 7/1/22.
//

import UIKit
import CoreData
import MapKit

extension UIViewController {
    
    func reloadAlbum(coordinate: CLLocationCoordinate2D, album: Album, completion: @escaping () -> Void) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let dataController = appDelegate.dataController
        
        // delete existing flicks
        if let flicks = album.flicks?.allObjects as? [Flick] {
            for flick in flicks {
                dataController?.deleteObject(object: flick)
            }
        }
        
        FlickrAPI.geoSearchFlickr(latitude: coordinate.latitude, longitude: coordinate.longitude) { success, error in
            
            if success {
                for dictionary in FlickrAPI.foundFlicksArray {
                    if let urlString = dictionary.keys.first, let title = dictionary.values.first {
                        
                        let objectID = album.objectID
                        dataController?.container.performBackgroundTask({ context in
                            context.automaticallyMergesChangesFromParent = true
                            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
                            
                            let album = context.object(with: objectID) as! Album
                            let flick = Flick(context: context)
                            flick.urlString = urlString
                            flick.title = title
                            flick.album = album
                            if let _ = try? context.save() {}
                        })
                    }
                }
                completion()
            }
        }
    }
}
