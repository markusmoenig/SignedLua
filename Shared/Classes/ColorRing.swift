//
//  ColorRing.swift
//  Signed
//
//  Created by Markus Moenig on 9/2/21.
//

// Modified version of https://github.com/hendriku/ColorPicker

/**
 
 MIT License

 Copyright (c) 2020 Hendrik Ulbrich

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 
 */

import SwiftUI
import DynamicColor

public struct ColorPickerRing : View {
    public var color: Binding<DynamicColor>
    public var strokeWidth: CGFloat = 30
    
    public var body: some View {
        GeometryReader {
            ColorWheel(color: self.color, frame: $0.frame(in: .local), strokeWidth: self.strokeWidth)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    public init(color: Binding<DynamicColor>, strokeWidth: CGFloat) {
       self.color = color
       self.strokeWidth = strokeWidth
    }
}

public struct ColorWheel: View {
    public var color: Binding<DynamicColor>
    public var frame: CGRect
    public var strokeWidth: CGFloat
    
    @State public var internalColor : DynamicColor
        
    public var body: some View {
        let indicatorOffset = CGSize(
            width: cos($internalColor.wrappedValue.angle.radians) * Double(frame.midX - strokeWidth / 2),
            height: -sin($internalColor.wrappedValue.angle.radians) * Double(frame.midY - strokeWidth / 2))
        
        
        return ZStack(alignment: .center) {
            // Color Gradient
            Circle()
                .strokeBorder(AngularGradient.conic, lineWidth: strokeWidth)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged(self.internalUpdate(value:))
                .onEnded(self.update(value:))
            )
            Circle()
                .fill(Color(internalColor))
                .frame(width: 60, height: 60, alignment: .center)
            // Color Selection Indicator
            Circle()
                .fill(Color(internalColor))
                .frame(width: strokeWidth, height: strokeWidth, alignment: .center)
                .fixedSize()
                .offset(indicatorOffset)
                .allowsHitTesting(false)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .offset(indicatorOffset)
                        .allowsHitTesting(false)
            )
        }
    }
    
    public init(color: Binding<DynamicColor>, frame: CGRect, strokeWidth: CGFloat) {
       self.frame = frame
       self.color = color
       self.strokeWidth = strokeWidth
        self._internalColor = State(initialValue: color.wrappedValue)
    }
    
    func internalUpdate(value: DragGesture.Value) {
        $internalColor.wrappedValue = Angle(radians: radCenterPoint(value.location, frame: self.frame)).color
    }
    
    func update(value: DragGesture.Value) {
        //self.color.wrappedValue = Angle(radians: radCenterPoint(value.location, frame: self.frame)).color
        self.color.wrappedValue = internalColor
    }
    
    func radCenterPoint(_ point: CGPoint, frame: CGRect) -> Double {
        let adjustedAngle = atan2f(Float(frame.midX - point.x), Float(frame.midY - point.y)) + .pi / 2
        return Double(adjustedAngle < 0 ? adjustedAngle + .pi * 2 : adjustedAngle)
    }
}

import DynamicColor

extension Angle {
    var color: DynamicColor {
        DynamicColor(hue: CGFloat(self.radians / (2 * .pi)), saturation: 1, brightness: 1, alpha: 1)
    }
    
    var colorView: Color {
        Color(hue: self.radians / (2 * .pi), saturation: 1, brightness: 1)
    }
}

extension DynamicColor {
    var angle: Angle {
        Angle(radians: Double(2 * .pi * self.hueComponent))
    }
}

extension AngularGradient {
    static let conic = AngularGradient(gradient: Gradient.colorWheelSpectrum, center: .center, angle: .degrees(-90))
}

extension Gradient {
    static let colorWheelSpectrum: Gradient = Gradient(colors: [
        Angle(radians: 3/6 * .pi).colorView,
        
        Angle(radians: 2/6 * .pi).colorView,
        Angle(radians: 1/6 * .pi).colorView,
        Angle(radians: 12/6 * .pi).colorView,
        
        Angle(radians: 11/6 * .pi).colorView,
        
        Angle(radians: 10/6 * .pi).colorView,
        Angle(radians: 9/6 * .pi).colorView,
        Angle(radians: 8/6 * .pi).colorView,
        
        Angle(radians: 7/6 * .pi).colorView,
        
        Angle(radians: 6/6 * .pi).colorView,
        Angle(radians: 5/6 * .pi).colorView,
        Angle(radians: 4/6 * .pi).colorView,
        
        Angle(radians: 3/6 * .pi).colorView,
    ])
}
