//
//  ObjectView.swift
//  Signed
//
//  Created by Markus Moenig on 27/6/21.
//

import SwiftUI

struct CommandView: View {
    
    let model                               : Model
    
    @State var selection                    : SignedObject? = nil
    
    var body: some View {
                
        VStack {
            HStack {

                Text("Hallo")
            }
        }
        
        .onReceive(model.componentPreviewNeedsUpdate) { _ in
        }
        
        .onReceive(model.objectSelected) { object in
            selection = object
            model.selectedObject = object
            model.selectedCommand = object.commands.first
            if let component = model.selectedCommand {
                model.scriptEditor?.setComponentSession(component)
            }
        }
    }
}
