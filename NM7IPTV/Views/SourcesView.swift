import SwiftUI

struct SourcesView: View {
    @ObservedObject var model: AppViewModel
    @ObservedObject private var store: SourceStore
    @State private var showingAdd = false
    @State private var name = ""
    @State private var url = ""
    @State private var formError: String?

    init(model: AppViewModel) {
        self.model = model
        self.store = model.sourceStore
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Nguồn tích hợp") {
                    sourceRow(store.defaultSource, subtitle: "Nguồn mặc định tích hợp sẵn • URL được ẩn")
                }
                Section("Nguồn đã thêm") {
                    if store.customSources.isEmpty {
                        Text("Chưa có nguồn tự thêm. Bạn vẫn có thể dùng nguồn NM7 IPTV mặc định.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.customSources) { source in
                            sourceRow(source, subtitle: source.url.absoluteString)
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
                Button { showingAdd = true } label: { Label("Thêm nguồn", systemImage: "plus") }
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
