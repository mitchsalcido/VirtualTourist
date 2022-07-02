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

extension CoreDataController {
    
    func reloadAlbum(album:Album, completion: @escaping () -> Void) {
        
        FlickrAPI.geoSearchFlickr(latitude: album.latitude, longitude: album.longitude) { success, error in

            if success {
                let objectID = album.objectID
                self.container.performBackgroundTask { context in
                    context.automaticallyMergesChangesFromParent = true
                    context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
                    let privateAlbum = context.object(with: objectID) as! Album
                    
                    for dictionary in FlickrAPI.foundFlicksArray {
                        if let urlString = dictionary.keys.first, let title = dictionary.values.first {
                            
                            let flick = Flick(context: context)
                            flick.urlString = urlString
                            flick.title = title
                            flick.album = privateAlbum
                        }
                    }
                    if let _ = try? context.save() {
                        self.resumeFlickDownload(album: privateAlbum) {
                        }
                    }
                }
            }
        }
    }
    
    func resumeFlickDownload(album:Album, completion: @escaping () -> Void) {
        
        let objectID = album.objectID
        self.container.performBackgroundTask { context in
            context.automaticallyMergesChangesFromParent = true
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            let privateAlbum = context.object(with: objectID) as! Album
            
            if let flicks = privateAlbum.flicks?.allObjects as? [Flick] {
                for flick in flicks {
                    
                    if let urlString = flick.urlString, let url = URL(string: urlString), flick.imageData == nil {
                        FlickrAPI.getFlickData(url: url) { data, error in
                            print("downloading flick data")
                            if let data = data {
                                flick.imageData = data
                                if let _ = try? context.save() {
                                    print("good download...saved")
                                }
                            }
                        }
                    } else {
                        print("already downloaded flick")
                    }
                }
            }
        }
    }
}
