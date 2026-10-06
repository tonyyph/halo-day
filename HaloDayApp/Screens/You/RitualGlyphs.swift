import Foundation

/// SF Symbols offered for rituals, with their spoken names.
struct RitualGlyph: Identifiable, Sendable {
    let symbol: String
    let name: String
    var id: String { symbol }

    static let all: [RitualGlyph] = [
        ("drop", "Water"), ("book.closed", "Reading"), ("figure.walk", "Walk"),
        ("leaf", "Plants"), ("sun.max", "Sunshine"), ("moon.stars", "Rest"),
        ("pencil", "Writing"), ("heart", "Wellbeing"), ("cup.and.saucer", "Tea"),
        ("dumbbell", "Exercise"), ("bed.double", "Sleep"), ("face.smiling", "Smile"),
        ("pills", "Medication"), ("bag", "Shopping"), ("music.note", "Music"),
        ("camera", "Photography"), ("paintbrush", "Painting"), ("brain.head.profile", "Learning"),
        ("wind", "Breathe"), ("fork.knife", "Food"), ("figure.run", "Running"),
        ("figure.outdoor.cycle", "Cycling"), ("figure.pool.swim", "Swimming"),
        ("figure.yoga", "Yoga"), ("figure.flexibility", "Stretching"),
        ("briefcase", "Work"), ("calendar", "Calendar"), ("pencil.line", "Journal"),
        ("house", "Home"), ("airplane", "Travel"), ("globe", "Language"),
        ("lightbulb", "Creativity"), ("sparkles", "Gratitude"),
        ("waterbottle", "Hydration"), ("flame", "Cooking"), ("timer", "Quiet time"),
        ("lungs", "Fresh air"), ("eyes", "Screen break"), ("person.2", "Family"),
        ("hands.sparkles", "Self care")
    ].map { RitualGlyph(symbol: $0.0, name: $0.1) }
}
