//
//  CoreDataController.swift
//  VirtualTourist
//
//  Created by Mitchell Salcido on 6/26/22.
//

import Foundation
import CoreData

class CoreDataController {
    
    let container:NSPersistentContainer
    var viewContext:NSManagedObjectContext {
        return container.viewContext
    }
    
    init(name: String) {
        self.container = NSPersistentContainer(name: name)
    }
    
    func load() {
        container.loadPersistentStores { description, error in
            guard error == nil else {
                fatalError("Error loading Store: \(error!.localizedDescription)")
            }
            self.configureContext()
        }
    }
    
    func configureContext() {
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }
    
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
    
    func deleteManagedObjects(objects:[NSManagedObject], completion: @escaping (LocalizedError?) -> Void) {
        
        var objectIDs:[NSManagedObjectID] = []
        for object in objects {
            objectIDs.append(object.objectID)
        }
        self.performBackgroundOp { context in
            
            for objectID in objectIDs {
                let privateObject = context.object(with: objectID)
                context.delete(privateObject)
            }
            self.saveContext(context: context, completion: completion)
        }
    }
}

// MARK: Loading Album and Flicks
extension CoreDataController {
    
    func reloadAlbum(album:Album, completion: @escaping (LocalizedError?) -> Void) {
        
        let objectID = album.objectID
        performBackgroundOp { context in
            let privateAlbum = context.object(with: objectID) as! Album
            privateAlbum.flickDownloadComplete = false
            privateAlbum.noFlicksFound = false
            if !self.saveContext(context: context, completion: completion) {
                return
            }
        }

        // new search
        FlickrAPI.geoSearchFlickr(latitude: album.latitude, longitude: album.longitude) { success, error in

            if success {
                self.performBackgroundOp { context in
                    let privateAlbum = context.object(with: objectID) as! Album
                    
                    if FlickrAPI.foundFlicksArray.isEmpty {
                        privateAlbum.noFlicksFound = true
                        privateAlbum.flickDownloadComplete = true
                    } else {
                        for dictionary in FlickrAPI.foundFlicksArray {
                            if let urlString = dictionary.keys.first, let title = dictionary.values.first {
                                
                                let flick = Flick(context: context)
                                flick.urlString = urlString
                                flick.title = title
                                flick.album = privateAlbum
                            }
                        }
                    }
                    if self.saveContext(context: context, completion: completion) {
                        if !privateAlbum.noFlicksFound {
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
    
    func resumeFlickDownload(album:Album, completion: @escaping (LocalizedError?) -> Void) {
        
        let ojectID = album.objectID
        self.performBackgroundOp { context in
            let privateAlbum = context.object(with: ojectID) as! Album
            
            if var flicks = privateAlbum.flicks?.allObjects as? [Flick] {
                flicks = flicks.sorted(by: {$0.urlString! > $1.urlString!})
                
                for flick in flicks {
                    
                    if let urlString = flick.urlString, let url = URL(string: urlString), flick.imageData == nil {
                        
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
                privateAlbum.flickDownloadComplete = true
                self.saveContext(context: context, completion: completion)
            }
        }
    }
}
