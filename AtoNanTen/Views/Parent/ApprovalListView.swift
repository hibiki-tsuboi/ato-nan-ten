import SwiftData
import SwiftUI

struct ApprovalListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CompletionRequest.requestedAt, order: .reverse) private var requests: [CompletionRequest]
    let child: ChildProfile
    @Bindable var goal: RewardGoal

    private var pendingRequests: [CompletionRequest] {
        requests.filter { $0.childID == child.id && $0.status == .pending }
    }

    var body: some View {
        Group {
            if pendingRequests.isEmpty {
                ContentUnavailableView(
                    "承認待ちはありません",
                    systemImage: "checkmark.circle.fill",
                    description: Text("子どもが「できた！」を押すと、ここに表示されます。")
                )
            } else {
                List(pendingRequests) { request in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 13) {
                            Text(request.taskEmoji).font(.system(size: 36))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(request.taskTitle)
                                    .font(.headline)
                                Text(request.requestedAt.formatted(
                                    .dateTime.month().day().hour().minute().locale(Locale(identifier: "ja_JP"))
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+\(request.points)点")
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(AppTheme.purple)
                        }

                        HStack(spacing: 10) {
                            Button(role: .destructive) {
                                reject(request)
                            } label: {
                                Label("却下", systemImage: "xmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                approve(request)
                            } label: {
                                Label("承認する", systemImage: "checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.mint)
                        }
                        .fontWeight(.bold)
                    }
                    .padding(.vertical, 8)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("承認待ち")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func approve(_ request: CompletionRequest) {
        try? PointService.approve(request, goal: goal, in: modelContext)
    }

    private func reject(_ request: CompletionRequest) {
        try? PointService.reject(request, in: modelContext)
    }
}
