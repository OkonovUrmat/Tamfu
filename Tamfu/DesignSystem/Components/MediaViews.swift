import SwiftUI
import AVKit
import AVFoundation

/// Renders any `MediaItem` image source with a soft gradient placeholder.
struct MediaImage: View {
    let item: MediaItem
    var contentMode: ContentMode = .fill

    var body: some View {
        GeometryReader { geo in
            content
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.source {
        case .imageData(let data):
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        case .remote(let url):
            if item.isVideo {
                remote(item.posterURL)
            } else {
                remote(url)
            }
        case .localFile:
            if let poster = item.posterURL {
                remote(poster)
            } else {
                VideoPosterView(item: item)
            }
        }
    }

    @ViewBuilder
    private func remote(_ url: URL?) -> some View {
        if let url {
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: contentMode).transition(.opacity)
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Theme.Gradients.seeded(item.placeholderSeed)
            Image(systemName: item.isVideo ? "film" : "photo")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

/// Generates a poster frame for a local video file.
struct VideoPosterView: View {
    let item: MediaItem
    @State private var poster: UIImage?

    var body: some View {
        ZStack {
            if let poster {
                Image(uiImage: poster).resizable().scaledToFill()
            } else {
                Theme.Gradients.seeded(item.placeholderSeed)
            }
        }
        .task(id: item.id) {
            guard poster == nil, let url = item.playableURL else { return }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            if let cg = try? await generator.image(at: .zero).image {
                poster = UIImage(cgImage: cg)
            }
        }
    }
}

/// Thumbnail with a play badge for videos.
struct MediaThumbnail: View {
    let item: MediaItem
    var cornerRadius: CGFloat = Theme.Radius.medium

    var body: some View {
        MediaImage(item: item)
            .overlay {
                if item.isVideo {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.black.opacity(0.35)))
                        .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Full-screen viewer for photos and videos.
struct MediaViewer: View {
    let items: [MediaItem]
    @State var selection: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(items) { item in
                    Group {
                        if item.isVideo, let url = item.playableURL {
                            InlineVideoPlayer(url: url)
                        } else {
                            MediaImage(item: item, contentMode: .fit)
                        }
                    }
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .always : .never))
            .ignoresSafeArea()

            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(CircleIconButtonStyle(size: 38, background: .black.opacity(0.4), foreground: .white))
                .padding()
        }
    }
}

struct InlineVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                if player == nil { player = AVPlayer(url: url) }
                player?.play()
            }
            .onDisappear { player?.pause() }
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let name: String
    var media: MediaItem?
    var seed: Int = 0
    var size: CGFloat = 44
    var isOnline = false
    var isBlurred = false

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    var body: some View {
        ZStack {
            if let media {
                MediaImage(item: media)
                    .blur(radius: isBlurred ? size * 0.18 : 0)
            } else {
                Theme.Gradients.seeded(seed)
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
        .overlay(alignment: .bottomTrailing) {
            if isOnline {
                Circle()
                    .fill(Theme.Palette.online)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .overlay(Circle().strokeBorder(Theme.Palette.surface, lineWidth: 2))
            }
        }
    }
}

extension AvatarView {
    init(profile: UserProfile, size: CGFloat = 44, showsOnline: Bool = true) {
        self.init(name: profile.name, media: profile.avatar, seed: profile.avatarSeed,
                  size: size, isOnline: showsOnline && profile.isOnline)
    }
}
