//
//  DataView.swift
//  Signed
//
//  Created by Markus Moenig on 1/7/21.
//

import SwiftUI

struct Float3DataView: View {
    
    let model                               : Model
    let entity                              : SignedDataEntity
    
    @State private var xText                : String
    @State private var yText                : String
    @State private var zText                : String


    init(_ model: Model,_ entity: SignedDataEntity) {
        self.model = model
        self.entity = entity
        _xText = State(initialValue: String(format: "%.02f", entity.value.x))
        _yText = State(initialValue: String(format: "%.02f", entity.value.y))
        _zText = State(initialValue: String(format: "%.02f", entity.value.z))
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(entity.key)
            HStack {
                TextField("", text: $xText, onEditingChanged: { (changed) in
                })
                    .border(.red)
                TextField("", text: $yText, onEditingChanged: { (changed) in
                })
                    .border(.green)
                TextField("", text: $zText, onEditingChanged: { (changed) in
                })
                    .border(.blue)
            }
        }
    }
}


struct DataView: View {
    
    let model                               : Model
    let data                                : SignedData
    
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                
                ForEach(data.data, id: \.key) { entity in
                    if entity.type == .Float3 {
                        Float3DataView(model, entity)
                            .padding(2)
                            .padding(.leading, 6)
                            .padding(.trailing, 6)
                    }
                }
                Spacer()
            }
        }
    }
}
