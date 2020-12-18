//
//  Classes.swift
//  Metal-Z
//
//  Created by Markus Moenig on 25/8/20.
//

import Foundation

class TextRef
{
    var text        : String? = nil

    var f1          : Float1? = nil
    var f2          : Float2? = nil
    var f3          : Float3? = nil
    var f4          : Float4? = nil

    var i1          : Int1? = nil
    
    var font        : Font? = nil
    var fontSize    : Float = 10
    
    var digits      : Int1? = nil

    init(_ text: String? = nil)
    {
        self.text = text
    }
}

class Rect2D
{
    var x               : Float = 0
    var y               : Float = 0
    var width           : Float = 0
    var height          : Float = 0

    init(_ x: Float = 0,_ y: Float = 0,_ width: Float = 0,_ height:Float = 0)
    {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
