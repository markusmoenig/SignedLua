//
//  LibraryView.swift
//  Signed
//
//  Created by Markus Moenig on 23/6/21.
//

import Foundation


import SwiftUI

struct LibraryView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext
/*
    @FetchRequest(
      entity: Component.entity(),
      sortDescriptors: [
        NSSortDescriptor(keyPath: \Component.name, ascending: true)
      ]
    ) var components: FetchedResults<Component>
    */
    //@State private var selection            : Component? = nil

    var body: some View {
        
        VStack {
               /*
            List {
                ForEach(components, id: \.self) { component in
                    //object.name.map(Text.init)
                    
                    Button(action: {
                        selection = component
                    })
                    {
                        //Label("Render", systemImage: "play.fill")
                        Text(component.name!)
                            .padding(.leading, 4)
                        Spacer()
                        Text(component.type!)
                            .padding(.trailing, 4)
                    }
                    
                        .swipeActions(edge: .trailing) {
                            Button {
                                self.managedObjectContext.delete(component)
                                try! managedObjectContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(Group {
                            if selection === component {
                                Color.accentColor.mask(RoundedRectangle(cornerRadius: 4))
                            } else { Color.clear }
                        })
                }
                //.onDelete(perform: deleteObject)

            }*/
        }
    }
}

