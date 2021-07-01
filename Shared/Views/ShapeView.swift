//
//  ShapeView.swift
//  Signed
//
//  Created by Markus Moenig on 1/7/21.
//

import SwiftUI

struct ShapeView: View {
    
    let model                               : Model
    
    @State var selected                     : SignedShape? = nil
    
    init(model: Model) {
        self.model = model
        _selected = State(initialValue: model.shapes.first)
    }

    var body: some View {
    
        let rows: [GridItem] = Array(repeating: .init(.fixed(70)), count: 1)
        
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows, alignment: .center) {
                ForEach(model.shapes, id: \.id) { shape in
                    
                    ZStack(alignment: .center) {
                        Rectangle()
                            .fill(Color.secondary)
                            .frame(width: 60, height: 60)
                            .onTapGesture(perform: {
                                selected = shape
                            })
                        
                        if shape === selected {
                            Rectangle()
                                .stroke(Color.primary, lineWidth: 2)
                                .frame(width: 60, height: 60)
                                .allowsHitTesting(false)
                        }
                        
                        Text(shape.name)
                            .padding(.top, 40)
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding()
        }

    }
}
