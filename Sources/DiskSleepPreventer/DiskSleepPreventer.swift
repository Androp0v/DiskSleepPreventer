import ArgumentParser
import Foundation
import Darwin

struct Volume: Codable, Sendable {
    let name: String
    let url: URL
}

@main
struct DiskSleepPreventer: AsyncParsableCommand {
    @Option(help: "The volume names of the disks to keep awake.")
    var disks: [String]
    @Option(help: "The frequency at which the disks should be queried, in seconds.")
    var seconds: Double = 20
    @Option(help: "The logging system to use. Options: os, terminal.")
    var logger: SharedLogger
    @Flag
    var verbose = false

    static let markerFilename = ".DiskSleepPreventer"
    static let markerFileContent = "KEEP_AWAKE"
    static let markerFileContentSize = 10

    func run() async throws {
        logger.info(StatusMessage.startupMessage(
            seconds: seconds,
            disks: disks)
        )

        while true {
            let keepAwakeVolumes = updatedKeepAwakeVolumes()
            guard !keepAwakeVolumes.isEmpty else {
                break
            }
            if verbose {
                logger.info(StatusMessage.keepingAwake(disks: keepAwakeVolumes))
            }
            for volume in keepAwakeVolumes {
                pokeDisk(at: volume.url)
            }
            if verbose {
                logger.info(StatusMessage.sleeping(for: seconds))
            }
            try await Task.sleep(for: .seconds(seconds))
        }
        logger.warning("No disks to keep awake!")
    }

    func updatedKeepAwakeVolumes() -> [Volume] {
        guard let allMountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.nameKey]
        ) else {
            return []
        }

        return allMountedVolumes.compactMap { volumeURL in
            do {
                let resourceValues = try volumeURL.resourceValues(forKeys: [.nameKey])
                guard let name = resourceValues.name else {
                    logger.warning("Mounted volume with unknown name at \(volumeURL.path)")
                    return nil
                }
                guard disks.contains(name) else {
                    return nil
                }
                return Volume(name: name, url: volumeURL)
            } catch {
                logger.warning("Failed to read resource values for \(volumeURL): \(error)")
                return nil
            }
        }
    }

    func pokeDisk(at url: URL) {
        let markerFile = url.appending(path: Self.markerFilename)
        do {
            let readTime = try ContinuousClock().measure {
                let contents = try readWithNoCache(at: markerFile)
                guard contents == Self.markerFileContent else {
                    logger.error("Unexpected contents in \(Self.markerFilename) file")
                    return
                }
            }
            if verbose, readTime.components.seconds < 1 {
                logger.info("Read took \(readTime)")
            } else if verbose {
                logger.warning("Read took \(readTime)")
            }
        } catch ReadError.noSuchFile {
            do {
                logger.info("Marker file not found on disk mounted at \(url), writing marker file...")
                try writeMarkerFile(at: markerFile)
                logger.info("Marker file written successfully at \(markerFile)")
            } catch {
                logger.error("Failed to write marker file at \(markerFile): \(error)")
            }
        } catch {
            logger.error("Failed to read contents of \(markerFile): \(error)")
        }
    }

    // Read the file using POSIX open/read with fcntl(F_NOCACHE) to avoid caching.
    private func readWithNoCache(at url: URL) throws -> String {
        let result = try url.withUnsafeFileSystemRepresentation { cPath in
            guard let cPath else {
                throw ReadError.unrepresentablePath
            }

            // Open read-only, avoid following symlinks for safety.
            let fileDescriptor = open(cPath, O_RDONLY | O_NOFOLLOW)
            if fileDescriptor == -1 {
                if errno == ENOENT {
                    throw ReadError.noSuchFile
                } else {
                    throw ReadError.posixError(errno)
                }
            }
            defer {
                _ = close(fileDescriptor)
            }

            // Disable caching
            guard fcntl(fileDescriptor, F_NOCACHE, 1) != -1 else {
                throw ReadError.unableToDisableCache
            }

            var buffer = UnsafeMutableBufferPointer<UInt8>.allocate(
                capacity: Self.markerFileContentSize
            )
            try buffer.withContiguousMutableStorageIfAvailable { bufferPointer in
                guard let basePointer = bufferPointer.baseAddress else {
                    throw ReadError.unexpectedNilBufferPointer
                }
                let bytesRead = read(
                    fileDescriptor,
                    basePointer,
                    Self.markerFileContentSize
                )

                guard bytesRead == Self.markerFileContentSize else {
                    if bytesRead == 0 {
                        throw ReadError.unexpectedEOF
                    } else {
                        throw ReadError.posixError(errno)
                    }
                }
            }
            return Data(buffer: buffer)
        }

        // Decode as UTF-8
        guard let string = String(data: result, encoding: .utf8) else {
            throw ReadError.invalidUTF8
        }
        return string
    }

    func writeMarkerFile(at markerFileURL: URL) throws {
        try Self.markerFileContent.write(
            to: markerFileURL,
            atomically: true,
            encoding: .utf8
        )
    }
}

enum ReadError: Error {
    case unrepresentablePath
    case noSuchFile
    case posixError(Int32)
    case unableToDisableCache
    case unexpectedEOF
    case unexpectedNilBufferPointer
    case invalidUTF8
}
