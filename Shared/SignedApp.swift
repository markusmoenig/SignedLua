//
//  SignedApp.swift
//  Signed
//
//  Created by Markus Moenig on 12/12/20.
//

import SwiftUI

@main
struct SignedApp: App {
    
    @StateObject var storeManager = StoreManager()

    var body: some Scene {
        DocumentGroup(newDocument: SignedDocument()) { file in
            ContentView(document: file.$document, storeManager: storeManager)
        }
        .commands {
            SidebarCommands()
        }
    }
}
