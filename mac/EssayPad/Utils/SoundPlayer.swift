import AppKit

enum SoundPlayer {
    /// macOS 系统音效(必须在主线程)
    /// 可选: Glass, Pop, Submarine, Blow, Bottle, Frog, Funk, Hero, Morse, Ping, Purr, Sosumi, Tink
    static func playTaskComplete() {
        DispatchQueue.main.async {
            if let sound = NSSound(named: "Glass") {
                sound.play()
            } else {
                NSSound.beep()
            }
        }
    }

    static func playProgress() {
        DispatchQueue.main.async {
            if let sound = NSSound(named: "Tink") {
                sound.play()
            } else {
                NSSound.beep()
            }
        }
    }
}