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

    // perform an operation on provate queue
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
             On provate queue, retrieve objects into private queue and delete
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

// MARK: Loading Album and Flicks
extension CoreDataController {
    
    // (re)load an album
    func reloadAlbum(album:Album, completion: @escaping (LocalizedError?) -> Void) {
        /*
         Loads new set of flicks into Album entity. A Flickr geosearch os performed. The result are parsed for urlString and title and used to create a Flick for each urlString.
         */
        
        // reset flickDownloadComplete and noFlicksFound attributes
        let objectID = album.objectID
        performBackgroundOp { context in
            let privateAlbum = context.object(with: objectID) as! Album
            privateAlbum.flickDownloadComplete = false
            privateAlbum.noFlicksFound = false
            if !self.saveContext(context: context, completion: completion) {
                return
            }
        }

        // new geo search
        FlickrAPI.geoSearchFlickr(latitude: album.latitude, longitude: album.longitude) { success, error in
            
            if success {
                /*
                 Create a new Flick for each URL found
                 */
                self.performBackgroundOp { context in
                    let privateAlbum = context.object(with: objectID) as! Album
                    
                    // test for no flicks found
                    if FlickrAPI.foundFlicksArray.isEmpty {
                        privateAlbum.noFlicksFound = true
                        privateAlbum.flickDownloadComplete = true
                    } else {
                        // good flicks, continue creating new Flick objects
                        for dictionary in FlickrAPI.foundFlicksArray {
                            if let urlString = dictionary.keys.first, let title = dictionary.values.first {
                                
                                // create/config Flick
                                let flick = Flick(context: context)
                                flick.urlString = urlString
                                flick.title = title
                                flick.album = privateAlbum
                            }
                        }
                    }
                    
                    // save context
                    if self.saveContext(context: context, completion: completion) {
                        if !privateAlbum.noFlicksFound {
                            /*
                             If Flicks have been found, proceed to download Flicks
                             */
                            self.resumeFlickDownload(album: privateAlbum, completion: completion)
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
    
    // Download Flicks in an album
    func resumeFlickDownload(album:Album, completion: @escaping (LocalizedError?) -> Void) {
        /*
         Download (or resume downloading) all Flicks in an album that have nil imageData.
         */
        let ojectID = album.objectID
        self.performBackgroundOp { context in
            let privateAlbum = context.object(with: ojectID) as! Album
            
            // retrieve Flicks and sort by urlString. This is the same order sorted in Album Collection view. Forces Flicks to download in same order as presentation.
            if var flicks = privateAlbum.flicks?.allObjects as? [Flick] {
                flicks = flicks.sorted(by: {$0.urlString! > $1.urlString!})
                
                for flick in flicks {
                    // verify good URL and nil imageData (need new imageData)
                    if let urlString = flick.urlString, let url = URL(string: urlString), flick.imageData == nil {
                        // good URL and nil imageData for Flick...retireve imageData
                        do {
                            let data = try Data(contentsOf: url)
                            flick.imageData = data
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
                privateAlbum.flickDownloadComplete = true
                self.saveContext(context: context, completion: completion)
            }
        }
    }
}
