//
//  Plugin.swift
//  GenerateKurrentDBProjectionsPlugin
//
//  Created by Grady Zhuo on 2026/4/6.
//
import Foundation
import PackagePlugin

enum CommandPluginError: Error {
    case generationFailure(executable: String, arguments: [String], stdErr: String?)
}

extension URL {
    var absoluteStringNoScheme: String {
        var absoluteString = self.absoluteString.removingPercentEncoding ?? self.absoluteString
        absoluteString.trimPrefix("file://")
        return absoluteString
    }
}

@main
struct GenerateKurrentDBProjectionsPlugin {

    func performCommand(
        arguments: [String],
        tool: (String) throws -> PluginContext.Tool
    ) throws {
        let executableURL = try tool("generate").url

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["kurrentdb-projection"] + arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            let stdErr: String?
            if let errorData = try errorPipe.fileHandleForReading.readToEnd() {
                stdErr = String(decoding: errorData, as: UTF8.self)
            } else {
                stdErr = nil
            }
            throw CommandPluginError.generationFailure(
                executable: executableURL.absoluteStringNoScheme,
                arguments: arguments,
                stdErr: stdErr
            )
        }
        process.waitUntilExit()

        if process.terminationReason == .exit && process.terminationStatus == 0 {
            return
        }

        let stdErr: String?
        if let errorData = try errorPipe.fileHandleForReading.readToEnd() {
            stdErr = String(decoding: errorData, as: UTF8.self)
        } else {
            stdErr = nil
        }
        throw CommandPluginError.generationFailure(
            executable: executableURL.absoluteStringNoScheme,
            arguments: arguments,
            stdErr: stdErr
        )
    }
}

extension GenerateKurrentDBProjectionsPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        try self.performCommand(
            arguments: arguments,
            tool: context.tool
        )
    }
}
