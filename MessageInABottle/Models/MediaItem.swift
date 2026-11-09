import Foundation

/// A photo or video attachment. `source` abstracts where the bytes live so the
/// same model works for mock data, freshly picked media and uploaded media.
struct MediaItem: Identifiable, Hashable, Codable {
    enum Kind: String, Codable, Hashable {
        case photo, video
    }

    enum Source: Hashable, Codable {
        /// Remote asset (CDN). Used by mock data and after upload.
        case remote(URL)
        /// Local file on disk (e.g. a picked video copied to tmp).
        case localFile(URL)
        /// Raw image bytes (e.g. a picked photo before upload).
        case imageData(Data)
    }

    let id: UUID
    var kind: Kind
    var source: Source
    /// Optional poster image for videos.
    var posterURL: URL?
    /// Seed used for the gradient placeholder while loading / offline.
    var placeholderSeed: Int
    var moderation: ModerationState

    init(id: UUID = UUID(),
         kind: Kind,
         source: Source,
         posterURL: URL? = nil,
         placeholderSeed: Int = Int.random(in: 0...50),
         moderation: ModerationState = .approved) {
        self.id = id
        self.kind = kind
        self.source = source
        self.posterURL = posterURL
        self.placeholderSeed = placeholderSeed
        self.moderation = moderation
    }

    var isVideo: Bool { kind == .video }

    var playableURL: URL? {
        switch source {
        case .remote(let url), .localFile(let url): return url
        case .imageData: return nil
        }
    }

    static func remotePhoto(_ seed: String, w: Int = 800, h: Int = 1000) -> MediaItem {
        MediaItem(kind: .photo,
                  source: .remote(URL(string: "https://picsum.photos/seed/\(seed)/\(w)/\(h)")!),
                  placeholderSeed: abs(seed.hashValue) % 50)
    }

    static func sampleVideo(posterSeed: String) -> MediaItem {
        MediaItem(kind: .video,
                  source: .remote(URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!),
                  posterURL: URL(string: "https://picsum.photos/seed/\(posterSeed)/800/600"),
                  placeholderSeed: abs(posterSeed.hashValue) % 50)
    }
}

enum ModerationState: String, Codable, Hashable {
    case pending, approved, rejected
}
