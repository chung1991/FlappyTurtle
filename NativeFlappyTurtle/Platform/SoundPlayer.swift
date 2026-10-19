import AVFoundation

/// Replaces SimpleAudioEngine. Each effect gets a small pool of preloaded
/// players so rapid repeats (jump spam) overlap like the original.
final class SoundPlayer: SoundPlaying {
    var isMuted: Bool
    private var pools: [SoundEffect: [AVAudioPlayer]] = [:]
    private var nextIndex: [SoundEffect: Int] = [:]
    private let voicesPerEffect = 4

    init(muted: Bool = false, bundle: Bundle = .main) {
        isMuted = muted
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        for effect in SoundEffect.allCases {
            guard let url = bundle.url(forResource: effect.fileName, withExtension: nil) else { continue }
            pools[effect] = (0..<voicesPerEffect).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
        }
    }

    func play(_ effect: SoundEffect) {
        guard !isMuted, let pool = pools[effect], !pool.isEmpty else { return }
        let index = nextIndex[effect, default: 0]
        nextIndex[effect] = (index + 1) % pool.count
        let player = pool[index]
        player.currentTime = 0
        player.play()
    }
}
