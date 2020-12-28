//
//  ExpAtomNodes.swift
//  Signed
//
//  Created by Markus Moenig on 18/12/20.
//

import Foundation

class MultiplyAtomNode : ExpressionNode {
    
    init()
    {
        super.init("*")
    }
    
    override func setupAtom(_ context: ExpressionContext,_ indices: [Int],_ error: inout CompileError)
    {
        self.indices = indices
        
        let left = context.values[indices[0]]!
        let right = context.values[indices[1]]!
        
        if left.components != right.components && left.components != 1 && right.components != 1 {
            error.error = "Cannot multiply \(left.getTypeName()) with \(right.getTypeName())"
        }
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        let left = context.values[indices[0]]!
        let right = context.values[indices[1]]!
        
        if let left = left as? Float1 {
            if let right = right as? Float1 {
                context.values[indices[1] + 1] = Float1(left.toSIMD() * right.toSIMD())
            }
            if let right = right as? Float2 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float2(rcLeft * rcRight.x, rcLeft * rcRight.y)
            }
            if let right = right as? Float3 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float3(rcLeft * rcRight.x, rcLeft * rcRight.y, rcLeft * rcRight.z)
            }
            if let right = right as? Float4 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float4(rcLeft * rcRight.x, rcLeft * rcRight.y, rcLeft * rcRight.z, rcLeft * rcRight.w)
            }
        }
        if let left = left as? Float2 {
            if let right = right as? Float1 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float2(rcLeft.x * rcRight, rcLeft.y * rcRight)
            } else
            if let right = right as? Float2 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float2(rcLeft.x * rcRight.x, rcLeft.y * rcRight.y)
            }
        } else
        if let left = left as? Float3 {
            if let right = right as? Float1 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float3(rcLeft.x * rcRight, rcLeft.y * rcRight, rcLeft.z * rcRight)
            } else
            if let right = right as? Float3 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float3(rcLeft.x * rcRight.x, rcLeft.y * rcRight.y, rcLeft.z * rcRight.z)
            }
        } else
        if let left = left as? Float4 {
            if let right = right as? Float1 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float4(rcLeft.x * rcRight, rcLeft.y * rcRight, rcLeft.z * rcRight, rcLeft.w * rcRight)
            } else
            if let right = right as? Float4 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float4(rcLeft.x * rcRight.x, rcLeft.y * rcRight.y, rcLeft.z * rcRight.z, rcLeft.w * rcRight.w)
            }
        }
    }
}

class DivisionAtomNode : ExpressionNode {
    
    init()
    {
        super.init("/")
    }
    
    override func setupAtom(_ context: ExpressionContext,_ indices: [Int],_ error: inout CompileError)
    {
        self.indices = indices
        
        let left = context.values[indices[0]]!
        let right = context.values[indices[1]]!
        
        if left.components != right.components && left.components != 1 && right.components != 1 {
            error.error = "Cannot divide \(left.getTypeName()) with \(right.getTypeName())"
        }
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        let left = context.values[indices[0]]!
        let right = context.values[indices[1]]!
        
        if let left = left as? Float1 {
            if let right = right as? Float1 {
                context.values[indices[1] + 1] = Float1(left.toSIMD() / right.toSIMD())
            }
            if let right = right as? Float2 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float2(rcLeft / rcRight.x, rcLeft / rcRight.y)
            }
            if let right = right as? Float3 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float3(rcLeft / rcRight.x, rcLeft / rcRight.y, rcLeft / rcRight.z)
            }
            if let right = right as? Float4 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float4(rcLeft / rcRight.x, rcLeft / rcRight.y, rcLeft / rcRight.z, rcLeft / rcRight.w)
            }
        }
        if let left = left as? Float2 {
            if let right = right as? Float1 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float2(rcLeft.x / rcRight, rcLeft.y / rcRight)
            } else
            if let right = right as? Float2 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float2(rcLeft.x / rcRight.x, rcLeft.y / rcRight.y)
            }
        } else
        if let left = left as? Float3 {
            if let right = right as? Float1 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float3(rcLeft.x / rcRight, rcLeft.y / rcRight, rcLeft.z / rcRight)
            } else
            if let right = right as? Float3 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float3(rcLeft.x / rcRight.x, rcLeft.y / rcRight.y, rcLeft.z / rcRight.z)
            }
        } else
        if let left = left as? Float4 {
            if let right = right as? Float1 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float4(rcLeft.x / rcRight, rcLeft.y / rcRight, rcLeft.z / rcRight, rcLeft.w / rcRight)
            } else
            if let right = right as? Float4 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float4(rcLeft.x / rcRight.x, rcLeft.y / rcRight.y, rcLeft.z / rcRight.z, rcLeft.w / rcRight.w)
            }
        }
    }
}

class MinusAtomNode : ExpressionNode {
    
    init()
    {
        super.init("-")
    }
    
    override func setupAtom(_ context: ExpressionContext,_ indices: [Int],_ error: inout CompileError)
    {
        self.indices = indices
        
        let left = context.values[indices[0]]!
        let right = context.values[indices[1]]!
        
        if left.components != right.components {
            error.error = "Cannot subtract \(right.getTypeName()) from \(left.getTypeName())"
        }
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        let left = context.values[indices[0]]
        let right = context.values[indices[1]]

        if let left = left as? Float1 {
            if let right = right as? Float1 {
                context.values[indices[1] + 1] = Float1(left.toSIMD() - right.toSIMD())
            }
        } else
        if let left = left as? Float2 {
            if let right = right as? Float2 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float2(rcLeft.x - rcRight.x, rcLeft.y - rcRight.y)
            }
        }
        if let left = left as? Float3 {
            if let right = right as? Float3 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float3(rcLeft.x - rcRight.x, rcLeft.y - rcRight.y, rcLeft.z - rcRight.z)
            }
        }
        if let left = left as? Float4 {
            if let right = right as? Float4 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float4(rcLeft.x - rcRight.x, rcLeft.y - rcRight.y, rcLeft.z - rcRight.z, rcLeft.w - rcRight.w)
            }
        }
    }
}

class AddAtomNode : ExpressionNode {
    
    init()
    {
        super.init("+")
    }
    
    override func setupAtom(_ context: ExpressionContext,_ indices: [Int],_ error: inout CompileError)
    {
        self.indices = indices
        
        let left = context.values[indices[0]]!
        let right = context.values[indices[1]]!
        
        if left.components != right.components {
            error.error = "Cannot add \(right.getTypeName()) to \(left.getTypeName())"
        }
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        let left = context.values[indices[0]]
        let right = context.values[indices[1]]

        if let left = left as? Float1 {
            if let right = right as? Float1 {
                context.values[indices[1] + 1] = Float1(left.toSIMD() + right.toSIMD())
            }
        } else
        if let left = left as? Float2 {
            if let right = right as? Float2 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float2(rcLeft.x + rcRight.x, rcLeft.y + rcRight.y)
            }
        }
        if let left = left as? Float3 {
            if let right = right as? Float3 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float3(rcLeft.x + rcRight.x, rcLeft.y + rcRight.y, rcLeft.z + rcRight.z)
            }
        }
        if let left = left as? Float4 {
            if let right = right as? Float4 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float4(rcLeft.x + rcRight.x, rcLeft.y + rcRight.y, rcLeft.z + rcRight.z, rcLeft.w + rcRight.w)
            }
        }
    }
}

