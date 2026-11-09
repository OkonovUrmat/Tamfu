import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Video picked from the library, copied into tmp so we own the file.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}

enum MediaPickerLoader {
    /// Loads a PhotosPicker item into a `MediaItem`.
    static func load(_ item: PhotosPickerItem) async -> MediaItem? {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                return MediaItem(kind: .video, source: .localFile(movie.url), moderation: .pending)
            }
            return nil
        }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data),
           let jpeg = image.jpegData(compressionQuality: 0.8) {
            return MediaItem(kind: .photo, source: .imageData(jpeg), moderation: .pending)
        }
        return nil
    }
}

@MainActor
@Observable
final class ComposeViewModel {
    var draft = BottleDraft()
    var photoSelection: PhotosPickerItem?
    var videoSelection: PhotosPickerItem?
    var isLoadingMedia = false
    var isSending = false
    var didSend = false
    var errorMessage: String?

    let prompts = [
        "What's something that made you happy today?",
        "Greetings from Kyrgyzstan!",
        "Does anyone else feel like time is moving too fast?",
        "Tell me about the view from your window.",
        "What song is stuck in your head?"
    ]

    var canAddMedia: Bool { draft.media.count < BottleDraft.maxMedia }
    var remainingCharacters: Int { BottleDraft.maxLength - draft.text.count }
    var canSend: Bool { !draft.isEmpty && remainingCharacters >= 0 && !isSending && !isLoadingMedia }

    func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingMedia = true
        defer { isLoadingMedia = false }
        if let media = await MediaPickerLoader.load(item), canAddMedia {
            withAnimation(Theme.Motion.snappy) { draft.media.append(media) }
        } else if !canAddMedia {
            errorMessage = "You can attach up to \(BottleDraft.maxMedia) items."
        } else {
            errorMessage = "Couldn't load that file. Try another one."
        }
        photoSelection = nil
        videoSelection = nil
    }

    func remove(_ item: MediaItem) {
        withAnimation(Theme.Motion.snappy) { draft.media.removeAll { $0.id == item.id } }
    }

    func usePrompt(_ prompt: String) {
        withAnimation { draft.text = prompt }
    }

    func send(using model: AppModel) async {
        errorMessage = nil
        isSending = true
        defer { isSending = false }
        do {
            try await model.sendBottle(draft)
            withAnimation(Theme.Motion.gentle) { didSend = true }
        } catch {
            withAnimation { errorMessage = error.localizedDescription }
        }
    }
}

struct ComposeBottleView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var vm = ComposeViewModel()
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        ZStack {
            if vm.didSend {
                BottleThrowView {
                    dismiss()
                }
                .transition(.opacity)
            } else {
                editor
                    .transition(.opacity)
            }
        }
        .onChange(of: vm.photoSelection) { _, item in
            Task { await vm.load(item) }
        }
        .onChange(of: vm.videoSelection) { _, item in
            Task { await vm.load(item) }
        }
    }

    private var editor: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    paper
                    if !vm.draft.media.isEmpty || vm.isLoadingMedia { mediaStrip }
                    attachmentButtons
                    promptIdeas
                    safetyNote
                }
                .padding(Theme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("New bottle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("\(model.quota.remaining) bottles left today")
                        .font(.ui(13, weight: .medium))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: Theme.Spacing.s) {
                    if let error = vm.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.ui(13, weight: .medium))
                            .foregroundStyle(Theme.Palette.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    Button {
                        hideKeyboard()
                        Task { await vm.send(using: model) }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isSending {
                                ProgressView().tint(.white)
                                Text("Sealing your bottle…")
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Throw into the ocean")
                            }
                        }
                    }
                    .buttonStyle(.primary)
                    .disabled(!vm.canSend || model.quota.remaining == 0)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.m)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear { isEditorFocused = true }
    }

    private var paper: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("To: someone, somewhere")
                    .font(.display(15, weight: .regular))
                    .italic()
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Text("\(vm.remainingCharacters)")
                    .font(.roundedUI(12, weight: .semibold))
                    .foregroundStyle(vm.remainingCharacters < 0 ? Theme.Palette.danger : Theme.Palette.textTertiary)
                    .contentTransition(.numericText())
            }
            TextField("Write something personal, ask a question, or simply say hello…",
                      text: $vm.draft.text, axis: .vertical)
                .font(.display(21, weight: .regular))
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(6...14)
                .focused($isEditorFocused)
        }
        .padding(Theme.Spacing.xl)
        .frame(minHeight: 260, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(Theme.Palette.parchment)
                .shadow(color: Theme.Palette.deepOcean.opacity(0.08), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .strokeBorder(Theme.Palette.sand.opacity(0.7), lineWidth: 1)
        )
    }

    private var mediaStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.m) {
                ForEach(vm.draft.media) { item in
                    MediaThumbnail(item: item)
                        .frame(width: 120, height: 150)
                        .overlay(alignment: .topTrailing) {
                            Button { vm.remove(item) } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(CircleIconButtonStyle(size: 28, background: .black.opacity(0.55), foreground: .white))
                            .padding(6)
                            .accessibilityLabel("Remove attachment")
                        }
                        .transition(.scale.combined(with: .opacity))
                }
                if vm.isLoadingMedia {
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .fill(Theme.Palette.surfaceMuted)
                        .frame(width: 120, height: 150)
                        .overlay(ProgressView())
                }
            }
        }
    }

    private var attachmentButtons: some View {
        HStack(spacing: Theme.Spacing.m) {
            PhotosPicker(selection: $vm.photoSelection, matching: .images) {
                attachmentLabel("Add Photo", icon: "photo")
            }
            .disabled(!vm.canAddMedia)
            PhotosPicker(selection: $vm.videoSelection, matching: .videos) {
                attachmentLabel("Add Video", icon: "video")
            }
            .disabled(!vm.canAddMedia)
        }
    }

    private func attachmentLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.ui(15, weight: .semibold))
        .foregroundStyle(vm.canAddMedia ? Theme.Palette.accent : Theme.Palette.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Theme.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
            .strokeBorder(Theme.Palette.hairline, lineWidth: 1))
    }

    private var promptIdeas: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Need an idea?")
                .font(.ui(13, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(vm.prompts, id: \.self) { prompt in
                        Button { vm.usePrompt(prompt) } label: {
                            Text(prompt)
                                .font(.ui(14))
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .multilineTextAlignment(.leading)
                                .frame(width: 180, alignment: .leading)
                                .padding(Theme.Spacing.m)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Palette.surface))
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
    }

    private var safetyNote: some View {
        Label("Your bottle goes to one random person. Only your first initial, age range and country are shown until you choose to share more.",
              systemImage: "lock.shield")
            .font(.ui(13))
            .foregroundStyle(Theme.Palette.textSecondary)
    }
}

/// Success animation: the bottle is thrown, ripples spread, the sea settles.
struct BottleThrowView: View {
    var onFinish: () -> Void
    @State private var thrown = false
    @State private var ripple = false
    @State private var showText = false

    var body: some View {
        ZStack {
            Theme.Gradients.ocean.ignoresSafeArea()
            VStack {
                Spacer()
                OceanWaves(height: 260, tint: Theme.Palette.seafoam)
            }
            .ignoresSafeArea()

            ForEach(0..<3, id: \.self) { i in
                Ellipse()
                    .strokeBorder(.white.opacity(ripple ? 0 : 0.5), lineWidth: 1.5)
                    .frame(width: ripple ? 320 : 20, height: ripple ? 80 : 6)
                    .offset(y: 120)
                    .animation(.easeOut(duration: 1.8).delay(0.9 + Double(i) * 0.25), value: ripple)
            }

            BottleIllustration(size: 150, glow: true)
                .rotationEffect(.degrees(thrown ? 200 : -10))
                .scaleEffect(thrown ? 0.25 : 1)
                .offset(x: thrown ? 40 : 0, y: thrown ? 120 : 40)
                .opacity(thrown ? 0 : 1)

            VStack(spacing: Theme.Spacing.m) {
                Text("Your bottle is drifting")
                    .font(.display(28, weight: .bold))
                Text("We'll let you know when someone finds it.")
                    .font(.ui(16))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .offset(y: -170)
            .opacity(showText ? 1 : 0)
        }
        .sensoryFeedback(.success, trigger: ripple)
        .onAppear {
            withAnimation(.easeIn(duration: 1.1)) { thrown = true }
            ripple = true
            withAnimation(.easeOut(duration: 0.6).delay(1.2)) { showText = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { onFinish() }
        }
    }
}
