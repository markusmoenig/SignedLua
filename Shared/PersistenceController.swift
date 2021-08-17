//
//  PersistenceController.swift
//  Signed
//
//  Created by Markus Moenig on 23/6/21.
//

import Foundation
import CoreData
import CloudKit

struct PersistenceController {
    // A singleton for our entire app to use
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        
        container = NSPersistentCloudKitContainer(name: "DataModel")

        /*
         let datamodelName = "DataModel"
         let storeType = "sqlite"
        
         let url: URL = {
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("\(datamodelName).\(storeType)")

            //assert(FileManager.default.fileExists(atPath: url.path))

            return url
        }()
        
        try! container.persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: storeType, options: nil)
        */

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Error")
        }
        
        description.cloudKitContainerOptions?.databaseScope = .public
        
        //description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        //description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Save the context if it has changes
    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
