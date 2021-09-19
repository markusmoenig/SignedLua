//
//  ProgressView.swift
//  ProgressView
//
//  Created by Markus Moenig on 10/9/21.
//

import SwiftUI

struct ProgressView: View {
    
    let model                               : Model

    @State private var value                : Float = 0
    @State private var color                : Color = .accentColor

    var body: some View {
            
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                Rectangle().frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(color)
            } else {
                Rectangle().frame(width: geometry.size.width, height: min(CGFloat(self.value)*geometry.size.height, geometry.size.height))
                    .foregroundColor(color)
            }
        }
        
        .onReceive(model.progressChanged) { _ in
            
            if model.progress == .modelling {
                color = .accentColor
            } else {
                color = .green
            }
            
            if model.progressCurrent < model.progressTotal {
                value = Float(model.progressCurrent) / Float(model.progressTotal)
            } else {
                if model.progressTotal > 0 {
                    value = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    value = 0
                }
            }
        }
    }
}

