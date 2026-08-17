import Clibgpod

/// Swift wrapper around libgpod's Itdb_Playlist.
///
/// Does not own the underlying C struct — the parent `iTunesDB` manages its lifecycle.
public final class Playlist: @unchecked Sendable {
    internal let pointer: UnsafeMutablePointer<Itdb_Playlist>
    private let db: iTunesDB  // prevent premature dealloc

    internal init(pointer: UnsafeMutablePointer<Itdb_Playlist>, db: iTunesDB) {
        self.pointer = pointer
        self.db = db
    }

    public var name: String? {
        get { pointer.pointee.name.map { String(cString: $0) } }
        set {
            g_free(pointer.pointee.name)
            pointer.pointee.name = newValue.flatMap { g_strdup($0) }
        }
    }

    public var id: UInt64 { pointer.pointee.id }
    public var isMaster: Bool { pointer.pointee.type == 1 }
    public var isSmartPlaylist: Bool { pointer.pointee.is_spl != 0 }
    public var isPodcast: Bool { pointer.pointee.podcastflag != 0 }
    public var trackCount: Int32 { pointer.pointee.num }

    /// The tracks in this playlist.
    public var tracks: [Track] {
        var result: [Track] = []
        var node = pointer.pointee.members
        while let current = node {
            if let data = current.pointee.data {
                let trackPtr = data.assumingMemoryBound(to: Itdb_Track.self)
                result.append(Track(pointer: trackPtr, db: db))
            }
            node = current.pointee.next
        }
        return result
    }
}

public extension iTunesDB {
    /// Creates a new, empty, non-smart playlist and adds it to the database.
    ///
    /// The playlist is added to the in-memory database. Call `write()` after
    /// this method returns successfully to persist the change.
    @discardableResult
    func addPlaylist(title: String) throws -> Playlist {
        guard let playlistPointer = itdb_playlist_new(title, 0) else {
            throw GPodError(message: "Could not create an iPod playlist.")
        }
        itdb_playlist_add(pointer, playlistPointer, -1)
        return Playlist(pointer: playlistPointer, db: self)
    }

    /// Removes a playlist with the given name from the database, if one exists.
    ///
    /// Only the playlist entry is removed; the tracks it referenced stay on the iPod.
    func removePlaylist(named name: String) {
        guard let existing = playlists.first(where: { $0.name == name }) else { return }
        itdb_playlist_remove(existing.pointer)
    }

    /// Appends a track to the end of a playlist, preserving manual ordering.
    func add(track: Track, to playlist: Playlist) {
        itdb_playlist_add_track(playlist.pointer, track.pointer, -1)
    }
}
