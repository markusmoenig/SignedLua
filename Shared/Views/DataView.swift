//
//  DataView.swift
//  Signed
//
//  Created by Markus Moenig on 1/7/21.
//

import SwiftUI

/// DataFloatSliderView
struct DataFloatSliderView: View {
    
    let model                               : Model

    var value                               : Binding<Float>
    var range                               : Binding<float2>

    @State var valueText                    : String = ""
    @State var clipWidth                    : CGFloat = 0
    
    @State var color                        : Color

    init(_ model: Model,_ value :Binding<Float>,_ range: Binding<float2>,_ color: Color = Color.accentColor)
    {
        self.model = model
        self.value = value
        self.range = range
        self.color = color

        _valueText = State(initialValue: String(format: "%.02f", value.wrappedValue))
    }

    var body: some View {
            
        GeometryReader { geom in
            Canvas { context, size in
                context.fill(
                    Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8),
                    with: .color(.gray))
                
                var maskedContext = context

                maskedContext.clip(
                    to: Path(roundedRect: CGRect(origin: .zero, size: CGSize(width: getClipWidth(size.width), height: size.height)), cornerRadius: 0))
                
                maskedContext.fill(
                    Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8),
                    with: .color(color))

                context.draw(Text(valueText), at: CGPoint(x: geom.size.width / 2, y: geom.size.height), anchor: .center)
                
            }
            .frame(width: geom.size.width, height: 19)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                
                    .onChanged({ info in
                        
                        let offset = Float(info.location.x / geom.size.width)
                
                        let r = range.wrappedValue
                
                        var newValue = r.x + (r.y - r.x) * offset
                        newValue = max(newValue, r.x)
                        newValue = min(newValue, r.y)
                    
                        value.wrappedValue = newValue
                        valueText = String(format: "%.02f",  newValue)
                    })
                    .onEnded({ info in
                    })
            )
        }
        
        .onReceive(model.updateDataViews) { _ in
            valueText = String(format: "%.02f", value.wrappedValue)
        }
    }
    
    func getClipWidth(_ width: CGFloat) -> CGFloat {
        let v = value.wrappedValue
        let r = range.wrappedValue

        let off = CGFloat((v - r.x) / (r.y - r.x))
        return off * width
    }
}

/// FloatSliderParameterView
struct FloatDataView: View {
    let model                               : Model
    let entity                              : SignedDataEntity
    
    @State var value                        : Float = 0
    @State var valueRange                   = float2()

    init(_ model: Model,_ entity: SignedDataEntity)
    {
        self.model = model
        self.entity = entity
        
        _value = State(initialValue: entity.value.x)
        _valueRange = State(initialValue: entity.range)
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(entity.key)
                Spacer()
                Button(action: {
                    entity.value = entity.defaultValue
                    model.updateDataViews.send()
                })
                {
                    Image(systemName: "x.circle")
                }
                .buttonStyle(.borderless)
            }
            DataFloatSliderView(model, $value, $valueRange)
        }
        
        .onReceive(model.updateDataViews) { _ in
            value = entity.value.x
        }
        
        .onChange(of: value) { value in
            entity.value.x = value
            model.renderer?.restart()
        }
    }
}

/*
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
 */

struct Float3DataView: View {
    
    let model                               : Model
    let entity                              : SignedDataEntity
    
    @State var xValue                       : Float = 0
    @State var yValue                       : Float = 0
    @State var zValue                       : Float = 0
    @State var valueRange                   = float2()

    init(_ model: Model,_ entity: SignedDataEntity) {
        self.model = model
        self.entity = entity

        _xValue = State(initialValue: entity.value.x)
        _yValue = State(initialValue: entity.value.y)
        _zValue = State(initialValue: entity.value.z)
        _valueRange = State(initialValue: entity.range)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(entity.key)
                Spacer()
                Button(action: {
                    entity.value = entity.defaultValue
                    model.updateDataViews.send()
                })
                {
                    Image(systemName: "x.circle")
                }
                .buttonStyle(.borderless)
            }
            HStack {
                DataFloatSliderView(model, $xValue, $valueRange, .red)
                DataFloatSliderView(model, $yValue, $valueRange, .green)
                DataFloatSliderView(model, $zValue, $valueRange, .blue)
            }
        }
        
        .onChange(of: xValue) { value in
            entity.value.x = value
            model.renderer?.restart()
        }
        
        .onChange(of: yValue) { value in
            entity.value.y = value
            model.renderer?.restart()
        }
        
        .onChange(of: zValue) { value in
            entity.value.z = value
            model.renderer?.restart()
        }
        
        .onReceive(model.updateDataViews) { _ in
            xValue = entity.value.x
            yValue = entity.value.y
            zValue = entity.value.z
        }
    }
}

/*
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
}*/

struct DataView: View {
    
    let model                               : Model
    let data                                : SignedData
    
    @State var updateView                   : Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                
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
