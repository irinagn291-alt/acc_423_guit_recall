import Foundation

enum RecallMode: Int, CaseIterable, Codable {
    case order, change, pattern
    var title: String { ["In sequence", "Spot the change", "Read the pattern"][rawValue] }
    var short: String { ["Sequence", "Change", "Pattern"][rawValue] }
    var print: String { ["SequencePrint","ChangePrint","PatternPrint"][rawValue] }
    var instruction: String {
        ["Memorise the cards, then rebuild their order.", "Compare two hands and find the card that was replaced.", "Identify the strongest pattern in five open cards."][rawValue]
    }
}

enum Pattern: String, CaseIterable, Codable {
    case high = "High card", pair = "One pair", two = "Two pair", three = "Three of a kind", run = "Straight", flush = "Flush", house = "Full house", four = "Four of a kind", straightFlush = "Straight flush"
    var rule: String {
        switch self {
        case .high: return "All five ranks differ. They do not form a run or share a suit."
        case .pair: return "Two cards share one rank. The other three ranks differ."
        case .two: return "Two different ranks each occur twice."
        case .three: return "Three cards share a rank. The other two have different ranks."
        case .run: return "Five ranks form an unbroken run. An ace may sit below two or above the king."
        case .flush: return "All five cards share a suit without forming a run."
        case .house: return "Three cards of one rank sit alongside a pair of another rank."
        case .four: return "Four cards share a rank, one from each suit."
        case .straightFlush: return "All five ranks run in sequence and all five cards share a suit."
        }
    }
    static func classify(_ cards: [PlayingCard]) -> Self {
        let ranks = cards.map { $0.id % 13 }
        let counts = Dictionary(grouping:ranks,by:{$0}).values.map(\.count).sorted(by:>)
        let sorted = Set(ranks).sorted()
        let run = sorted.count == 5 && (sorted[4]-sorted[0] == 4 || sorted == [0,9,10,11,12])
        let flush = Set(cards.map(\.suit)).count == 1
        if run && flush { return .straightFlush }
        if counts.first == 4 { return .four }
        if counts == [3,2] { return .house }
        if flush { return .flush }
        if run { return .run }
        if counts.first == 3 { return .three }
        if counts == [2,2,1] { return .two }
        if counts.first == 2 { return .pair }
        return .high
    }
}

extension PlayingCard {
    init(code: Substring) {
        let rank = Self.ranks.firstIndex(of:String(code.dropLast()))!
        let suit = ["S","H","C","D"].firstIndex(of:String(code.suffix(1)))!
        self.init(id:suit*13+rank)
    }
}

struct Lesson: Identifiable {
    let id: Int
    let mode: RecallMode
    let title: String
    let cards: [PlayingCard]
    let tray: [PlayingCard]
    let changedIndex: Int?
    let replacement: PlayingCard?
    let options: [Pattern]
    let expected: Pattern?
    var number: Int { id / 3 + 1 }
    var tier: String { ["Foundation","Development","Mastery"][max(0,id)/10] }
    var revealed: [PlayingCard] {
        var next = cards
        if let changedIndex, let replacement { next[changedIndex] = replacement }
        return next
    }
    static func hand(_ text:String) -> [PlayingCard] { text.split(separator:" ").map(PlayingCard.init(code:)) }

    init(id:Int, mode:RecallMode, title:String, cards:[PlayingCard], tray:[PlayingCard] = [],
         changedIndex:Int? = nil, replacement:PlayingCard? = nil, options:[Pattern] = [], expected:Pattern? = nil) {
        self.id=id; self.mode=mode; self.title=title; self.cards=cards; self.tray=tray
        self.changedIndex=changedIndex; self.replacement=replacement; self.options=options; self.expected=expected
    }

    static let course: [Lesson] = {
        let order = [
            ("First impressions","AS 3H 7C 9D KS","2C 8H"),
            ("Red intervals","4H 8D JS 2C QH","6S 9C"),
            ("Picture parade","JC 5H QD 2S KH","9D AC"),
            ("Alternating suits","4S 5H 6S 7H 8S","7S 6H 8H"),
            ("Odd numbers","3C 5D 7C 9D JC","7D 9C JD"),
            ("Royal neighbours","QH JS KD JH QS","KS JD QC"),
            ("Mirror ranks","2D 9S 6H 9C 2H","6D 2C 9D"),
            ("Close quarters","7H 8H 7D 8D 7C","8C 7S 8S 9H"),
            ("Reverse echoes","KS QD JC QS KD","KC QC JD JH"),
            ("The final cut","10S JC 10C JS 10D","JD 10H JH 9S")
        ]
        let change = [
            ("One new face","2S 7H KD",1,"QC"),("Last light","4H 8C JS",2,"AD"),
            ("Colour switch","AS 5D 9H",0,"3C"),("Same place","6C 2D QS 8H",2,"QH"),
            ("One step up","3H 5C 8D JS",0,"4H"),("Twin eights","8D 4S 8C KH",2,"8S"),
            ("Middle distance","2S 6H 9D 6C JH",1,"6D"),("Quiet substitution","JS QD 10S QH JD",3,"QC"),
            ("Four red ranks","7D 8H 9D 8D 7H",1,"9H"),("Fine print","10S JC 10C JD 10D",4,"10H")
        ]
        let pattern: [(String,String,Pattern,[Pattern])] = [
            ("Two alike","8S 3D 8H KC 2C",.pair,[.two,.high,.pair]),
            ("Five in step","4S 7H 5C 8D 6H",.run,[.run,.flush,.high]),
            ("One family","2H KH 7H 10H 4H",.flush,[.high,.flush,.run]),
            ("Double edition","6S JS 2D 6H JC",.two,[.house,.pair,.two,.three]),
            ("Three signatures","9D AS 9H 9C 5S",.three,[.two,.three,.four,.house]),
            ("A broken run","4S 5H 7D 8C 9H",.high,[.run,.pair,.flush,.high]),
            ("Full company","QC 3S QD 3C QH",.house,[.two,.house,.four,.three]),
            ("The fourth seal","KC KS 2H KH KD",.four,[.flush,.house,.three,.four]),
            ("Ace at the edge","4C AC 5C 2C 3C",.straightFlush,[.straightFlush,.flush,.run,.high]),
            ("Crown sequence","QD AS 10H KC JS",.run,[.flush,.high,.run,.straightFlush])
        ]
        var all=[Lesson]()
        for i in 0..<10 {
            let a=order[i], target=hand(a.1), available=target+hand(a.2)
            // A fixed permutation keeps each authored exercise repeatable without revealing the answer.
            let permuted=available.indices.sorted { ($0*17+i*5)%23 < ($1*17+i*5)%23 }.map { available[$0] }
            all.append(Lesson(id:i*3,mode:.order,title:a.0,cards:target,tray:permuted))
            let b=change[i]
            all.append(Lesson(id:i*3+1,mode:.change,title:b.0,cards:hand(b.1),changedIndex:b.2,replacement:hand(b.3)[0]))
            let c=pattern[i]
            all.append(Lesson(id:i*3+2,mode:.pattern,title:c.0,cards:hand(c.1),options:c.3,expected:c.2))
        }
        return all
    }()
}
