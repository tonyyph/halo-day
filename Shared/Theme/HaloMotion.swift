import SwiftUI

enum Motion {
    static let snappy = Animation.spring(duration: 0.28, bounce: 0.15)
    static let smooth = Animation.spring(duration: 0.45, bounce: 0)
    static let gentle = Animation.spring(duration: 0.65, bounce: 0.05)
    static let bouncy = Animation.spring(duration: 0.5, bounce: 0.32)
    static let ring = Animation.spring(duration: 0.9, bounce: 0)
    static let draw = Animation.easeInOut(duration: 1.2)
    static let breathe = Animation.easeInOut(duration: 4)
    static let ambient = Animation.linear(duration: 8)
    static let phase = Animation.easeInOut(duration: 2.5)
    static let shimmer = Animation.linear(duration: 1.6)

    static func timer(_ remaining: TimeInterval) -> Animation {
        .linear(duration: max(0, remaining))
    }

    static func stagger(_ index: Int) -> Animation {
        smooth.delay(Double(min(index, 8)) * 0.04)
    }

    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : animation
    }
}
