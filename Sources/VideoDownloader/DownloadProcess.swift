import Foundation

final class DownloadProcess {
    private let process = Process()
    private let outputPipe = Pipe()
    private var outputBuffer = ""
    private let lock = NSLock()

    func start(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        output: @escaping @Sendable (String) -> Void,
        completion: @escaping @Sendable (ProcessOutcome) -> Void
    ) throws {
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.receive(data: data, output: output)
        }

        process.terminationHandler = { [weak self] process in
            self?.flush(output: output)
            self?.outputPipe.fileHandleForReading.readabilityHandler = nil
            completion(.exited(process.terminationStatus))
        }

        DispatchQueue.global(qos: .userInitiated).async { [process] in
            do {
                try process.run()
            } catch {
                completion(.failed(error.localizedDescription))
            }
        }
    }

    func cancel() {
        guard process.isRunning else { return }
        process.terminate()
    }

    private func receive(data: Data, output: @escaping @Sendable (String) -> Void) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        lock.lock()
        outputBuffer.append(chunk)
        let pieces = outputBuffer.components(separatedBy: .newlines)
        outputBuffer = pieces.last ?? ""
        let completeLines = pieces.dropLast()
        lock.unlock()

        for line in completeLines where !line.isEmpty {
            output(line)
        }
    }

    private func flush(output: @escaping @Sendable (String) -> Void) {
        lock.lock()
        let remaining = outputBuffer
        outputBuffer = ""
        lock.unlock()

        if !remaining.isEmpty {
            output(remaining)
        }
    }
}
