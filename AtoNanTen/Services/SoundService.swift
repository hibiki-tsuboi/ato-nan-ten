import AudioToolbox
import Foundation

enum AppSound: String, CaseIterable {
    case complete
    case celebrate
    case finish
}

@MainActor
enum SoundService {
    private static var soundIDs: [AppSound: SystemSoundID] = [:]

    static func play(_ sound: AppSound) {
        guard AppSettings.isSoundEnabled, let soundID = soundID(for: sound) else { return }
        AudioServicesPlaySystemSound(soundID)
    }

    private static func soundID(for sound: AppSound) -> SystemSoundID? {
        if let existing = soundIDs[sound] { return existing }

        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else {
            return nil
        }

        var soundID: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &soundID) == kAudioServicesNoError else {
            return nil
        }

        soundIDs[sound] = soundID
        return soundID
    }
}
