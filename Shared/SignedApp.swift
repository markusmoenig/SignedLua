//
//  SignedApp.swift
//  Shared
//
//  Created by Markus Moenig on 12/12/20.
//

import SwiftUI

@main
struct SignedApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: SignedDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
