import Foundation

struct Transcription: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date
    let duration: TimeInterval

    init(id: UUID = UUID(), text: String, date: Date = Date(), duration: TimeInterval) {
        self.id = id
        self.text = text
        self.date = date
        self.duration = duration
    }
}
