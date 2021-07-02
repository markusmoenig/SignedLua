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
                
        /*
        NavigationView {
         List {
             NavigationLink(tag: NavigationItem.shapes, selection: $selection) {
                 ShapeView(model: model)
             } label: {
                 Label("Shapes", systemImage: "square")
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
        }*/
        
        HStack {
            List {
                Button(action: {
                    selection =  .shapes
                })
                {
                    Label("Shapes", systemImage: "square")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.leading, 6)
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                .listRowBackground(Group {
                    if selection == .shapes {
                        Color.accentColor.mask(RoundedRectangle(cornerRadius: 4))
                    } else { Color.clear }
                })
                
                Button(action: {
                    selection =  .materials
                })
                {
                    Label("Materials", systemImage: "light.max")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.leading, 6)
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                .listRowBackground(Group {
                    if selection == .materials {
                        Color.accentColor.mask(RoundedRectangle(cornerRadius: 4))
                    } else { Color.clear }
                })
                
                Button(action: {
                    selection =  .scripts
                })
                {
                    Label("Scripts", systemImage: "j.square")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.leading, 6)
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                .listRowBackground(Group {
                    if selection == .scripts {
                        Color.accentColor.mask(RoundedRectangle(cornerRadius: 4))
                    } else { Color.clear }
                })
            }
            .frame(maxWidth: 130)
            
            Divider()
            
            if selection == .shapes {
                ShapeView(model: model)
            }
            Spacer()
        }
        
        //.onReceive(model.componentPreviewNeedsUpdate) { _ in
        //}
        
        .onReceive(model.objectSelected) { object in

        }
    }
}
