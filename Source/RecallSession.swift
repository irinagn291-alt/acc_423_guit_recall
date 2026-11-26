import Foundation

struct PlayingCard: Equatable, Hashable, Codable {
    let id: Int
    static let ranks = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]
    static let names = ["Ace","Two","Three","Four","Five","Six","Seven","Eight","Nine","Ten","Jack","Queen","King"]
    static let suits = ["Spades","Hearts","Clubs","Diamonds"]
    static let symbols = ["♠","♥","♣","♦"]
    var rank: String { Self.ranks[id % 13] }
    var suit: Int { id / 13 }
    var label: String { "\(Self.names[id % 13]) of \(Self.suits[suit])" }
}

struct RecallSession: Codable, Equatable {
    enum Phase: String, Codable { case study, recall, review }
    var target: [PlayingCard]
    var tray: [PlayingCard]
    var answer = [PlayingCard]()
    var phase = Phase.study
    var completed = 0
    var correctPositions = 0

    static func deal() -> Self {
        let cards = Array((0..<52).shuffled().prefix(7)).map { PlayingCard(id: $0) }
        let target = Array(cards.prefix(5))
        var tray = cards.shuffled()
        if tray.filter({ target.contains($0) }) == target { tray.reverse() }
        return Self(target: target, tray: tray)
    }

    var matches: Int { zip(target, answer).filter { $0 == $1 }.count }

    mutating func choose(_ card: PlayingCard) {
        guard phase == .recall, answer.count < target.count, tray.contains(card), !answer.contains(card) else { return }
        answer.append(card)
    }

    mutating func finish() {
        guard phase == .recall, answer.count == target.count else { return }
        phase = .review
        completed += 1
        correctPositions += matches
    }

    mutating func next(repeatDeal: Bool) {
        let total = completed, correct = correctPositions
        if repeatDeal { answer.removeAll(); phase = .study; tray.shuffle() }
        else { self = Self.deal() }
        completed = total
        correctPositions = correct
    }

    static func restore(_ data: Data?) -> Self {
        guard let data, let round = try? JSONDecoder().decode(Self.self, from: data),
              round.target.count == 5, round.tray.count == 7, Set(round.tray).count == 7,
              Set(round.target).count == 5, Set(round.target).isSubset(of: Set(round.tray)),
              round.tray.allSatisfy({ (0..<52).contains($0.id) }),
              round.answer.count <= 5, Set(round.answer).count == round.answer.count,
              Set(round.answer).isSubset(of: Set(round.tray)),
              round.phase != .review || round.answer.count == 5 else { return deal() }
        return round
    }
}
