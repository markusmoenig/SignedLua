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

    var body: some View {
            
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                Rectangle().frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(.accentColor)
            } else {
                Rectangle().frame(width: geometry.size.width, height: min(CGFloat(self.value)*geometry.size.height, geometry.size.height))
                    .foregroundColor(.accentColor)
            }
        }
        
        .onReceive(model.modelingProgressChanged) { string in
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
    }
}

