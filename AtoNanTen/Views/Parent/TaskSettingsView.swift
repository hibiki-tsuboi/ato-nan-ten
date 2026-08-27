import SwiftData
import SwiftUI

struct TaskSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @Query(sort: \ChildProfile.sortOrder) private var children: [ChildProfile]
    @State private var editingTask: TaskItem?
    @State private var showsNewTask = false
    @State private var showsCopySheet = false

    let child: ChildProfile
    let date: Date

    private var childTasks: [TaskItem] {
        tasks.filter { $0.childID == child.id }
    }

    private var otherChildren: [ChildProfile] {
        children.filter { $0.id != child.id }
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
                                    Text(scheduleText(for: task))
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

                        Toggle("表示", isOn: enabledBinding(for: task))
                            .labelsHidden()
                            .accessibilityLabel("\(task.title)を子ども画面に表示")
                    }
                }
                .onDelete(perform: deleteTasks)
                .onMove(perform: moveTasks)
            } header: {
                Text("子ども画面に表示する行動")
            } footer: {
                Text("スイッチをオンにした行動だけが子ども画面に表示されます。この選択は翌日以降もそのまま引き継がれるので、毎日設定し直す必要はありません。曜日を決めた行動は、その曜日だけ表示されます。")
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
            if !otherChildren.isEmpty && !childTasks.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsCopySheet = true
                    } label: {
                        Label("ほかの子どもにコピー", systemImage: "doc.on.doc")
                    }
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
        .sheet(isPresented: $showsCopySheet) {
            NavigationStack {
                CopyTasksView(sourceTasks: childTasks, targets: otherChildren, date: date)
            }
        }
    }

    private func enabledBinding(for task: TaskItem) -> Binding<Bool> {
        Binding(
            get: { task.isEnabled },
            set: { isEnabled in
                task.setEnabled(isEnabled, on: date)
                try? modelContext.save()
            }
        )
    }

    private func scheduleText(for task: TaskItem) -> String {
        let limit = task.dailyLimit.map { "1日\($0)回まで" } ?? "回数制限なし"
        return "\(WeekdayFormatter.summary(for: task)) ・ \(limit)"
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

enum WeekdayFormatter {
    static let symbols = ["日", "月", "火", "水", "木", "金", "土"]

    static func summary(for task: TaskItem) -> String {
        if task.isEveryWeekday { return "毎日" }

        let days = (1...7).filter { task.isWeekdayOn($0) }.map { symbols[$0 - 1] }
        return days.isEmpty ? "曜日が未選択" : days.joined(separator: "・")
    }
}

private struct CopyTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]

    let sourceTasks: [TaskItem]
    let targets: [ChildProfile]
    let date: Date

    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        List {
            Section {
                ForEach(targets) { target in
                    Button {
                        toggle(target)
                    } label: {
                        HStack(spacing: 12) {
                            Text(target.avatarEmoji).font(.title2)
                            Text(target.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: selectedIDs.contains(target.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedIDs.contains(target.id) ? AppTheme.mint : .secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("コピー先")
            } footer: {
                Text("\(sourceTasks.count)個の行動を、選んだ子どもにそのまま追加します。ポイントや曜日の設定も一緒にコピーされます。")
            }
        }
        .navigationTitle("行動をコピー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("コピー") { copyTasks() }
                    .fontWeight(.bold)
                    .disabled(selectedIDs.isEmpty)
            }
        }
    }

    private func toggle(_ target: ChildProfile) {
        if selectedIDs.contains(target.id) {
            selectedIDs.remove(target.id)
        } else {
            selectedIDs.insert(target.id)
        }
    }

    private func copyTasks() {
        for targetID in selectedIDs {
            var sortOrder = (allTasks.filter { $0.childID == targetID }.map(\.sortOrder).max() ?? -1) + 1

            for task in sourceTasks {
                let copy = TaskItem(
                    childID: targetID,
                    title: task.title,
                    emoji: task.emoji,
                    points: task.points,
                    dailyLimit: task.dailyLimit,
                    isEnabled: task.isEnabled,
                    sortOrder: sortOrder,
                    weekdayMask: task.weekdayMask
                )
                copy.refreshSchedule(on: date)
                modelContext.insert(copy)
                sortOrder += 1
            }
        }
        try? modelContext.save()
        dismiss()
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
    @State private var weekdayMask: Int

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
        _weekdayMask = State(initialValue: task?.weekdayMask ?? TaskItem.everyWeekday)
    }

    var body: some View {
        Form {
            Section("名前") {
                TextField("例：お風呂そうじ", text: $title)
            }

            Section("アイコン") {
                EmojiPicker(selection: $emoji, candidates: emojis)
            }

            Section("ポイント") {
                Stepper("\(points)点", value: $points, in: 1...99)
            }

            Section {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { weekday in
                        Button {
                            toggleWeekday(weekday)
                        } label: {
                            Text(WeekdayFormatter.symbols[weekday - 1])
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(isWeekdayOn(weekday) ? .white : AppTheme.ink.opacity(0.6))
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(
                                    isWeekdayOn(weekday) ? AppTheme.mint : Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(WeekdayFormatter.symbols[weekday - 1])曜日")
                        .accessibilityAddTraits(isWeekdayOn(weekday) ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)

                Button("毎日にする") {
                    weekdayMask = TaskItem.everyWeekday
                }
                .font(.subheadline.weight(.bold))
                .disabled(weekdayMask == TaskItem.everyWeekday)
            } header: {
                Text("表示する曜日")
            } footer: {
                Text("選んだ曜日だけ子ども画面に表示されます。")
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || weekdayMask == 0)
            }
        }
    }

    private func isWeekdayOn(_ weekday: Int) -> Bool {
        weekdayMask & (1 << (weekday - 1)) != 0
    }

    private func toggleWeekday(_ weekday: Int) {
        let bit = 1 << (weekday - 1)
        if isWeekdayOn(weekday) {
            weekdayMask &= ~bit
        } else {
            weekdayMask |= bit
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
            task.weekdayMask = weekdayMask
            task.refreshSchedule(on: date)
        } else {
            let newTask = TaskItem(
                childID: childID,
                title: cleanedTitle,
                emoji: emoji,
                points: points,
                dailyLimit: limit,
                sortOrder: suggestedSortOrder,
                weekdayMask: weekdayMask
            )
            newTask.refreshSchedule(on: date)
            modelContext.insert(newTask)
        }
        try? modelContext.save()
        dismiss()
    }
}
