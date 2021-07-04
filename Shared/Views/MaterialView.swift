//
//  MaterialView.swift
//  Signed
//
//  Created by Markus Moenig on 4/7/21.
//

import SwiftUI

struct MaterialView: View {
    
    let model                               : Model
    
    @State var selected                     : SignedCommand? = nil
    
    init(model: Model) {
        self.model = model
        _selected = State(initialValue: model.shapes.first)
    }

    var body: some View {
    
        let rows: [GridItem] = Array(repeating: .init(.fixed(70)), count: 1)
        
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows, alignment: .center) {
                ForEach(model.materials, id: \.id) { material in
                    
                    ZStack(alignment: .center) {
                        
                        if let image = material.icon {
                            Image(image, scale: 1.0, label: Text(material.name))
                                .onTapGesture(perform: {
                                    selected = material
                                    model.selectedMaterial = material
                                    model.editingCmd.copyMaterial(from: material)
                                    model.materialSelected.send(material)
                                    model.editingCmdChanged.send(model.editingCmd)
                                    model.renderer?.restart()
                                })
                        } else {
                            Rectangle()
                                .fill(Color.secondary)
                                .frame(width: 60, height: 60)
                                .onTapGesture(perform: {
                                    selected = material
                                    model.selectedMaterial = material
                                    model.editingCmd.copyMaterial(from: material)
                                    model.materialSelected.send(material)
                                    model.editingCmdChanged.send(model.editingCmd)
                                    model.renderer?.restart()
                                })
                        }
                        
                        if material === selected {
                            Rectangle()
                                .stroke(Color.primary, lineWidth: 2)
                                .frame(width: 60, height: 60)
                                .allowsHitTesting(false)
                        }
                        
                        Text(material.name)
                            .padding(.top, 40)
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding()
        }

        .onReceive(model.iconFinished) { cmd in
            let buffer = selected
            selected = nil
            selected = buffer
            print("finished", cmd.name)
        }
    }
}
