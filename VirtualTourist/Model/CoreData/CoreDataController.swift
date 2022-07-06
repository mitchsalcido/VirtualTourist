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
        
        var errorDescription: String? {
            switch self {
            case.badSave:
                return "Bad core data save."
            case .badFetch:
                return "Bad data fetch."
            }
        }
        var failureReason: String? {
            switch self {
            case .badSave:
                return "Unable to save data."
            case .badFetch:
                return "Unable to retrieve data."
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


// MARK: Saving/Deleting Managed Objects
extension CoreDataController {

    func deleteManagedObjects(objects:[NSManagedObject], completion: @escaping (LocalizedError?) -> Void) {
        
        var objectIDs:[NSManagedObjectID] = []
        for object in objects {
            objectIDs.append(object.objectID)
        }
        container.performBackgroundTask { context in
            context.automaticallyMergesChangesFromParent = true
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            
            for objectID in objectIDs {
                let privateObject = context.object(with: objectID)
                context.delete(privateObject)
            }
            do {
                try context.save()
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(CoreDataError.badSave)
                }
            }
        }
    }
}

// MARK: Loading Album and Flicks
extension CoreDataController {
    
    func reloadAlbum(album:Album, completion: @escaping (LocalizedError?) -> Void) {
        
        let objectID = album.objectID
        container.performBackgroundTask { context in
            context.automaticallyMergesChangesFromParent = true
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            let album = context.object(with: objectID) as! Album
            album.flickDownloadComplete = false
            album.noFlicksFound = false
            do {
                try context.save()
            } catch {
                DispatchQueue.main.async {
                    completion(CoreDataError.badSave)
                }
                return
            }
        }
        
        // new search
        FlickrAPI.geoSearchFlickr(latitude: album.latitude, longitude: album.longitude) { success, error in

            if success {
                let objectID = album.objectID
                self.container.performBackgroundTask { context in
                    context.automaticallyMergesChangesFromParent = true
                    context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
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
                    
                    do {
                        try context.save()
                        if !privateAlbum.noFlicksFound {
                            self.resumeFlickDownload(album: privateAlbum, completion:completion)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            completion(CoreDataError.badSave)
                        }
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
        self.container.performBackgroundTask { context in
            context.automaticallyMergesChangesFromParent = true
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            let privateAlbum = context.object(with: ojectID) as! Album
            
            if var flicks = privateAlbum.flicks?.allObjects as? [Flick] {
                flicks = flicks.sorted(by: {$0.urlString! > $1.urlString!})
                
                for flick in flicks {
                    
                    if let urlString = flick.urlString, let url = URL(string: urlString), flick.imageData == nil {
                        
                        do {
                            let data = try Data(contentsOf: url)
                            flick.imageData = data
                            do {
                                try context.save()
                            } catch {
                                DispatchQueue.main.async {
                                    completion(CoreDataError.badSave)
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                completion(CoreDataError.badSave)
                            }
                            return
                        }
                    }
                }
                privateAlbum.flickDownloadComplete = true
                do {
                    try context.save()
                } catch {
                    DispatchQueue.main.async {
                        completion(CoreDataError.badSave)
                    }
                    return
                }
            }
        }
    }
}
