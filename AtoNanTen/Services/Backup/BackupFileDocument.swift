import SwiftUI
import UniformTypeIdentifiers

nonisolated struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

nonisolated enum BackupFileReader {
    static let maximumSize = 50 * 1024 * 1024

    /// Coordinated reads also work for files supplied by iCloud Drive and other file providers.
    static func read(from url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { fileURL in
            result = Result {
                let handle = try FileHandle(forReadingFrom: fileURL)
                defer { try? handle.close() }
                // Bound the actual read, even when the provider reports an incorrect file size.
                return try handle.read(upToCount: maximumSize + 1) ?? Data()
            }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }
}
