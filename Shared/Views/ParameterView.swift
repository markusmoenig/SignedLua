//
//  ParameterView.swift
//  Signed
//
//  Created by Markus Moenig on 20/6/2564 BE.
//

import SwiftUI
import DynamicColor

/// We cannot display parameters the traditional way as they can be variables or even expressions. Display as text.
struct ParamAsTextView: View {
    
    let core                                : Core
    let option                              : GraphOption
    
    @State var valueText                    : String = ""
    @State private var selectedColor        = Color.white

    @State var color = DynamicColor.red

    @State var lastChange                   : String? = nil

    init(_ core: Core, _ option: GraphOption)
    {
        self.core = core
        self.option = option
        
        _valueText = State(initialValue: option.raw)
        
        if option.canBeColor {
            if option.variable.getType() == .Float3 {
                let array = option.raw.split(separator: ",")
                if array.count == 3 {
                    let dx = Double(array[0].trimmingCharacters(in: .whitespaces))
                    let dy = Double(array[1].trimmingCharacters(in: .whitespaces))
                    let dz = Double(array[2].trimmingCharacters(in: .whitespaces))
                    
                    if dx != nil && dy != nil && dz != nil {
                        let color = Color(.sRGB, red: dx!, green: dy!, blue: dz!, opacity: Double(1))
                        //_selectedColor = State(initialValue: Color(.sRGB, red: dx!, green: dy!, blue: dz!, opacity: Double(1)))
                        _color = State(initialValue: DynamicColor(color))
                    }
                }
            }
        }
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            TextField(option.name, text: $valueText, onEditingChanged: { (changed) in
                option.raw = valueText
            },
            onCommit: {
                core.scriptProcessor.replaceOptionInLine(option, useRaw: true)
            } )
            if option.canBeColor {
                
                ColorPickerRing(color: $color, strokeWidth: 10)
                    .frame(width: 100, height: 100, alignment: .center)
                
                    .onChange(of: color) { color in
                        let c = color.cgColor
                        
                        let x = String(format: "%.03g", c.components![0])
                        let y = String(format: "%.03g", c.components![1])
                        let z = String(format: "%.03g", c.components![2])

                        option.raw = "\(x), \(y), \(z)"
                        core.scriptProcessor.replaceOptionInLine(option, useRaw: true)
                    }
            }
        }
    }
}

struct ParameterView: View {
    
    let core                                : Core
    
    @State var radius                       : String = "1"
    
    @State var updateView                   : Bool = false
    
    @State var options                      : [GraphOption] = []

    init(_ core: Core)
    {
        self.core = core
    }
    
    var body: some View {
        
        ScrollView {
            VStack(alignment: .leading) {
                
                ForEach(options, id: \.id) { option in
                    ParamAsTextView(core, option)
                        .padding(4)
                }
                
                Spacer()
            }
            
            .onReceive(self.core.modelChanged) { void in
                options = core.scriptProcessor.getOptions()
                updateView.toggle()
            }
            .onReceive(self.core.graphBuilder.selectionChanged) { id in
                options = core.scriptProcessor.getOptions()
                updateView.toggle()
            }
            .onReceive(self.core.graphBuilder.contextColorChanged) { colorText in
                let v = Float3(0,0,0)
                v.isColor = true
                options = [GraphOption(v,"Color","")]
                updateView.toggle()
            }
            .onAppear(perform: {
                options = core.scriptProcessor.getOptions()
            })
        }
    }
}
