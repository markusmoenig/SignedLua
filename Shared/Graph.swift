//
//  Graph.swift
//  Signed
//
//  Created by Markus Moenig on 13/12/20.
//

import Foundation

class GraphNode {
    
    enum Result {
        case Success, Failure, Running, Unused
    }
    
    // Only applicable for branch nodes like a sequence
    var leaves              : [GraphNode] = []
    
    var name                : String = ""
    var lineNr              : Int32 = 0
    
    // Options
    var options             : [String:Any]
    
    init(_ options: [String:Any] = [:])
    {
        self.options = options
    }
    
    /// Verify options
    func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    /// Executes a node inside a behaviour tree
    @discardableResult @inlinable public func execute(context: GraphContext) -> Result
    {
        return .Success
    }
}

class GraphVariable
{
    var name        : String
    var value       : Any
    
    init(_ name: String,_ value:Any)
    {
        self.name = name
        self.value = value
    }
}

final class GraphContext
{
    var buffer              : Array<SIMD4<UInt8>>!
    
    var nodes               : [GraphNode] = []
    
    var variables           : [GraphVariable] = []
    var failedAt            : [Int32] = []
    
    var lines               : [Int32:String] = [:]
        
    let core                : Core
    
    var position            = float3(0,0,0)
    
    var camOrigin           = float3(0,0,-5)
    var camDir              = float3(0,0,0)
    
    // SDF Raymarching
    
    var rayPos              : float3 = float3(0,0,0)
    var rayDist             : [Float] = []
    var rayIndex            : Int = 0
    
    init(_ core: Core)
    {
        self.core = core
        
        rayDist.append(.greatestFiniteMagnitude)
        rayDist.append(.greatestFiniteMagnitude)
    }
    
    func clear()
    {
        nodes = []
        variables = []
        lines = [:]
    }
    
    /// Create a copy of this context and return it
    func copy() -> GraphContext {
        let copy = GraphContext(core)
        copy.nodes = nodes
        copy.variables = variables
        return copy
    }
    
    @inlinable public func reset(_ rayPos: float3 = float3(0,0,0))
    {
        self.rayPos = rayPos
        rayDist[0] = .greatestFiniteMagnitude
        rayDist[1] = .greatestFiniteMagnitude
        rayIndex = 0
        position = float3(0,0,0)
    }
    
    @inlinable public func toggleRayIndex()
    {
        if rayIndex == 0 {
            rayIndex = 1
        } else {
            rayIndex = 0
        }
    }
    
    func addVariable(_ name: String,_ value: Any)
    {
        variables.append(GraphVariable(name, value))
    }
    
    func getVariableValue(_ name: String) -> Any?
    {
        // Globals
        if name == "Time" {
            return core._Time
        } else
        if name == "Aspect" {
            return core._Aspect
        }
        
        // Check the context variables
        for v in variables {
            if v.name == name {
                return v.value
            }
        }
        return nil
    }
    
    func getNode(_ name: String) -> GraphNode?
    {
        // Check the context variables
        for t in nodes {
            if t.name == name {
                return t
            }
        }
        return nil
    }
    
    func addFailure(lineNr: Int32)
    {
        failedAt.append(lineNr)
    }
    
    @discardableResult @inlinable public func execute() -> GraphNode.Result
    {
        failedAt = []
        for node in nodes {
            node.execute(context: self)
        }
        return .Success
    }
    
    func debug()
    {
        for node in nodes {
            print(node.name, node.leaves.count )
            for l in node.leaves {
                print("  \(l.name)", l.leaves.count)
                for l in node.leaves {
                    print("    \(l.name)", l.leaves.count)
                }
            }
        }
    }
}
