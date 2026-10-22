import Darwin
import Foundation

protocol DownloadRunning: AnyObject, Sendable {
    func start(executableURL: URL, arguments: [String], environment: [String: String],
               currentDirectoryURL: URL?, output: @escaping @Sendable (String) -> Void,
               completion: @escaping @Sendable (ProcessOutcome) -> Void) throws
    func cancel()
}

final class DownloadProcess: DownloadRunning, @unchecked Sendable {
    private let process = Process()
    private let outputPipe = Pipe()

    func start(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectoryURL: URL? = nil,
        output: @escaping @Sendable (String) -> Void,
        completion: @escaping @Sendable (ProcessOutcome) -> Void
    ) throws {
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = currentDirectoryURL
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        try? outputPipe.fileHandleForWriting.close()

        // Keep bytes until a complete line arrives, preserving split UTF-8 characters.
        // Drain the pipe before reporting completion so the last error cannot be lost.
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            var buffer = Data()
            let reader = outputPipe.fileHandleForReading
            while true {
                let chunk = reader.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)
                while let boundary = buffer.firstIndex(where: { $0 == 10 || $0 == 13 }) {
                    let line = String(decoding: buffer[..<boundary], as: UTF8.self)
                    buffer.removeSubrange(...boundary)
                    if !line.isEmpty { output(line) }
                }
            }
            if !buffer.isEmpty { output(String(decoding: buffer, as: UTF8.self)) }
            process.waitUntilExit()
            try? reader.close()
            completion(.exited(process.terminationStatus))
        }
    }

    func cancel() {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        if getpgid(pid) == pid {
            kill(-pid, SIGTERM)
        } else {
            process.terminate()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [self] in
            guard process.isRunning else { return }
            if getpgid(pid) == pid { kill(-pid, SIGKILL) }
            else { kill(pid, SIGKILL) }
        }
    }
}
