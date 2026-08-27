import SwiftData
import SwiftUI

struct TaskSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @State private var editingTask: TaskItem?
    @State private var showsNewTask = false

    let child: ChildProfile
    let date: Date

    private var childTasks: [TaskItem] {
        tasks.filter { $0.childID == child.id }
    }

    private var nextSortOrder: Int {
        (childTasks.map(\.sortOrder).max() ?? -1) + 1
    }

    var body: some View {
        List {
            Section {
                ForEach(childTasks) { task in
                    HStack(spacing: 12) {
                        Button {
                            editingTask = task
                        } label: {
                            HStack(spacing: 12) {
                                Text(task.emoji).font(.system(size: 30))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(limitText(for: task))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("+\(task.points)点")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.purple)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Toggle("表示", isOn: scheduledBinding(for: task))
                            .labelsHidden()
                            .accessibilityLabel("\(task.title)を子ども画面に表示")
                    }
                }
                .onDelete(perform: deleteTasks)
                .onMove(perform: moveTasks)
            } header: {
                Text("子ども画面に表示する行動")
            } footer: {
                Text("スイッチをオンにした行動だけが子ども画面に表示されます。この選択は翌日以降もそのまま引き継がれるので、毎日設定し直す必要はありません。")
            }
        }
        .navigationTitle("行動の設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsNewTask = true
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showsNewTask) {
            NavigationStack {
                TaskEditorView(
                    childID: child.id,
                    task: nil,
                    suggestedSortOrder: nextSortOrder,
                    date: date
                )
            }
        }
        .sheet(item: $editingTask) { task in
            NavigationStack {
                TaskEditorView(
                    childID: child.id,
                    task: task,
                    suggestedSortOrder: task.sortOrder,
                    date: date
                )
            }
        }
    }

    private func scheduledBinding(for task: TaskItem) -> Binding<Bool> {
        Binding(
            get: { task.isScheduled(on: date) },
            set: { isScheduled in
                task.setScheduled(isScheduled, on: date)
                try? modelContext.save()
            }
        )
    }

    private func limitText(for task: TaskItem) -> String {
        guard let limit = task.dailyLimit else { return "回数制限なし" }
        return "1日\(limit)回まで"
    }

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(childTasks[index])
        }
        try? modelContext.save()
    }

    private func moveTasks(from source: IndexSet, to destination: Int) {
        var reordered = childTasks
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, task) in reordered.enumerated() {
            task.sortOrder = index
        }
        try? modelContext.save()
    }
}

private struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let childID: UUID
    let task: TaskItem?
    let suggestedSortOrder: Int
    let date: Date

    @State private var title: String
    @State private var emoji: String
    @State private var points: Int
    @State private var dailyLimitValue: Int

    private let emojis = ["📚", "✏️", "📖", "🧹", "🏫", "📝", "🛁", "🧸"]

    init(childID: UUID, task: TaskItem?, suggestedSortOrder: Int, date: Date) {
        self.childID = childID
        self.task = task
        self.suggestedSortOrder = suggestedSortOrder
        self.date = date
        _title = State(initialValue: task?.title ?? "")
        _emoji = State(initialValue: task?.emoji ?? "⭐️")
        _points = State(initialValue: task?.points ?? 1)
        _dailyLimitValue = State(initialValue: task?.dailyLimit ?? 0)
    }

    var body: some View {
        Form {
            Section("名前") {
                TextField("例：お風呂そうじ", text: $title)
            }

            Section("アイコン") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(emojis, id: \.self) { candidate in
                        Button {
                            emoji = candidate
                        } label: {
                            Text(candidate)
                                .font(.system(size: 32))
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(emoji == candidate ? AppTheme.yellow.opacity(0.3) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("ポイント") {
                Stepper("\(points)点", value: $points, in: 1...99)
            }

            Section("1日の回数") {
                Picker("上限", selection: $dailyLimitValue) {
                    Text("制限なし").tag(0)
                    Text("1回まで").tag(1)
                    Text("2回まで").tag(2)
                    Text("3回まで").tag(3)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle(task == nil ? "行動を追加" : "行動を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .fontWeight(.bold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let limit = dailyLimitValue == 0 ? nil : dailyLimitValue

        if let task {
            task.title = cleanedTitle
            task.emoji = emoji
            task.points = points
            task.dailyLimit = limit
        } else {
            modelContext.insert(TaskItem(
                childID: childID,
                title: cleanedTitle,
                emoji: emoji,
                points: points,
                dailyLimit: limit,
                sortOrder: suggestedSortOrder,
                scheduledDate: date
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}
