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
}


// MARK: Adding/Deleting Managed Objects
extension CoreDataController {
    
    func newManagedObject<ObjectType:NSManagedObject>(objectType:ObjectType.Type, completion: @escaping (ObjectType) -> Void) {
        
        container.performBackgroundTask { context in
            context.automaticallyMergesChangesFromParent = true
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            
            let newObject = ObjectType(context: context)
            completion(newObject)
            if let _ = try? context.save() {}
        }
    }

    func deleteObject(object: NSManagedObject) {
        let objectID = object.objectID
        container.performBackgroundTask { context in
            context.automaticallyMergesChangesFromParent = true
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            
            let object = context.object(with: objectID)
            context.delete(object)
            if let _ = try? context.save() {}
        }
    }
    
    func deleteManagedObjects(objects:[NSManagedObject], completion: @escaping (Error?) -> Void) {
        
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
                    completion(error)
                }
            }
        }
    }
}

// MARK: Loading Album and Flicks
extension CoreDataController {
    
    func reloadAlbum(album:Album, completion: @escaping (Error?) -> Void) {

        let objectID = album.objectID
        container.performBackgroundTask { context in
            let album = context.object(with: objectID) as! Album
            album.flickDownloadComplete = false
            album.noFlicksFound = false
            if let _ = try? context.save() {}
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
                        album.noFlicksFound = true
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
                    
                    if let _ = try? context.save() {
                        self.resumeFlickDownload(album: privateAlbum)
                    }
                }
            } else {
                if let error = error {
                    DispatchQueue.main.async {
                        completion(error)
                    }
                }
            }
        }
    }
    
    func resumeFlickDownload(album:Album) {
        
        let ojectID = album.objectID
        self.container.performBackgroundTask { context in
            context.automaticallyMergesChangesFromParent = true
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            let privateAlbum = context.object(with: ojectID) as! Album
            
            if var flicks = privateAlbum.flicks?.allObjects as? [Flick] {
                flicks = flicks.sorted(by: {$0.urlString! > $1.urlString!})
                
                for flick in flicks {
                    
                    if let urlString = flick.urlString, let url = URL(string: urlString), flick.imageData == nil {
                        if let data = try? Data(contentsOf: url) {
                            flick.imageData = data
                            if let _ = try? context.save() {}
                        }
                    }
                }
                privateAlbum.flickDownloadComplete = true
                if let _ = try? context.save() {}
            }
        }
    }
}
