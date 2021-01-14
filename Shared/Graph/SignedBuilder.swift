//
//  GraphBuilder.swift
//  Signed
//
//  Created by Markus Moenig on 13/12/20.
//

import Foundation
import Combine

class SignedGraphBuilder: GraphBuilder {
    let core                : Core
    
    let selectionChanged    = PassthroughSubject<UUID?, Never>()
    let contextColorChanged = PassthroughSubject<String, Never>()

    var cursorTimer         : Timer? = nil
    var currentNode         : GraphNode? = nil
    
    init(_ core: Core)
    {
        self.core = core
        super.init()
        
        branches.append(GraphNodeItem("PinholeCamera", { (_ options: [String:Any]) -> GraphNode in return GraphPinholeCameraNode(options) }))
        branches.append(GraphNodeItem("DefaultSky", { (_ options: [String:Any]) -> GraphNode in return GraphDefaultSkyNode(options) }))
    }
    
    @discardableResult override func compile(_ asset: Asset, silent: Bool = false) -> CompileError
    {
        var error = super.compile(asset, silent: silent)
        
        if silent == false {
            
            if asset.graph?.cameraNode == nil {
                error.error = "Project must contain a Camera!"
                error.line = 0
            }
            
            if core.state == .Idle {
                if error.error != nil {
                    error.line = error.line! + 1
                    core.scriptEditor?.setError(error)
                } else {
                    core.scriptEditor?.clearAnnotations()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.core.modelChanged.send()
            }
        }
        
        return error
    }

    func startTimer(_ asset: Asset)
    {
        DispatchQueue.main.async(execute: {
            let timer = Timer.scheduledTimer(timeInterval: 0.2,
                                             target: self,
                                             selector: #selector(self.cursorCallback),
                                             userInfo: nil,
                                             repeats: true)
            self.cursorTimer = timer
        })
    }
    
    func stopTimer()
    {
        if cursorTimer != nil {
            cursorTimer?.invalidate()
            cursorTimer = nil
        }
    }
    
    var send = false
    var lastContextHelpId :UUID? = nil
    @objc func cursorCallback(_ timer: Timer) {
        if core.state == .Idle && core.scriptEditor != nil {
            core.scriptEditor!.getSessionCursor({ (line, column) in
            
                if let asset = self.core.assetFolder.current, asset.type == .Source {
                    
                    var processed = false
                    if let line = self.core.scriptProcessor.getLine(line) {
                        let word = extractWordAtOffset(line, offset: column, boundaries: " <>\",()")
                        
                        
                        if word.starts(with: "#") && (word.count == 7 || word.count == 9) {
                            // Color ?
                            if self.send == false {
                                self.contextColorChanged.send(word)
                                self.send = true
                            }
                        } else {
                            let context = ExpressionContext()
                            for f in context.functions {
                                if f.name == word {
                                    if f.id != self.lastContextHelpId {
                                        let functionNode = f.createNode()
                                        
                                        self.core.contextText = self.generateNodeHelpText(functionNode)
                                        self.core.contextTextChanged.send(self.core.contextText)
                                        processed = true
                                        self.lastContextHelpId = f.id
                                    }
                                }
                            }
                        }
                    }
                    
                    if processed == false {
                        if let context = asset.graph {
                            if let node = context.lines[line] {
                                if node.id != self.lastContextHelpId {
                                    self.currentNode = node
                                    self.selectionChanged.send(node.id)
                                    self.core.contextText = self.generateNodeHelpText(node)
                                    self.core.contextTextChanged.send(self.core.contextText)
                                    self.lastContextHelpId = node.id
                                }
                            } else {
                                if self.lastContextHelpId != nil {
                                    self.currentNode = nil
                                    self.selectionChanged.send(nil)
                                    self.core.contextText = ""
                                    self.core.contextTextChanged.send(self.core.contextText)
                                    self.lastContextHelpId = nil
                                }
                            }
                        }
                    }
                }
            })
        }
    }
    
    /// Generates a markdown help text for the given node
    func generateNodeHelpText(_ node: GraphNode) -> String
    {
        var help = "## " + node.name + "\n"
        help += node.getHelp()
        let options = node.getOptions()
        if options.count > 0 {
            help += "\nOptional Parameters\n"
        }
        for o in options {
            help += "* **\(o.name)** (\(o.variable.getTypeName())) - " + o.help + "\n"
        }
        return help
    }
    
    /// Generates a markdown help text for the given expression node
    func generateNodeHelpText(_ node: ExpressionNode) -> String
    {
        var help = "## " + node.name + "\n"
        help += node.getHelp()
        let options = node.getOptions()
        if options.count > 0 {
            help += "\nOptional Parameters\n"
        }
        for o in options {
            help += "* **\(o.name)** (\(o.variable.getTypeName())) - " + o.help + "\n"
        }
        return help
    }
    
    /// Go to the line of the node
    func gotoNode(_ node: GraphNode)
    {
        if currentNode != node {
            core.scriptEditor?.gotoLine(node.lineNr+1)
            currentNode = node
        }
    }
}
