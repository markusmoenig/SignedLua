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
    func verifyOptions(context: GraphContext, tree: GraphTree, error: inout CompileError) {
    }
    
    /// Executes a node inside a behaviour tree
    @discardableResult func execute(game: Game, context: GraphContext, tree: GraphTree?) -> Result
    {
        return .Success
    }
}


class GraphTree     : GraphNode
{
    var parameters  : [GraphVariable] = []

    init(_ name: String)
    {
        super.init()
        self.name = name
    }
    
    @discardableResult override func execute(game: Game, context: GraphContext, tree: GraphTree?) -> Result
    {
        for leave in leaves {
            leave.execute(game: game, context: context, tree: self)
        }
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

class GraphContext
{
    var trees               : [GraphTree] = []
    var variables           : [GraphVariable] = []
    var failedAt            : [Int32] = []
    
    var lines               : [Int32:String] = [:]
        
    let game                : Game
    
    init(_ game: Game)
    {
        self.game = game
    }
    
    func clear()
    {
        trees = []
        variables = []
        lines = [:]
    }
    
    func addVariable(_ name: String,_ value: Any)
    {
        variables.append(GraphVariable(name, value))
    }
    
    func getVariableValue(_ name: String, tree: GraphTree? = nil) -> Any?
    {
        // Globals
        if name == "Time" {
            return game._Time
        } else
        if name == "Aspect" {
            return game._Aspect
        }
        
        // First check the optional tree parameters (if any) as they overrule the context variables
        if let tree = tree {
            for v in tree.parameters {
                if v.name == name {
                    return v.value
                }
            }
        }
        // Check the context variables
        for v in variables {
            if v.name == name {
                return v.value
            }
        }
        return nil
    }
    
    func getTree(_ name: String) -> GraphTree?
    {
        // Check the context variables
        for t in trees {
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
    
    @discardableResult func execute(name: String) -> GraphNode.Result
    {
        failedAt = []
        for tree in trees {
            if tree.name == name {
                tree.execute(game: game, context: self, tree: tree)
                return .Success
            }
        }
        return .Failure
    }
    
    func debug()
    {
        for tree in trees {
            print(tree.name, tree.leaves.count )
            for l in tree.leaves {
                print("  \(l.name)", l.leaves.count)
                for l in tree.leaves {
                    print("    \(l.name)", l.leaves.count)
                }
            }
        }
    }
}
