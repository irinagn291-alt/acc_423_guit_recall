import Foundation

struct LessonRound: Codable, Equatable {
    var phase: RecallSession.Phase
    var order = [PlayingCard]()
    var spot: Int?
    var pattern: Pattern?
    init(_ mode: RecallMode) { phase = mode == .pattern ? .recall : .study }
    func score(_ lesson:Lesson) -> Int {
        switch lesson.mode {
        case .order: return zip(order,lesson.cards).filter { $0 == $1 }.count
        case .change: return spot == lesson.changedIndex ? 1 : 0
        case .pattern: return pattern == lesson.expected ? 1 : 0
        }
    }
    func ready(_ lesson:Lesson) -> Bool {
        switch lesson.mode {
        case .order: return order.count == lesson.cards.count
        case .change: return spot != nil
        case .pattern: return pattern != nil
        }
    }
}

struct LessonRecord: Codable, Equatable {
    var attempts=0
    var best=0
    var needsPractice=false
}

struct Workbook: Codable, Equatable {
    enum Page:String,Codable { case home, contents, desk, mistakes }
    var page = Page.home
    var mode = RecallMode.order
    var active = 0
    var monochrome: Bool?
    var rounds=[Int:LessonRound]()
    var records=[Int:LessonRecord]()
    var practice=RecallSession.deal()

    var lesson: Lesson {
        if active == -1 { return Lesson(id:-1,mode:.order,title:"Free practice",cards:practice.target,tray:practice.tray) }
        return Lesson.course[active]
    }
    var round: LessonRound { rounds[active] ?? LessonRound(lesson.mode) }
    var mistakes: [Int] { records.keys.filter { records[$0]?.needsPractice == true }.sorted() }
    var completed: Int { records.count }
    var nextUnseen: Int? { Lesson.course.first { records[$0.id] == nil }?.id }

    mutating func open(_ id:Int) {
        active=id; mode=lesson.mode; page = .desk
        if rounds[id] == nil { rounds[id]=LessonRound(lesson.mode) }
    }
    mutating func reveal() {
        guard round.phase == .study else { return }
        rounds[active]?.phase = .recall
    }
    mutating func pick(_ card:PlayingCard) {
        guard lesson.mode == .order, round.phase == .recall, round.order.count < lesson.cards.count,
              lesson.tray.contains(card), !round.order.contains(card) else { return }
        rounds[active]?.order.append(card)
    }
    mutating func finish() {
        let task=lesson, attempt=round
        guard attempt.phase == .recall, attempt.ready(task) else { return }
        let points=attempt.score(task)
        if active >= 0 {
            var record=records[active] ?? LessonRecord()
            record.attempts+=1
            record.best=max(points,record.best)
            record.needsPractice=points != (task.mode == .order ? task.cards.count : 1)
            records[active]=record
        } else {
            practice.completed+=1; practice.correctPositions+=points
        }
        rounds[active]?.phase = .review
    }
    mutating func retry() { rounds[active]=LessonRound(lesson.mode) }
    mutating func next() {
        if active == -1 {
            practice.next(repeatDeal:false); retry()
        } else if let following=Lesson.course.first(where:{ $0.mode == mode && $0.id > active && records[$0.id] == nil }) {
            open(following.id)
        } else if let nextUnseen { open(nextUnseen) }
        else { page = mistakes.isEmpty ? .home : .mistakes }
    }
    static func restore(_ data:Data?, legacy:Data?) -> Self {
        if let data, let book=try? JSONDecoder().decode(Self.self,from:data),
           (-1..<Lesson.course.count).contains(book.active),
           book.records.keys.allSatisfy({ Lesson.course.indices.contains($0) }),
           book.practice.target.count == 5, book.practice.tray.allSatisfy({ (0..<52).contains($0.id) }),
           Set(book.practice.target).isSubset(of:Set(book.practice.tray)) {
            var safe=book
            safe.rounds=book.rounds.filter { id,r in
                guard (-1..<Lesson.course.count).contains(id) else { return false }
                let task=id == -1 ? Lesson(id:-1,mode:.order,title:"Free practice",cards:book.practice.target,tray:book.practice.tray) : Lesson.course[id]
                return r.order.count <= task.cards.count && Set(r.order).count == r.order.count &&
                    Set(r.order).isSubset(of:Set(task.tray)) && (r.spot.map(task.cards.indices.contains) ?? true) &&
                    (r.pattern.map(task.options.contains) ?? true) && (r.phase != .review || r.ready(task))
            }
            if safe.page == .desk { safe.open(safe.active) }
            return safe
        }
        var book=Self()
        if let legacy {
            book.practice=RecallSession.restore(legacy)
            book.open(-1)
            book.rounds[-1]?.order=book.practice.answer
            book.rounds[-1]?.phase=book.practice.phase
        }
        return book
    }
}
