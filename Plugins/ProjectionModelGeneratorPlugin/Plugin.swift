//
//  Plugin.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/2/12.
//

import Foundation
import PackagePlugin

enum PluginError: Error {
    case projectionModelDefinitionFileNotFound
    case configFileNotFound
}

@main struct ProjectionHelperGeneratorPlugin {
    func createBuildCommands(
        pluginWorkDirectory: URL,
        tool: (String) throws -> URL,
        sourceFiles: FileList,
        targetName: String
    ) throws -> [Command] {
        guard let projectionModelSource = (sourceFiles.first{ $0.url.lastPathComponent == "projection-model.yaml" }) else {
            throw PluginError.projectionModelDefinitionFileNotFound
        }
        
        guard let configSource = (sourceFiles.first{ $0.url.lastPathComponent == "event-generator-config.yaml" }) else {
            throw PluginError.configFileNotFound
        }
        
        let generatedProjectionHelperSource = pluginWorkDirectory.appending(path: "generated-projection-model.swift")
    
        return [
            try .buildCommand(displayName: "Event Generating...\(projectionModelSource.url.path())", executable: tool("generate"), arguments: [
                "projection-model",
                "--configuration", "\(configSource.url.path())",
                "--output", "\(generatedProjectionHelperSource.path())",
                "\(projectionModelSource.url.path())"
            ], inputFiles: [
                projectionModelSource.url
            ], outputFiles: [
                generatedProjectionHelperSource
            ])
        ]
    }
}

extension ProjectionHelperGeneratorPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let swiftTarget = target as? SwiftSourceModuleTarget else {
            return []
        }
    
        return try createBuildCommands(
            pluginWorkDirectory: context.pluginWorkDirectoryURL,
            tool: {
                try context.tool(named: $0).url
            },
            sourceFiles: swiftTarget.sourceFiles,
            targetName: target.name
        )
    
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ProjectionHelperGeneratorPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        try createBuildCommands(
            pluginWorkDirectory: context.pluginWorkDirectoryURL,
            tool: {
                try context.tool(named: $0).url
            },
            sourceFiles: target.inputFiles,
            targetName: target.displayName
        )
    }
}
#endif

