//
//  SignedDocument.swift
//  Signed
//
//  Created by Markus Moenig on 12/12/20.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var signedProject: UTType {
        UTType(exportedAs: "com.Signed.project")
    }
}

extension UTType {
    static var signedOBJ: UTType {
        UTType(exportedAs: "com.Signed.obj")
    }
}

struct SignedDocument: FileDocument {
    
    var model       = Model()
    
    var updated     = false

    init() {
    }

    static var readableContentTypes: [UTType] { [.signedProject] }
    static var writableContentTypes: [UTType] { [.signedProject, .png, .signedOBJ] }

    init(configuration: ReadConfiguration) throws {
        
        guard let data = configuration.file.regularFileContents,
                let project = try? JSONDecoder().decode(SignedProject.self, from: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if data.isEmpty == false {
            model.setProject(project)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var data = Data()
        
        let encodedData = try? JSONEncoder().encode(model.project)
        if let json = String(data: encodedData!, encoding: .utf8) {
            data = json.data(using: .utf8)!
        }
        
        return .init(regularFileWithContents: data)
    }
}
