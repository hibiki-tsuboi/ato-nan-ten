import Foundation

enum RewardDuration {
    static let options = [5, 10, 15, 20, 30, 45, 60]

    /// 「ゲーム 30ぷん」のような名前から時間を推測する
    static func minutes(in title: String) -> Int? {
        let pattern = /(\d+)\s*(分|ぷん|ふん)/
        guard let match = title.firstMatch(of: pattern),
              let minutes = Int(match.1),
              (1...240).contains(minutes) else {
            return nil
        }
        return minutes
    }

    static func text(for minutes: Int) -> String {
        minutes % 60 == 0 && minutes >= 60 ? "\(minutes / 60)時間" : "\(minutes)分"
    }
}
