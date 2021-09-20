//
//  SignedContext.swift
//  SignedContext
//
//  Created by Markus Moenig on 16/8/21.
//

import Foundation

class SignedContext {
    
    let model           : Model
    let kit             : ModelerKit
    
    var commands        : [String:SignedCommand] = [:]
        
    init(model: Model, kit: ModelerKit) {
        self.model = model
        self.kit = kit
    }
    
    deinit {
        commands = [:]
    }
    
    /// Adds the given cmd to the modeler pipeline
    func addToPipeline(cmd: SignedCommand) {
        if let copy = cmd.copy() {
            kit.pipeline.append(copy)
        }
        
        if kit.role == .main {
            model.progressTotal += 1
            sendProgressNotification()
        }
    }
    
    func sendProgressNotification() {        
        DispatchQueue.main.async {
            self.model.progressChanged.send()
        }
    }
}
