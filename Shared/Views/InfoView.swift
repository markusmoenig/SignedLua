//
//  InfoView.swift
//  InfoView
//
//  Created by Markus Moenig on 19/8/21.
//

import SwiftUI

struct InfoView: View {
    
    enum InfoType {
        case info, shape, object, material
    }

    let model                               : Model
    
    @State private var infoType             : InfoType = .info
    @State private var info                 : String = ""
    
    init(model: Model) {
        self.model = model
    }
    
    var body: some View {
                    
        VStack {
            if infoType == .info {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(getAttributedString(markdown: info))
                                .lineLimit(nil)
                            Spacer()
                        }
                        .padding(.leading, 4)
                    }.frame(maxWidth: .infinity)
                }
            } else
            if infoType == .shape {
                if let shape = model.selectedShape {
                    ShapeDetailsView(model: model, shape: shape)
                }
            } else
            if infoType == .object {
                if let object = model.selectedDBObject {
                    ObjectDetailsView(model: model, object: object)
                }
            } else
            if infoType == .material {
                if let material = model.selectedDBMaterial {
                    MaterialDetailsView(model: model, material: material)
                }
            }
        }

        .onReceive(model.infoChanged) { _ in
            info = model.infoText
            infoType = .info
            model.deselectSideViewIcon.send()
        }
        
        .onReceive(model.shapeSelected) { shape in
            infoType = .shape
        }
        
        .onReceive(model.dbObjectSelected) { object in
            infoType = .object
        }
        
        .onReceive(model.dbMaterialSelected) { object in
            infoType = .material
        }
    }
    
    ///
    func getCommandMarkdown(shape: SignedCommand) ->  String {
        var txt = ""
        
        func processData(name: String, data: SignedData) {
            txt += "**\(name)**\n"
            for d in data.data {
                txt += d.key + " "
                if d.type == .Float {
                    txt += "(*Number*)\n"
                } else
                if d.type == .Float2 {
                    txt += "(*vec2*)\n"
                } else
                if d.type == .Float3 {
                    txt += "(*vec3*)\n"
                }
            }
            txt += "\n"
        }
        
        if let data = shape.dataGroups.getGroup("Geometry") {
            processData(name: "Geometry", data: data)
        }
        if let data = shape.dataGroups.getGroup("Transform") {
            processData(name: "Transform", data: data)
        }
        if let data = shape.dataGroups.getGroup("Modifier") {
            processData(name: "Modifier", data: data)
        }
        if let data = shape.dataGroups.getGroup("Boolean") {
            processData(name: "Boolean", data: data)
        }
        if let data = shape.dataGroups.getGroup("Repetition") {
            processData(name: "Repetition", data: data)
        }
        
        processData(name: "Material", data: shape.material.data)
        
        return txt
    }
    
    func getAttributedString(markdown: String) -> AttributedString {
        do {
            return try AttributedString(markdown: markdown, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch {
            return AttributedString()
        }
    }
}


