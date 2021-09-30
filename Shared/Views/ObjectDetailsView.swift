//
//  ObjectDetailsView.swift
//  Signed
//
//  Created by Markus Moenig on 25/9/2564 BE.
//

import SwiftUI
import MarkdownUI

struct ObjectDetailsView: View {
    
    let model                               : Model
    
    @State var object                       : ObjectEntity
    
    init(model: Model, object: ObjectEntity) {
        self.model = model
        self._object = State(initialValue: object)
    }
        
    var body: some View {
        
        Text(object.name!)
            .font(.title2)

        ScrollView {
            VStack(alignment: .leading) {
                Text("Create using")
                    .font(.headline)
                
                Button("command:newObject(\"\(object.name!)\", bbox)") {
                    copyToClipboard("local bbox = bbox:new( vec3(0, 0, 0), vec3(1, 1, 1) )\nlocal cmd = command:newObject(\"\(object.name!)\", bbox)")
                }
                    .background(Color.accentColor)
                    .font(.system(size: 12))
                    .padding(.top, 4)
                
                Text("execute with")
                    .font(.headline)
                
                Button(":execute(id, { *options* } )") {
                    copyToClipboard(":execute(0, { } )")
                }
                    .background(Color.accentColor)
                    .font(.system(size: 12))
                    .padding(.top, 4)
                
                Markdown("Reference the object source code for a list of supported options.")
            }
            .padding(2)
        }
                 
        .onReceive(model.dbObjectSelected) { object in
            self.object = object
        }
    }
    
    func copyToClipboard(_ str: String) {
        #if os(iOS)
        UIPasteboard.general.string = str
        #elseif os(OSX)
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(str, forType: .string)
        #endif
    }
}
