import SwiftUI
import UniformTypeIdentifiers

struct SourcesView: View {
    @ObservedObject var model: AppViewModel
    @ObservedObject private var store: SourceStore
    @State private var showingAdd = false
    @State private var showingImporter = false
    @State private var showingFileError = false
    @State private var name = ""
    @State private var url = ""
    @State private var formError: String?
    @State private var fileError: String?

    init(model: AppViewModel) {
        self.model = model
        self.store = model.sourceStore
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Nhập playlist") {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Nhập tệp M3U từ Tệp", systemImage: "doc.badge.plus")
                    }
                    Text("Chọn tệp .m3u hoặc .m3u8 đã lưu trên iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Nguồn tích hợp") {
                    sourceRow(store.defaultSource, subtitle: "Nguồn mặc định tích hợp sẵn • URL được ẩn")
                }
                Section("Nguồn đã thêm") {
                    if store.customSources.isEmpty {
                        Text("Chưa có nguồn tự thêm. Bạn vẫn có thể dùng nguồn NM7 IPTV mặc định.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.customSources) { source in
                            sourceRow(
                                source,
                                subtitle: source.url.isFileURL ? "Tệp M3U đã nhập trên thiết bị" : source.url.absoluteString
                            )
                        }
                        .onDelete { offsets in
                            store.remove(at: offsets)
                            Task { await model.reload() }
                        }
                    }
                }
            }
            .navigationTitle("Quản lý nguồn")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Thêm URL", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack {
                    Form {
                        TextField("Tên nguồn", text: $name)
                        TextField("https://…", text: $url)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        if let formError { Text(formError).foregroundStyle(.red) }
                    }
                    .navigationTitle("Thêm nguồn")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Hủy") { showingAdd = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Lưu") {
                                do {
                                    try store.add(name: name, urlText: url)
                                    name = ""; url = ""; formError = nil; showingAdd = false
                                } catch { formError = error.localizedDescription }
                            }
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [
                    UTType(filenameExtension: "m3u") ?? .plainText,
                    UTType(filenameExtension: "m3u8") ?? .plainText,
                    .plainText
                ],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let selectedURL = try result.get().first else { return }
                    let hasSecurityScope = selectedURL.startAccessingSecurityScopedResource()
                    defer {
                        if hasSecurityScope { selectedURL.stopAccessingSecurityScopedResource() }
                    }
                    let source = try store.importPlaylistFile(from: selectedURL)
                    Task { await model.selectSource(source) }
                } catch {
                    fileError = error.localizedDescription
                    showingFileError = true
                }
            }
            .alert("Không nhập được playlist", isPresented: $showingFileError) {
                Button("Đóng", role: .cancel) {}
            } message: {
                Text(fileError ?? "Tệp không đọc được.")
            }
        }
    }

    @ViewBuilder
    private func sourceRow(_ source: PlaylistSource, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if store.activeSourceID == source.id {
                Label("Đang dùng", systemImage: "checkmark.circle.fill").foregroundStyle(.cyan)
            } else {
                Button(source.isBuiltIn ? "Chọn mặc định" : "Chọn") {
                    Task { await model.selectSource(source) }
                }.buttonStyle(.bordered)
            }
        }
    }
}
