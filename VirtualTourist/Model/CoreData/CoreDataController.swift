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
            if let _ = try? context.save() {
            }
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
}
