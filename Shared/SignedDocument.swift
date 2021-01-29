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

struct SignedDocument: FileDocument {
    var core = Core()
    var updated     = false

    init() {
    }

    static var readableContentTypes: [UTType] { [.signedProject] }
    static var writableContentTypes: [UTType] { [.signedProject, .png] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
                let folder = try? JSONDecoder().decode(AssetFolder.self, from: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if data.isEmpty == false {
            core.assetFolder = folder
            core.assetFolder.core = core
            
            // Make sure there is a selected asset
            if core.assetFolder.assets.count > 0 {
                core.assetFolder.current = core.assetFolder.assets[0]
            }
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var data = Data()
        
        let encodedData = try? JSONEncoder().encode(core.assetFolder)
        if let json = String(data: encodedData!, encoding: .utf8) {
            data = json.data(using: .utf8)!
        }
        
        return .init(regularFileWithContents: data)
    }
}
