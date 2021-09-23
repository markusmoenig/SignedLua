//
//  ShapeDetailsView.swift
//  Signed
//
//  Created by Markus Moenig on 23/9/2564 BE.
//

import SwiftUI

struct ShapeDetailsView: View {
    
    let model                               : Model
    
    @State var shape                        : SignedCommand
    
    init(model: Model, shape: SignedCommand) {
        self.model = model
        self._shape = State(initialValue: shape)
    }
        
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Create with")
                
                Button("command:newShape(\"\(shape.name)\")") {
                    copyToClipboard("local cmd = command:newShape(\"\(shape.name)\")")
                }
                    .font(.system(size: 11))
                    .padding(.top, 4)
            }
        }
                 
        .onReceive(model.shapeSelected) { shape in
            self.shape = shape
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
