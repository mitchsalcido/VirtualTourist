//
//  CoreDataController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//
/*
 About CoreDataController:
 Handle setup and config of Core Data stack. Provide functions for saving, deleting, and background operations. Also functionality for downloading albums from Flickr
 */
import Foundation
import CoreData

class CoreDataController {
    
    // container and context
    let container:NSPersistentContainer
    var viewContext:NSManagedObjectContext {
        return container.viewContext
    }
    
    // init with Data model name
    init(name: String) {
        self.container = NSPersistentContainer(name: name)
    }
    
    // load store
    func load() {
        container.loadPersistentStores { description, error in
            guard error == nil else {
                fatalError("Error loading Store: \(error!.localizedDescription)")
            }
            self.configureContext()
        }
    }
    
    // context config
    func configureContext() {
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }
    
    // Core Data errors
    enum CoreDataError: LocalizedError {
        case badSave
        case badFetch
        case badData
        
        var errorDescription: String? {
            switch self {
            case.badSave:
                return "Bad core data save."
            case .badFetch:
                return "Bad data fetch."
            case .badData:
                return "Bad data received."
            }
        }
        var failureReason: String? {
            switch self {
            case .badSave:
                return "Unable to save data."
            case .badFetch:
                return "Unable to retrieve data."
            case .badData:
                return "Bad data received in call."
            }
        }
        var helpAnchor: String? {
            return "Contact developer for prompt and courteous service."
        }
        var recoverySuggestion: String? {
            return "Close app and re-open."
        }
    }
}

// MARK: Background Op, Saving/Deleting Managed Objects
extension CoreDataController {

    // perform an operation on private queue
    func performBackgroundOp(completion: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            context.automaticallyMergesChangesFromParent = true
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            completion(context)
        }
    }
    
    // save context. Return true if good save
    @discardableResult func saveContext(context:NSManagedObjectContext, completion: @escaping (LocalizedError?) -> Void) -> Bool {
        do {
            try context.save()
            DispatchQueue.main.async {
                completion(nil)
            }
            return true
        } catch {
            DispatchQueue.main.async {
                completion(CoreDataError.badSave)
            }
            return false
        }
    }
    
    // delete managed objects
    func deleteManagedObjects(objects:[NSManagedObject], completion: @escaping (LocalizedError?) -> Void) {
        
        /*
         Retrieve object IDs for objects, retrieve objects from private context and delete
         */
        var objectIDs:[NSManagedObjectID] = []
        for object in objects {
            objectIDs.append(object.objectID)
        }
        self.performBackgroundOp { context in
            /*
             Retrieve objects into private queue and delete
             */
            for objectID in objectIDs {
                let privateObject = context.object(with: objectID)
                context.delete(privateObject)
            }
            
            // save
            self.saveContext(context: context, completion: completion)
        }
    }
}

// MARK: Loading Pin and Photos
extension CoreDataController {
    
    // (re)load a pin
    func reloadPin(pin:Pin, completion: @escaping (LocalizedError?) -> Void) {
        /*
         Loads new set of photos into Pin entity. A Flickr geosearch is performed. The result are parsed for urlString and title and used to create a Photo entity for each urlString.
         */
        
        // reset photoDownloadComplete and noPhotosFound attributes
        let objectID = pin.objectID
        performBackgroundOp { context in
            let privatePin = context.object(with: objectID) as! Pin
            privatePin.photoDownloadComplete = false
            privatePin.noPhotosFound = false
            if !self.saveContext(context: context, completion: completion) {
                return
            }
        }

        // new geo search
        FlickrAPI.geoSearchFlickr(latitude: pin.latitude, longitude: pin.longitude) { success, error in
            
            if success {
                /*
                 Create a new Photo for each URL found
                 */
                self.performBackgroundOp { context in
                    let privatePin = context.object(with: objectID) as! Pin
                    
                    // test for no photos found
                    if FlickrAPI.foundPhotosArray.isEmpty {
                        privatePin.noPhotosFound = true
                        privatePin.photoDownloadComplete = true
                    } else {
                        // good photos, continue creating new Photo objects
                        for dictionary in FlickrAPI.foundPhotosArray {
                            if let urlString = dictionary.keys.first, let title = dictionary.values.first {
                                
                                // create/config Photo
                                let photo = Photo(context: context)
                                photo.urlString = urlString
                                photo.title = title
                                photo.pin = privatePin
                            }
                        }
                    }
                    
                    // save context
                    if self.saveContext(context: context, completion: completion) {
                        if !privatePin.noPhotosFound {
                            /*
                             If Photos have been found, proceed to download Photos
                             */
                            self.resumePhotoDownload(pin: privatePin, completion: completion)
                        }
                    } else {
                        return
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(FlickrAPI.FlickrError.badFlickrDownload)
                }
            }
        }
    }
    
    // Download photos in Pin
    func resumePhotoDownload(pin:Pin, completion: @escaping (LocalizedError?) -> Void) {
        /*
         Download (or resume downloading) all photos in a Pin that have nil imageData.
         */
        let ojectID = pin.objectID
        self.performBackgroundOp { context in
            let privatePin = context.object(with: ojectID) as! Pin
            
            // retrieve photos and sort by urlString. This is the same order sorted in Pin Collection view. Forces photos to download in same order as presented.
            if var photos = privatePin.photos?.allObjects as? [Photo] {
                photos = photos.sorted(by: {$0.urlString! > $1.urlString!})
                
                for photo in photos {
                    // verify good URL and nil imageData (need new imageData)
                    if let urlString = photo.urlString, let url = URL(string: urlString), photo.imageData == nil {
                        // good URL and nil imageData for Photo...retireve imageData
                        do {
                            let data = try Data(contentsOf: url)
                            photo.imageData = data
                            if !self.saveContext(context: context, completion: completion) {
                                return
                            }
                        } catch {
                            DispatchQueue.main.async {
                                completion(CoreDataError.badData)
                            }
                            return
                        }
                    }
                }
                // download is complete. Set attribute and save.
                privatePin.photoDownloadComplete = true
                self.saveContext(context: context, completion: completion)
            }
        }
    }
}
