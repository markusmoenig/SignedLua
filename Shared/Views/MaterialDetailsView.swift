//
//  SwiftUIView.swift
//  Signed
//
//  Created by Markus Moenig on 25/9/2564 BE.
//

import SwiftUI
import MarkdownUI

struct MaterialDetailsView: View {
    
    let model                               : Model
    
    @State var material                     : MaterialEntity
    
    init(model: Model, material: MaterialEntity) {
        self.model = model
        self._material = State(initialValue: material)
    }
        
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Create using")
                    .font(.headline)
                
                Button("command:newMaterial(\"\(material.name!)\")") {
                    copyToClipboard("local cmd = command:newMaterial(\"\(material.name!)\")")
                }
                    .background(Color.accentColor)
                    .font(.system(size: 12))
                    .padding(.top, 4)
                
                Text("execute with")
                    .font(.headline)
                
                Button(":execute(index)") {
                    copyToClipboard(":execute(0, { } )")
                }
                    .background(Color.accentColor)
                    .font(.system(size: 12))
                    .padding(.top, 4)
                
                Markdown("To layer materials use :setBlendMode( *mode*, { *options* } ) where mode is either \"valuenoise\" or \"linear\". ")
                
                Markdown("See material documentation for further details.")
            }
            .padding(2)
        }
                 
        .onReceive(model.dbMaterialSelected) { material in
            self.material = material
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
