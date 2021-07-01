//
//  ShapesView.swift
//  Signed
//
//  Created by Markus Moenig on 1/7/21.
//

import SwiftUI

class SignedShape {
    
    var id              = UUID()
    var name            : String
    
    init(_ name: String) {
        self.name = name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ShapesView: View {
    
    let model                               : Model
    
    var body: some View {
    
        let shapes : [SignedShape] = [SignedShape("Sphere"), SignedShape("Box")]

        let rows: [GridItem] = Array(repeating: .init(.fixed(80)), count: 1)
        
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows, alignment: .center) {
                ForEach(shapes, id: \.id) { shape in
                    Text(shape.name)
                }
            }
        }

    }
}
