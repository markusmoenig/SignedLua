//
//  DataView.swift
//  Signed
//
//  Created by Markus Moenig on 1/7/21.
//

import SwiftUI

/// FloatSliderParameterView
struct FloatDataView: View {
    let model                               : Model
    let entity                              : SignedDataEntity
    
    @State var value                        : Double = 0
    @State var valueText                    : String = ""

    init(_ model: Model,_ entity: SignedDataEntity)
    {
        self.model = model
        self.entity = entity
        
        _value = State(initialValue: Double(entity.value.x))
        _valueText = State(initialValue: String(format: "%.02f", entity.value.x))
    }

    var body: some View {

        VStack(alignment: .leading) {
            Text(entity.key)
            HStack {
                Slider(value: Binding<Double>(get: {value}, set: { v in
                    value = v
                    valueText = String(format: "%.02f", v)

                    entity.value.x = Float(value)
                    model.renderer?.restart()
                }), in: Double(entity.range.x)...Double(entity.range.y))//, step: Double(parameter.step))
                Text(valueText)
                    .frame(maxWidth: 40)
            }
        }
        
        .onReceive(model.updateDataViews) { _ in
            valueText = String(format: "%.02f", entity.value.x)
        }
    }
}

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
                TextField("", text: $xText, onEditingChanged: { changed in
                    if let v = Float(xText) {
                        entity.value.x = v
                        model.renderer?.restart()
                    }
                })
                    .border(.red)
                TextField("", text: $yText, onEditingChanged: { changed in
                    if let v = Float(yText) {
                        entity.value.y = v
                        model.renderer?.restart()
                    }
                })
                    .border(.green)
                TextField("", text: $zText, onEditingChanged: { changed in
                    if let v = Float(zText) {
                        entity.value.z = v
                        model.renderer?.restart()
                    }
                })
                    .border(.blue)
            }
        }
        
        .onReceive(model.updateDataViews) { _ in
            xText = String(format: "%.02f", entity.value.x)
            yText = String(format: "%.02f", entity.value.y)
            zText = String(format: "%.02f", entity.value.z)
        }
    }
}

struct DataView: View {
    
    let model                               : Model
    let data                                : SignedData
    
    @State var updateView                   : Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                
                ForEach(data.data, id: \.id) { entity in
                    if entity.type == .Float {
                        FloatDataView(model, entity)
                            .padding(2)
                            .padding(.leading, 6)
                            .padding(.trailing, 6)
                    }
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
