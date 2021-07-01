//
//  ObjectView.swift
//  Signed
//
//  Created by Markus Moenig on 27/6/21.
//

import SwiftUI

struct BrowserView: View {
        
    enum NavigationItem {
        case shapes
        case materials
        case scripts
    }
    
    let model                               : Model
    
    @State private var selection            : NavigationItem? = .shapes

    var body: some View {
                
        NavigationView {
            List {
                NavigationLink(tag: NavigationItem.shapes, selection: $selection) {
                    ShapesView(model: model)
                } label: {
                    Label("Shapes", systemImage: "circle.fill")
                }
                
                NavigationLink(tag: NavigationItem.materials, selection: $selection) {
                } label: {
                    Label("Materials", systemImage: "book.closed")
                }
                
                NavigationLink(tag: NavigationItem.scripts, selection: $selection) {
                    Text("Scripts")
                } label: {
                    Label("Scripts", systemImage: "heart")
                }
            
            }
        }
        
        .onReceive(model.componentPreviewNeedsUpdate) { _ in
        }
        
        .onReceive(model.objectSelected) { object in

        }
    }
}
