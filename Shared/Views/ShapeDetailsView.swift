//
//  ShapeDetailsView.swift
//  Signed
//
//  Created by Markus Moenig on 23/9/2564 BE.
//

import SwiftUI
import MarkdownUI

struct ShapeDetailsView: View {
    
    let model                               : Model
    
    @State var shape                        : SignedCommand
    
    @State private var geometyDetails       = true

    
    init(model: Model, shape: SignedCommand) {
        self.model = model
        self._shape = State(initialValue: shape)
    }
        
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Create using")
                    .font(.headline)
                
                Button("command:newShape(\"\(shape.name)\")") {
                    copyToClipboard("local cmd = command:newShape(\"\(shape.name)\")")
                }
                    .background(Color.accentColor)
                    .font(.system(size: 12))
                    .padding(.top, 4)
                
                Markdown("execute with **:execute(index)** (index is an optional material index for material layering).")
                                
                if let geometryData = shape.dataGroups.getGroup("Geometry") {
                    DisclosureGroup(geometryData.name, isExpanded: $geometyDetails) {
                        extractDataUI(data: geometryData)
                    }
                    .font(.headline)
                }
                
                if let data = shape.dataGroups.getGroup("Boolean") {
                    DisclosureGroup(data.name) {
                        extractDataUI(data: data)
                    }
                    .font(.headline)
                }
                
                if let data = shape.dataGroups.getGroup("Transform") {
                    DisclosureGroup(data.name) {
                        extractDataUI(data: data)
                    }
                    .font(.headline)
                }
                
                if let data = shape.dataGroups.getGroup("Modifier") {
                    DisclosureGroup(data.name) {
                        extractDataUI(data: data)
                    }
                    .font(.headline)
                }
                
                if let data = shape.dataGroups.getGroup("Repetition") {
                    DisclosureGroup(data.name) {
                        extractDataUI(data: data)
                    }
                    .font(.headline)
                }
                
                if let data = shape.material.data {
                    DisclosureGroup("Material") {
                        extractDataUI(data: data)
                    }
                    .font(.headline)
                }
            }
            .padding(2)
        }
                 
        .onReceive(model.shapeSelected) { shape in
            self.shape = shape
        }
    }
    
    
    func copyToClipboard(_ str: String) {
        #if os(iOS)
        UIPasteboard.general.string = str
        #elseif os(OSX)
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(str, forType: .string)
        #endif
    }
    
    @ViewBuilder
    func extractDataUI(data: SignedData) -> some View {
        VStack(alignment: .leading) {
            ForEach(data.data, id: \.id) { entity in
                Button(getEntityButtonText(entity)) {
                    copyToClipboard(getEntityButtonText(entity))
                }
                    .background(Color.accentColor)
                    .font(.system(size: 12))
                    .padding(.top, 4)
                    
                if entity.about.isEmpty == false {
                    Markdown(Document("*" + entity.about + "*"))
                }
            }
        }
    }
    
    func getEntityButtonText(_ e: SignedDataEntity) -> String {
        
        func f2s(_ f: Float) -> String {
            let s = String(format: "%g", e.value.x)
            return s
        }
        
        var txt = ":set(\"" + e.key + "\", "
        
        if e.type == .Text {
            txt += "\"" + e.text + "\""
        } else
        if e.type == .Int {
            txt += String(Int(e.value.x))
        } else
        if e.type == .Float {
            txt += f2s(e.value.x)
        } else
        if e.type == .Float2 {
            txt += f2s(e.value.x) + ", " + f2s(e.value.y)
        } else
        if e.type == .Float3 {
            txt += f2s(e.value.x) + ", " + f2s(e.value.y) + ", " + f2s(e.value.z)
        } else
        if e.type == .Float4 {
            txt += f2s(e.value.x) + ", " + f2s(e.value.y) + ", " + f2s(e.value.z) + ", " + f2s(e.value.w)
        }
        
        txt += ")"
        
        return txt
    }
    
}
