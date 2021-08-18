//
//  DetailView.swift
//  DetailView
//
//  Created by Markus Moenig on 18/8/21.
//

import SwiftUI

struct DetailView: View {

    let model                               : Model
    
    @State var maximized                    : Bool = true
    
    @State var variableNames                : String = ""

    var body: some View {
        VStack(spacing: 1) {
            
            HStack(alignment: .center, spacing: 4) {
                TextField("Variable names", text: $variableNames, onEditingChanged: { (changed) in
                })
                
                Divider()
                    .frame(maxHeight: 16)
                
                Image(systemName: "rectangle.bottomthird.inset.filled")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .onTapGesture(perform: {
                        maximized.toggle()
                    })
                    .padding(.trailing, 6)
                    .foregroundColor(.gray)
                    //.padding(.top, 0)
                    //.padding(.bottom, 0)
                /*Button(action: {
                })
                {

                }
                .buttonStyle(PlainButtonStyle())*/

            }
            
            if maximized {
                Canvas { context, size in
                    
                    /*
                    context.fill(
                        Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10),
                        with: .color(.gray))
                    
                    context.stroke(
                        Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10),
                        with: .color(selection === object ? .white : .clear),
                        lineWidth: 4)
                    
                    context.draw(Text(object.name), at: CGPoint(x: 10, y: 4), anchor: .topLeading)
                     */
                    
                }
            }
        }
        .frame(minHeight: maximized ? 60 : 20, maxHeight: maximized ? 120 : 20)
        .animation(.default)

    }
}
