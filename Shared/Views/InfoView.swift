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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(info)
                        .lineLimit(nil)
                    Spacer()
                }
                .padding(.leading, 4)
            }.frame(maxWidth: .infinity)
        }
        
        .onReceive(model.infoChanged) { _ in
            info = model.infoText
        }
    }
}
