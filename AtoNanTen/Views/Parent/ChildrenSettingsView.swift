import SwiftData
import SwiftUI

struct ChildrenSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChildProfile.sortOrder) private var children: [ChildProfile]
    @Query private var goals: [RewardGoal]
    @Query private var tasks: [TaskItem]
    @Query private var requests: [CompletionRequest]
    @Query private var histories: [PointHistory]
    @Query private var redemptions: [RewardRedemption]
    @AppStorage("selectedChildID") private var selectedChildID = ""

    @State private var editingChild: ChildProfile?
    @State private var childToDelete: ChildProfile?
    @State private var showsSelectedChildNotice = false
    @State private var showsAddChild = false

    var body: some View {
        List {
            Section {
                ForEach(children) { child in
                    Button {
                        editingChild = child
                    } label: {
                        HStack(spacing: 14) {
                            Text(child.avatarEmoji)
                                .font(.system(size: 34))
                                .frame(width: 50, height: 50)
                                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(child.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if child.id.uuidString == selectedChildID {
                                    Text("いま表示している子ども")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppTheme.purple)
                                }
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if children.count > 1 {
                            Button("削除", role: .destructive) {
                                if child.id.uuidString == selectedChildID {
                                    showsSelectedChildNotice = true
                                } else {
                                    childToDelete = child
                                }
                            }
                        }
                    }
                }
                .onMove(perform: moveChildren)
            } footer: {
                Text("子ども画面では、上部の名前をタップしてきょうだいを切り替えられます。いま表示している子どもは削除できないので、先に別の子どもへ切り替えてください。")
            }

            Section {
                Button {
                    showsAddChild = true
                } label: {
                    Label("子どもを追加", systemImage: "person.badge.plus")
                        .font(.headline)
                }
            }
        }
        .navigationTitle("子どもの管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(item: $editingChild) { child in
            NavigationStack {
                ChildProfileEditorView(child: child)
            }
        }
        .fullScreenCover(isPresented: $showsAddChild) {
            SetupFlowView(isAddingSibling: true)
        }
        .alert(
            "\(childToDelete?.name ?? "子ども")を削除しますか？",
            isPresented: Binding(
                get: { childToDelete != nil },
                set: { if !$0 { childToDelete = nil } }
            )
        ) {
            Button("キャンセル", role: .cancel) { childToDelete = nil }
            Button("削除", role: .destructive) {
                if let childToDelete {
                    self.childToDelete = nil
                    deleteChild(childToDelete)
                }
            }
        } message: {
            Text("この子どものポイント、行動、申請、履歴がすべて削除されます。この操作は元に戻せません。")
        }
        .alert("いま表示している子どもは削除できません", isPresented: $showsSelectedChildNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("子ども画面の上部で別の子どもに切り替えてから、もう一度お試しください。")
        }
    }

    private func moveChildren(from source: IndexSet, to destination: Int) {
        var reordered = children
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, child) in reordered.enumerated() {
            child.sortOrder = index
        }
        try? modelContext.save()
    }

    private func deleteChild(_ child: ChildProfile) {
        guard children.count > 1, selectedChildID != child.id.uuidString else { return }

        goals.filter { $0.childID == child.id }.forEach(modelContext.delete)
        tasks.filter { $0.childID == child.id }.forEach(modelContext.delete)
        requests.filter { $0.childID == child.id }.forEach(modelContext.delete)
        histories.filter { $0.childID == child.id }.forEach(modelContext.delete)
        redemptions.filter { $0.childID == child.id }.forEach(modelContext.delete)
        modelContext.delete(child)

        try? modelContext.save()
    }
}

private struct ChildProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let child: ChildProfile
    @State private var name: String
    @State private var avatarEmoji: String

    private let avatars = ["🧒", "👦", "👧", "🐶", "🐱", "🐰"]

    init(child: ChildProfile) {
        self.child = child
        _name = State(initialValue: child.name)
        _avatarEmoji = State(initialValue: child.avatarEmoji)
    }

    var body: some View {
        Form {
            Section("おなまえ") {
                TextField("名前", text: $name)
                    .textContentType(.name)
            }

            Section("アイコン") {
                EmojiPicker(selection: $avatarEmoji, candidates: avatars, columns: 3)
            }
        }
        .navigationTitle("プロフィール編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        child.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        child.avatarEmoji = avatarEmoji
        try? modelContext.save()
        dismiss()
    }
}
