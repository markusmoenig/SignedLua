//
//  ShapeView.swift
//  Signed
//
//  Created by Markus Moenig on 1/7/21.
//

import SwiftUI

struct ShapeView: View {
    
    let model                               : Model
    
    @State var selected                     : SignedCommand? = nil
    
    init(model: Model) {
        self.model = model
        _selected = State(initialValue: model.selectedShape)
    }

    var body: some View {
    
        let rows: [GridItem] = Array(repeating: .init(.fixed(70)), count: 1)
        
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows, alignment: .center) {
                ForEach(model.shapes, id: \.id) { shape in
                    
                    ZStack(alignment: .center) {
                        
                        if let image = shape.icon {
                            Image(image, scale: 1.0, label: Text(shape.name))
                                .onTapGesture(perform: {
                                    selected = shape
                                    model.selectedShape = shape
                                    model.editingCmd.copyGeometry(from: shape)
                                    model.shapeSelected.send(shape)
                                    model.editingCmdChanged.send(model.editingCmd)
                                    model.renderer?.restart()
                                })
                        } else {
                            Rectangle()
                                .fill(Color.secondary)
                                .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                .onTapGesture(perform: {
                                    selected = shape
                                    model.selectedShape = shape
                                    model.editingCmd.copyGeometry(from: shape)
                                    model.shapeSelected.send(shape)
                                    model.editingCmdChanged.send(model.editingCmd)
                                    model.renderer?.restart()
                                })
                        }
                        
                        if shape === selected {
                            Rectangle()
                                .stroke(Color.accentColor, lineWidth: 2)
                                .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                .allowsHitTesting(false)
                        }
                        
                        Rectangle()
                            .fill(.black)
                            .opacity(0.4)
                            .frame(width: CGFloat(ModelerPipeline.IconSize - (shape === selected ? 2 : 0)), height: CGFloat(20 - (shape === selected ? 1 : 0)))
                            .padding(.top, CGFloat(ModelerPipeline.IconSize - (20 + (shape === selected ? 1 : 0))))
                        
                        Text(shape.name)
                            .padding(.top, CGFloat(ModelerPipeline.IconSize - 20))
                            .allowsHitTesting(false)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }

        .onReceive(model.iconFinished) { cmd in
            let buffer = selected
            selected = nil
            selected = buffer
            //print("finished", cmd.name)
        }
    }
}
