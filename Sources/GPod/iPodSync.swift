import Foundation
import Clibgpod

/// Metadata written to an audio track in an iPod library.
public struct AudioTrackMetadata: Sendable {
    public let title: String
    public let artist: String?
    public let album: String?
    public let genre: String?
    public let durationMilliseconds: Int32?
    public let bitrate: Int32?
    public let sampleRate: UInt16?

    public init(
        title: String,
        artist: String? = nil,
        album: String? = nil,
        genre: String? = nil,
        durationMilliseconds: Int32? = nil,
        bitrate: Int32? = nil,
        sampleRate: UInt16? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.durationMilliseconds = durationMilliseconds
        self.bitrate = bitrate
        self.sampleRate = sampleRate
    }
}

/// Errors raised before libgpod can copy a track.
public enum iPodSyncError: LocalizedError, Sendable {
    case sourceFileNotFound(URL)
    case masterPlaylistMissing

    public var errorDescription: String? {
        switch self {
        case .sourceFileNotFound(let url):
            return "The source audio file does not exist at \(url.path)."
        case .masterPlaylistMissing:
            return "The iPod database does not contain a master playlist."
        }
    }
}

public extension iTunesDB {
    /// Copies an audio file to the iPod and adds it to its master playlist.
    ///
    /// This changes the in-memory database. Call `write()` after this method
    /// returns successfully to persist the database update.
    @discardableResult
    func addAudioFile(at sourceURL: URL, metadata: AudioTrackMetadata) throws -> Track {
        guard sourceURL.isFileURL,
              FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw iPodSyncError.sourceFileNotFound(sourceURL)
        }

        guard let masterPlaylist = itdb_playlist_mpl(pointer) else {
            throw iPodSyncError.masterPlaylistMissing
        }

        guard let trackPointer = itdb_track_new() else {
            throw GPodError(message: "Could not create an iPod track.")
        }

        trackPointer.pointee.title = g_strdup(metadata.title)
        trackPointer.pointee.artist = metadata.artist.flatMap { g_strdup($0) }
        trackPointer.pointee.album = metadata.album.flatMap { g_strdup($0) }
        trackPointer.pointee.genre = metadata.genre.flatMap { g_strdup($0) }
        trackPointer.pointee.filetype = g_strdup(Self.fileType(for: sourceURL))
        trackPointer.pointee.mediatype = UInt32(ITDB_MEDIATYPE_AUDIO.rawValue)
        trackPointer.pointee.tracklen = metadata.durationMilliseconds ?? 0
        trackPointer.pointee.bitrate = metadata.bitrate ?? 0
        trackPointer.pointee.samplerate = metadata.sampleRate ?? 0

        if let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
           let size = attributes[.size] as? NSNumber {
            trackPointer.pointee.size = Int32(clamping: size.int64Value)
        }

        // libgpod needs the database association before it can choose a Music/Fxx path.
        itdb_track_add(pointer, trackPointer, -1)

        do {
            try sourceURL.path.withCString { sourcePath in
                try withGErrorBool { error in
                    itdb_cp_track_to_ipod(trackPointer, sourcePath, error)
                }
            }
        } catch {
            itdb_track_remove(trackPointer)
            throw error
        }

        itdb_playlist_add_track(masterPlaylist, trackPointer, -1)
        return Track(pointer: trackPointer, db: self)
    }

    private static func fileType(for sourceURL: URL) -> String {
        switch sourceURL.pathExtension.lowercased() {
        case "m4a", "m4b", "mp4":
            return "AAC audio file"
        case "mp3":
            return "MPEG audio file"
        case "wav":
            return "WAV audio file"
        default:
            return "Audio file"
        }
    }
}
