//
//  SignedApp.swift
//  Signed
//
//  Created by Markus Moenig on 12/12/20.
//

import SwiftUI

@main
struct SignedApp: App {
    
    let persistenceController = PersistenceController.shared
    
    @StateObject var storeManager = StoreManager()
    
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        DocumentGroup(newDocument: SignedDocument()) { file in
            ContentView(document: file.$document, storeManager: storeManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .commands {
            SidebarCommands()
        }
        .onChange(of: scenePhase) { _ in
            persistenceController.save()
        }
    }
}
