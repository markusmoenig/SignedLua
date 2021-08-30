//
//  InfoView.swift
//  InfoView
//
//  Created by Markus Moenig on 19/8/21.
//

import SwiftUI

struct InfoView: View {

    let model                               : Model
    
    @State private var info                 : String = ""

    @State private var progressString       : String = "Ready"
    @State private var value                : Float = 0

    var body: some View {
        
        VStack(spacing: 1) {
        
                
            ZStack {
                
                GeometryReader { geometry in
                    Rectangle().frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width), height: geometry.size.height)
                        .foregroundColor(.accentColor)
                        //.animation(.linear)
                        .frame(maxHeight: geometry.size.height)
                }
                .frame(maxHeight: 20)

                HStack(spacing: 1) {

                    Button(action: {
                        model.builder.workItem?.cancel()
                        model.builder.exitLua()
                        if let mainKit = model.modeler?.mainKit {
                            mainKit.pipeline = []
                        }
                        model.infoProgressTotalCmds = 0
                        model.infoProgressProcessedCmds = 0
                        model.builder.context.createProgressValues()
                    })
                    {
                        Image(systemName: "exclamationmark.octagon")
                    }
                    .contextMenu {
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 4)
                    .disabled(model.infoProgressTotalCmds == model.infoProgressProcessedCmds)
                    
                    Spacer()

                    Text(progressString)
                        .font(.system(size: 11))
                        .padding(.trailing, 6)
                }
            }
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(getAttributedString(markdown: info))
                            .lineLimit(nil)
                            .font(.system(size: 11))
                        Spacer()
                    }
                    .padding(.leading, 4)
                }.frame(maxWidth: .infinity)
            }
        }
            
        .onReceive(model.infoChanged) { _ in
            info = model.infoText
        }
        
        .onReceive(model.modelingProgressChanged) { string in
            progressString = string
            if model.infoProgressProcessedCmds < model.infoProgressTotalCmds {
                value = Float(model.infoProgressProcessedCmds) / Float(model.infoProgressTotalCmds)
            } else {
                if model.infoProgressTotalCmds > 0 {
                    value = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    value = 0
                }
            }
        }
        
        .onReceive(model.shapeSelected) { shape in
            info = getCommandMarkdown(shape: shape)
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


