//
//  TestUtility.swift
//  
//
//  Created by Grady Zhuo on 2024/6/13.
//

import DDDCore
import KurrentDB
import EventStoreDB
import Logging

let logger = Logger(label: "TestUtility")

extension KurrentDBClient {
    public func clearStreams<T: Projectable>(projectableType: T.Type, id: T.ID, execpted revision: KurrentDB.StreamRevision = .any, errorHandler: ((_ error: Error)->Void)? = nil) async {
        do{
            let streamName = T.getStreamName(id: id)
            guard let metadata = try await self.getStreamMetadata(streamName) else{
                return
            }
            try await self.deleteStream(streamName){ options in
                options.revision(expected: revision)
            }
        }catch {
            logger.warning("The error happended when clear stream with \(id) in \(projectableType). error message: \(error)")
            errorHandler?(error)
        }
    }
}

extension EventStoreDBClient {
    public func clearStreams<T: Projectable>(projectableType: T.Type, id: T.ID, execpted revision: KurrentDB.StreamRevision = .any, errorHandler: ((_ error: Error)->Void)? = nil) async {
        await self.underlyingClient.clearStreams(projectableType: projectableType, id: id, execpted: revision, errorHandler: errorHandler)
    }
}

