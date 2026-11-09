import SwiftUI
import PhotosUI

@MainActor
@Observable
final class EditProfileViewModel {
    var draft: UserProfile
    var photoSelection: PhotosPickerItem?
    var videoSelection: PhotosPickerItem?
    var isLoadingMedia = false
    var isSaving = false
    var errorMessage: String?
    private let original: UserProfile

    init(profile: UserProfile) {
        draft = profile
        original = profile
    }

    var hasChanges: Bool { draft != original }
    var isValid: Bool { draft.name.trimmingCharacters(in: .whitespaces).count >= 2 && draft.bio.count <= 300 }

    func add(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingMedia = true
        defer {
            isLoadingMedia = false
            photoSelection = nil
            videoSelection = nil
        }
        guard let media = await MediaPickerLoader.load(item) else { return }
        withAnimation(Theme.Motion.snappy) {
            if media.isVideo { draft.videos.append(media) } else { draft.photos.append(media) }
        }
    }

    func remove(_ item: MediaItem) {
        withAnimation(Theme.Motion.snappy) {
            draft.photos.removeAll { $0.id == item.id }
            draft.videos.removeAll { $0.id == item.id }
        }
    }

    func makePrimary(_ item: MediaItem) {
        guard let i = draft.photos.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(Theme.Motion.snappy) {
            let photo = draft.photos.remove(at: i)
            draft.photos.insert(photo, at: 0)
        }
    }

    func save(using model: AppModel) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            var cleaned = draft
            cleaned.name = cleaned.name.trimmingCharacters(in: .whitespaces)
            cleaned.bio = cleaned.bio.trimmingCharacters(in: .whitespacesAndNewlines)
            try await model.saveProfile(cleaned)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct EditProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var vm: EditProfileViewModel?

    var body: some View {
        Group {
            if let vm {
                EditProfileForm(vm: vm) {
                    Task {
                        if await vm.save(using: model) { dismiss() }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if vm == nil { vm = EditProfileViewModel(profile: model.currentUser) }
        }
    }
}

private struct EditProfileForm: View {
    @Bindable var vm: EditProfileViewModel
    var onSave: () -> Void

    var body: some View {
        Form {
            Section {
                mediaGrid
            } header: {
                Text("Photos & videos")
            } footer: {
                Text("Long-press a photo to make it your main picture. All media is reviewed for safety.")
            }

            Section("Basics") {
                TextField("Name", text: $vm.draft.name)
                    .textContentType(.name)
                DatePicker("Birthday", selection: $vm.draft.birthDate,
                           in: ...Calendar.current.date(byAdding: .year, value: -BottleRules.minimumAge, to: .now)!,
                           displayedComponents: .date)
                Picker("Country", selection: $vm.draft.country) {
                    ForEach(Country.all) { Text("\($0.flag) \($0.name)").tag($0) }
                }
                TextField("City", text: $vm.draft.city)
                TextField("Occupation", text: $vm.draft.details.occupation)
            }

            Section {
                TextField("A few words about you", text: $vm.draft.bio, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Current mood or status", text: $vm.draft.status)
            } header: {
                Text("Introduction")
            } footer: {
                Text("\(vm.draft.bio.count)/300")
                    .foregroundStyle(vm.draft.bio.count > 300 ? Theme.Palette.danger : Theme.Palette.textTertiary)
            }

            tagSection("Languages", tags: $vm.draft.languages, suggestions: MockData.allLanguages)
            tagSection("Interests", tags: $vm.draft.interests, suggestions: MockData.allInterests)
            tagSection("Hobbies", tags: $vm.draft.hobbies, suggestions: MockData.allHobbies)
            tagSection("Music", tags: $vm.draft.details.music, suggestions: [])
            tagSection("Movies & books", tags: $vm.draft.details.moviesBooks, suggestions: [])
            tagSection("Lifestyle", tags: $vm.draft.details.lifestyle, suggestions: ["Early riser", "Night owl", "Vegetarian", "Loves travel", "Homebody"])
            tagSection("Personality", tags: $vm.draft.details.personality, suggestions: ["Introvert", "Extrovert", "Curious", "Calm", "Funny", "Empathetic"])
            tagSection("More about me", tags: $vm.draft.details.additional, suggestions: [])

            if let error = vm.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Palette.danger)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if vm.isSaving {
                    ProgressView()
                } else {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                        .disabled(!vm.hasChanges || !vm.isValid)
                }
            }
        }
        .onChange(of: vm.photoSelection) { _, item in Task { await vm.add(item) } }
        .onChange(of: vm.videoSelection) { _, item in Task { await vm.add(item) } }
    }

    private var mediaGrid: some View {
        let items = vm.draft.photos + vm.draft.videos
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(items) { item in
                    MediaThumbnail(item: item, cornerRadius: 12)
                        .aspectRatio(0.8, contentMode: .fit)
                        .overlay(alignment: .topTrailing) {
                            Button { vm.remove(item) } label: { Image(systemName: "xmark") }
                                .buttonStyle(CircleIconButtonStyle(size: 24, background: .black.opacity(0.6), foreground: .white))
                                .padding(4)
                        }
                        .overlay(alignment: .bottomLeading) {
                            if item.id == vm.draft.photos.first?.id {
                                Text("Main")
                                    .font(.ui(10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Capsule().fill(Theme.Palette.accent))
                                    .padding(5)
                            }
                        }
                        .contextMenu {
                            if !item.isVideo {
                                Button { vm.makePrimary(item) } label: { Label("Make main photo", systemImage: "star") }
                            }
                            Button(role: .destructive) { vm.remove(item) } label: { Label("Remove", systemImage: "trash") }
                        }
                }
                if vm.isLoadingMedia {
                    RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.surfaceMuted)
                        .aspectRatio(0.8, contentMode: .fit)
                        .overlay(ProgressView())
                }
            }
            HStack {
                PhotosPicker(selection: $vm.photoSelection, matching: .images) {
                    Label("Add photo", systemImage: "photo.badge.plus")
                }
                Spacer()
                PhotosPicker(selection: $vm.videoSelection, matching: .videos) {
                    Label("Add video", systemImage: "video.badge.plus")
                }
            }
            .font(.ui(15, weight: .medium))
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func tagSection(_ title: String, tags: Binding<[String]>, suggestions: [String]) -> some View {
        Section(title) {
            TagEditor(tags: tags, placeholder: "Add \(title.lowercased())…", suggestions: suggestions)
                .padding(.vertical, 4)
        }
    }
}
