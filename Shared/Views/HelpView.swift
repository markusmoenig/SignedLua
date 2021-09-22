//
//  HelpView.swift
//  Signed
//
//  Created by Markus Moenig on 22/9/2564 BE.
//

import SwiftUI
import MarkdownUI

/// Help content
struct HelpView: View {
    
    let model                               : Model
    
    @State private var helpString           : String = ""

    init(model: Model, topic: HelpContentView.HelpTopic) {
        self.model = model
        
        var helpName = "introduction"
        
        if topic == .quickstart {
            helpName = "quickstart"
        }
        
        if let path = Bundle.main.path(forResource: helpName, ofType: "md", inDirectory: "Files/help") {
            if let value = try? String(contentsOfFile: path, encoding: String.Encoding.utf8) {
                _helpString = State(initialValue: value)
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack( alignment: .leading) {
                //Text(getAttributedString(markdown: helpString))
                Markdown(Document(helpString))
            }
        }
    }

    func getAttributedString(markdown: String) -> AttributedString {
        do {
            return try AttributedString(markdown: markdown, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch {
            return AttributedString()
        }
    }
}

/// Content Index for Help
struct HelpContentView: View {
    
    enum HelpTopic {
        case none, introduction, quickstart
    }
    
    let model                               : Model
    
    @State private var helpTopic            : HelpTopic = .introduction

    init(model: Model) {
        self.model = model
        self.helpTopic = model.currentHelpTopic
    }
    
    var body: some View {
        VStack(alignment: .leading) {

            List {
                Button("Introduction") {
                    helpTopic = .introduction
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(helpTopic == .introduction ? .accentColor : .primary)
                
                Button("Quick Start") {
                    helpTopic = .quickstart
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(helpTopic == .quickstart ? .accentColor : .primary)
            }

        }
        .padding(4)
    }
}
