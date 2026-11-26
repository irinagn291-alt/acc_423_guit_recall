import SwiftUI

let ink = Color(red:0.09,green:0.095,blue:0.11)
let ivory = Color(red:0.99,green:0.966,blue:0.89)
let redInk = Color(red:0.69,green:0.13,blue:0.09)
private let stock = Color(red:0.96,green:0.94,blue:0.89)
private let cobalt = Color(red:0.115,green:0.18,blue:0.65)
private let saffron = Color(red:0.92,green:0.67,blue:0.24)

private extension RecallMode {
    var colour:Color { [cobalt,redInk,saffron][rawValue] }
    var onColour:Color { self == .pattern ? ink : ivory }
    var symbol:String { ["rectangle.stack","rectangle.2.swap","suit.club.fill"][rawValue] }
}

@main
struct SuitRecallApp: App {
    var body: some Scene { WindowGroup { RecallStudio() } }
}

private var appDefaults: UserDefaults {
    #if DEBUG
    if StoreFrame.current != nil { return UserDefaults(suiteName:"preview.suitrecall.store")! }
    if let suite = ProcessInfo.processInfo.environment["UI_TEST_SUITE"], suite.hasPrefix("test.") {
        return UserDefaults(suiteName:suite) ?? .standard
    }
    #endif
    return .standard
}

private struct RecallStudio: View {
    static let key="suitrecall.workbook.v1"
    @State private var book: Workbook
    @State private var help=false
    @State private var deckOpen=false
    @State private var coveredLesson:Int?
    @Environment(\.dynamicTypeSize) private var type
    private var task:Lesson { book.lesson }
    private var round:LessonRound { book.round }

    init() {
        #if DEBUG
        if let frame = StoreFrame.current {
            var book = Workbook()
            for id in 0..<12 {
                book.open(id)
                let lesson = book.lesson
                book.reveal()
                switch lesson.mode {
                case .order:
                    var cards = lesson.cards
                    if id == 3 { cards.swapAt(0,1) }
                    for card in cards { book.pick(card) }
                case .change: book.rounds[id]?.spot = id == 7 ? (lesson.changedIndex! + 1) % lesson.cards.count : lesson.changedIndex
                case .pattern: book.rounds[id]?.pattern = id == 11 ? lesson.options.first { $0 != lesson.expected } : lesson.expected
                }
                book.finish()
            }
            switch frame {
            case .printStudio: book.page = .home
            case .pictureParade: book.open(6); book.retry()
            case .rebuildOrder:
                book.open(15); book.reveal()
                for card in book.lesson.cards.prefix(3) { book.pick(card) }
            case .quietSubstitution:
                book.open(22); book.reveal()
                book.rounds[22]?.spot = Lesson.course[22].changedIndex
            case .fullCompany:
                book.open(20)
                book.rounds[20]?.pattern = Lesson.course[20].expected
            case .changeProof:
                book.open(16); book.reveal()
                book.rounds[16]?.spot = Lesson.course[16].changedIndex
                book.finish()
            case .revisitErrors: book.page = .mistakes
            }
            _book = State(initialValue:book)
            return
        }
        #endif
        _book = State(initialValue:Workbook.restore(appDefaults.data(forKey:Self.key),legacy:appDefaults.data(forKey:"suitrecall.session.v1")))
    }

    var body: some View {
        GeometryReader { g in
            let wide=g.size.width >= 700 && !type.isAccessibilitySize
            let sideDesk=book.page == .desk && round.phase != .review && !type.isAccessibilitySize
                && g.size.width > 560 && g.size.width > g.size.height * 1.2
            let shortDesk=sideDesk && g.size.height < 530
            ScrollView {
                VStack(alignment:.leading,spacing:shortDesk ? 6 : wide ? 23 : 14) {
                    switch book.page {
                    case .home: home(wide:wide)
                    case .contents,.mistakes: contents(wide:wide)
                    case .desk: desk(wide:wide,sideDesk:sideDesk,shortDesk:shortDesk)
                    }
                }.padding(.horizontal,shortDesk ? 12 : wide ? 32 : 17).padding(.vertical,shortDesk ? 3 : 12)
                    .frame(maxWidth:1060).frame(maxWidth:.infinity)
            }.id("\(book.page.rawValue)-\(book.active)-\(round.phase.rawValue)")
        }.foregroundStyle(ink).background(stock.ignoresSafeArea()).preferredColorScheme(.light)
        .environment(\.monochromeCards, book.monochrome == true)
        .task(id:coveredLesson) {
            guard let id=coveredLesson else { return }
            do { try await Task.sleep(for:.milliseconds(650)) } catch { return }
            if coveredLesson == id { coveredLesson=nil }
        }
        .onChange(of:book) { _, updated in
            if let data=try? JSONEncoder().encode(updated) { appDefaults.set(data,forKey:Self.key) }
        }
        .sheet(isPresented:$deckOpen) {
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    HStack {
                        headline("The deck",35); Spacer()
                        Button { deckOpen=false } label:{ Image(systemName:"xmark").frame(width:44,height:44) }.accessibilityLabel("Close deck")
                    }
                    Toggle("Monochrome cards",isOn:Binding(get:{ book.monochrome == true },set:{ book.monochrome=$0 }))
                        .accessibilityIdentifier("monochrome")
                    HStack(spacing:8) {
                        ForEach(0..<4,id:\.self) { suit in
                            VStack {
                                CardFace(card:PlayingCard(id:suit*13)).aspectRatio(0.70,contentMode:.fit)
                                Text(tr(PlayingCard.suits[suit])).font(.caption)
                            }
                        }
                    }
                    Text("Every suit has a distinct shape. VoiceOver reads the rank and suit of each card.").font(.callout)
                }.padding(20)
            }.background(stock).environment(\.monochromeCards,book.monochrome == true)
                .presentationDetents([.medium,.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented:$help) {
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    HStack { Text("Pattern guide").font(.largeTitle.bold()); Spacer(); Button { help=false } label:{ Image(systemName:"xmark.circle").frame(width:44,height:44) }.accessibilityLabel("Close") }
                    ForEach(Pattern.allCases.reversed(),id:\.self) { p in
                        Text(tr(p.rawValue)).font(.headline)
                        Text(tr(p.rule)).font(.callout)
                        Divider()
                    }
                }.padding(22)
            }.background(stock).presentationDragIndicator(.visible)
        }
    }

    private var usesLatinDisplay: Bool { interfaceLocale.language.languageCode?.identifier == "en" }
    private func displayFont(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        let face: String
        switch interfaceLocale.language.languageCode?.identifier {
        case "ar": face = "GeezaPro-Bold"
        case "zh": face = "PingFangTC-Semibold"
        default: face = "AvenirNextCondensed-Heavy"
        }
        return .custom(face, size: size, relativeTo: style)
    }
    private func headline(_ text:String,_ size:CGFloat=38) -> some View {
        Text(tr(text)).font(displayFont(size, relativeTo: .largeTitle))
            .tracking(usesLatinDisplay ? -1.4 : 0).fixedSize(horizontal:false,vertical:true).accessibilityAddTraits(.isHeader)
    }
    private func imprint(_ text:String) -> some View {
        Text(tr(text).uppercased(with:interfaceLocale)).font(.system(.caption,design:.monospaced,weight:.bold)).tracking(usesLatinDisplay ? 1 : 0)
    }
    private func action(_ label:String,_ symbol:String,_ id:String,enabled:Bool=true,_ f:@escaping ()->Void) -> some View {
        Button(action:f) {
            HStack { Text(tr(label)).font(.headline); Spacer(); Image(systemName:symbol) }
                .padding(.horizontal,16).padding(.vertical,12).frame(maxWidth:.infinity,minHeight:49)
                .foregroundStyle(enabled ? ivory : ink.opacity(0.65)).background(enabled ? ink : ink.opacity(0.11),in:RoundedRectangle(cornerRadius:6))
        }.buttonStyle(.plain).disabled(!enabled).accessibilityIdentifier(id)
    }
    private func studioLink(_ label:String="Studio") -> some View {
        Button { book.page = .home } label: {
            Label(tr(label),systemImage:"arrow.backward").font(.subheadline.bold()).frame(minHeight:44)
        }.buttonStyle(.plain).accessibilityIdentifier("studio")
    }

    @ViewBuilder private func home(wide:Bool) -> some View {
        if type.isAccessibilitySize {
            VStack(alignment:.leading,spacing:4) { imprint("Card studies"); deckButton }
        } else { HStack { imprint("Card studies"); Spacer(); deckButton } }
        Rectangle().fill(ink).frame(height:2)
        HStack(alignment:.bottom,spacing:16) {
            VStack(alignment:.leading,spacing:0) {
                headline("Guit Recall",wide ? 82 : 56)
                Text(tr(book.completed == 30 ? (book.mistakes.isEmpty ? "All 30 studies mastered" : "Every study visited") : "A workbook for visual memory")).font(.system(.body,design:.serif)).italic()
            }
            Spacer(minLength:0)
            if !type.isAccessibilitySize { Text("♠").font(.system(size:wide ? 82 : 54,weight:.bold,design:.serif)).foregroundStyle(cobalt).accessibilityHidden(true) }
        }
        if type.isAccessibilitySize {
            VStack(alignment:.leading,spacing:6) {
                imprint(tr("%@ / 30 studied", numeral(book.completed)))
                ProgressView(value:Double(book.completed),total:30).tint(cobalt).accessibilityHidden(true)
            }
        } else {
            HStack {
                ProgressView(value:Double(book.completed),total:30).tint(cobalt).accessibilityHidden(true)
                imprint(tr("%@ / 30 studied", numeral(book.completed)))
            }
        }
        let activeRound=book.rounds[book.active]
        let resume=activeRound != nil && activeRound?.phase != .review
        if resume || book.nextUnseen != nil {
            action(resume ? tr("Resume · %@", tr(task.title)) : book.completed == 0 ? "Start first study" : "Next unfinished study","arrow.up.forward","continue") { book.open(resume ? book.active : book.nextUnseen ?? 0) }
        }
        if book.completed == 30 && !book.mistakes.isEmpty && !resume {
            action(tr("Revisit %@ missed studies", numeral(book.mistakes.count)),"arrow.counterclockwise","revisit-all") { book.page = .mistakes }
        }
        if wide {
            HStack(alignment:.top,spacing:14) { ForEach(RecallMode.allCases,id:\.self) { modeTile($0,wide:true) } }
        } else {
            ForEach(RecallMode.allCases,id:\.self) { modeTile($0,wide:false) }
        }
        Divider().overlay(ink)
        toolsRow
    }

    private func modeTile(_ mode:RecallMode,wide:Bool) -> some View {
        let done=Lesson.course.filter { $0.mode == mode && book.records[$0.id] != nil }.count
        return Button { book.mode=mode;book.page = .contents } label: {
            let info=VStack(alignment:.leading,spacing:5) {
                imprint(tr("%@ / 10 studies", numeral(done)))
                Text(tr(mode.title)).font(displayFont(29, relativeTo:.title2))
                    .fixedSize(horizontal:false,vertical:true)
                Text(tr(mode.instruction)).font(.callout).fixedSize(horizontal:false,vertical:true)
            }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
            Group {
                if type.isAccessibilitySize { info }
                else if wide {
                    VStack(alignment:.leading,spacing:0) {
                        Rectangle().fill(.clear).aspectRatio(0.95,contentMode:.fit)
                            .overlay { modePrint(mode) }
                        info
                    }
                } else {
                    HStack(spacing:0) {
                        info
                        Rectangle().fill(.clear).frame(width:76).overlay { modePrint(mode) }
                    }.fixedSize(horizontal:false,vertical:true)
                }
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(mode.onColour).background(mode.colour)
            .clipShape(RoundedRectangle(cornerRadius:6))
            .accessibilityIdentifier("mode-\(mode.rawValue)")
    }
    private func modePrint(_ mode:RecallMode) -> some View {
        GeometryReader { geo in
            Image(mode.print).resizable().scaledToFill()
                .frame(width:geo.size.width,height:geo.size.height).clipped()
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
    private var deckButton:some View {
        Button { deckOpen=true } label:{ Label("Deck",systemImage:"suit.spade.fill").font(.subheadline.bold()).frame(minHeight:44) }
            .accessibilityIdentifier("deck")
    }
    private var toolsRow:some View {
        ViewThatFits(in:.horizontal) {
            HStack(spacing:14) { mistakesButton; Spacer(); practiceButton }
            VStack(alignment:.leading) { mistakesButton; practiceButton }
        }
    }
    private var mistakesButton:some View {
        Button { book.page = .mistakes } label:{ Label(tr("Revisit errors (%@)", numeral(book.mistakes.count)),systemImage:"arrow.counterclockwise").frame(minHeight:44) }
            .disabled(book.mistakes.isEmpty).accessibilityIdentifier("errors")
    }
    private var practiceButton:some View {
        Button { book.open(-1) } label:{ Label("Free practice",systemImage:"shuffle").frame(minHeight:44) }.accessibilityIdentifier("practice")
    }

    @ViewBuilder private func contents(wide:Bool) -> some View {
        let errors=book.page == .mistakes
        HStack { studioLink(); Spacer(); imprint(errors ? "Review" : tr("%@ / 10", tr(book.mode.short))) }
        Rectangle().fill(ink).frame(height:2)
        headline(errors ? "Revisit errors" : book.mode.title,wide ? 58 : 40)
        Text(tr(errors ? "A correct replay clears a study from this list." : book.mode.instruction)).font(.body)
        let items=Lesson.course.filter { errors ? book.mistakes.contains($0.id) : $0.mode == book.mode }
        ForEach(["Foundation","Development","Mastery"],id:\.self) { tier in
            let group=items.filter { $0.tier == tier }
            if !group.isEmpty {
                HStack { imprint(tier); Rectangle().fill(ink.opacity(0.28)).frame(height:1) }
                ForEach(group) { lesson in
                    Button { book.open(lesson.id) } label:{
                        HStack(spacing:14) {
                            Text(numeral(lesson.number,padded:true)).font(.system(.headline,design:.monospaced,weight:.bold))
                                .foregroundStyle(lesson.mode.onColour).frame(width:44,height:44).background(lesson.mode.colour)
                            VStack(alignment:.leading) {
                                if errors { imprint(lesson.mode.short) }
                                Text(tr(lesson.title)).font(.headline)
                            }
                            Spacer()
                            Image(systemName:book.records[lesson.id]?.needsPractice == true ? "arrow.counterclockwise" : book.records[lesson.id] != nil ? "checkmark.circle.fill" : "arrow.up.forward")
                        }.frame(minHeight:44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("lesson-\(lesson.id)")
                }
            }
        }
    }

    @ViewBuilder private func desk(wide:Bool,sideDesk:Bool,shortDesk:Bool) -> some View {
        HStack {
            studioLink()
            Spacer()
            Button { book.mode=task.mode;book.page = .contents } label:{ Label("Studies",systemImage:"list.bullet").frame(minHeight:44) }
                .accessibilityIdentifier("studies")
        }.font(.subheadline.bold())
        Rectangle().fill(ink).frame(height:2)
        if sideDesk {
            HStack(alignment:.top,spacing:shortDesk ? 18 : 28) {
                VStack(alignment:.leading,spacing:shortDesk ? 8 : 16) {
                    deskTitle(size:shortDesk ? 30 : 45)
                    Text(tr(instruction)).font(shortDesk ? .callout : .body).fixedSize(horizontal:false,vertical:true)
                    deskActions
                }.frame(width:shortDesk ? 202 : 254,alignment:.leading)
                VStack(alignment:.leading,spacing:shortDesk ? 8 : 16) {
                    if task.mode == .order && round.phase == .recall {
                        orderTray(wide:true,shortDesk:shortDesk)
                    } else {
                        handStage(wide:true,shortDesk:shortDesk)
                        if task.mode == .pattern { patternPicks }
                    }
                }.frame(maxWidth:.infinity)
            }
        } else {
            deskTitle(size:wide ? 55 : 39)
            if round.phase == .review {
                review(wide:wide)
            } else {
                Text(tr(instruction)).font(.body).fixedSize(horizontal:false,vertical:true)
                if task.mode == .order && round.phase == .recall {
                    orderTray(wide:wide)
                } else {
                    handStage(wide:wide)
                    if task.mode == .pattern { patternPicks }
                }
                deskActions
            }
        }
    }
    @ViewBuilder private func deskTitle(size:CGFloat) -> some View {
        imprint(book.active == -1 ? "Sequence / Free practice" : tr("%1$@ · %2$@/10 · %3$@", tr(task.mode.short), numeral(task.number,padded:true), tr(task.tier)))
            .foregroundStyle(task.mode == .pattern ? ink : task.mode.colour)
        headline(task.title,size)
    }
    @ViewBuilder private var deskActions:some View {
        if round.phase == .study {
            action(task.mode == .change ? "Show the second hand" : "Hide cards","arrow.forward","hide") {
                if task.mode == .change { coveredLesson=book.active }
                book.reveal()
            }
        } else {
            if task.mode == .order {
                Button { _=book.rounds[book.active]?.order.popLast() } label:{ Label("Undo last card",systemImage:"arrow.uturn.backward").frame(minHeight:44) }.disabled(round.order.isEmpty)
            }
            action(task.mode == .order ? "Check order" : task.mode == .change ? "Check change" : "Check pattern","checkmark","check",enabled:round.ready(task)) { book.finish() }
            if task.mode == .pattern { Button("Pattern guide") { help=true }.frame(minHeight:44) }
        }
    }
    private var instruction:String {
        switch (task.mode,round.phase) {
        case (.order,.study): return "Read the five cards from left to right, row by row. Hide the hand when you are ready."
        case (.order,_): return "Choose the cards in their original order."
        case (.change,.study): return "Study each position. One card will be replaced."
        case (.change,_): return "Tap the card that changed in this second hand."
        case (.pattern,_): return "Which pattern best describes these five cards?"
        }
    }

    private func handStage(wide:Bool,shortDesk:Bool=false) -> some View {
        let pick=task.mode == .change && round.phase == .recall
        let cards=pick ? task.revealed : task.cards
        let rowSize=wide ? cards.count : (cards.count == 4 ? 2 : 3)
        let rows=stride(from:0,to:cards.count,by:rowSize).map { Array($0..<min($0+rowSize,cards.count)) }
        return VStack(alignment:.leading,spacing:shortDesk ? 5 : 12) {
            HStack { imprint(task.mode == .pattern ? "Open hand" : pick ? "Second hand" : "Study hand"); Spacer(); Text("♠  ♥  ♣  ♦").accessibilityHidden(true) }
            Rectangle().fill(task.mode.onColour.opacity(0.43)).frame(height:1)
            VStack(spacing:10) {
                ForEach(rows,id:\.self) { row in
                    HStack(spacing:shortDesk ? 8 : wide ? 16 : 10) {
                        ForEach(row,id:\.self) { index in
                            let card=cards[index]
                            VStack(spacing:3) {
                                if pick && coveredLesson == task.id {
                                    ZStack {
                                        RoundedRectangle(cornerRadius:6).fill(ink)
                                        RoundedRectangle(cornerRadius:4).strokeBorder(ivory.opacity(0.75)).padding(4)
                                        Image(systemName:"diamond.fill").foregroundStyle(ivory)
                                    }.accessibilityLabel("Covered card")
                                } else if pick {
                                    Button { book.rounds[book.active]?.spot=index } label:{
                                        CardFace(card:card).overlay(RoundedRectangle(cornerRadius:7).strokeBorder(round.spot == index ? ink : .clear,lineWidth:4))
                                    }.buttonStyle(.plain).accessibilityLabel(tr("Position %1$@, %2$@", numeral(index+1), card.spokenName))
                                        .accessibilityAddTraits(round.spot == index ? .isSelected : []).accessibilityIdentifier("change-\(index)")
                                } else { CardFace(card:card).accessibilityIdentifier("slot-\(index)") }
                                Text(pick && round.spot == index ? "✓ \(numeral(index+1))" : numeral(index+1)).font(.caption.monospacedDigit()).accessibilityHidden(true)
                            }.aspectRatio(0.65,contentMode:.fit).frame(maxWidth:shortDesk ? 76 : wide ? 166 : (task.mode == .pattern && !type.isAccessibilitySize ? 84 : 104))
                        }
                    }
                }
            }.frame(maxWidth:.infinity)
        }.padding(shortDesk ? 10 : wide ? 24 : 13).foregroundStyle(task.mode.onColour).background(task.mode.colour,in:RoundedRectangle(cornerRadius:7))
    }

    private func orderTray(wide:Bool,shortDesk:Bool=false) -> some View {
        VStack(alignment:.leading,spacing:shortDesk ? 6 : 13) {
            HStack(spacing:6) {
                ForEach(0..<5,id:\.self) { index in
                    if index < round.order.count {
                        CardFace(card:round.order[index]).accessibilityIdentifier("slot-\(index)")
                    } else {
                        RoundedRectangle(cornerRadius:5).strokeBorder(ivory.opacity(0.55),style:StrokeStyle(lineWidth:1,dash:[4,3]))
                            .overlay(Text(numeral(index+1)).foregroundStyle(ivory)).accessibilityLabel(tr("Empty position %@", numeral(index+1)))
                    }
                }
            }.aspectRatio(4.1,contentMode:.fit).frame(maxHeight:shortDesk ? 64 : nil).padding(shortDesk ? 5 : 10)
                .frame(maxWidth:.infinity).background(cobalt,in:RoundedRectangle(cornerRadius:7))
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:8),count:wide ? 5 : 4),spacing:8) {
                ForEach(task.tray,id:\.id) { card in
                    Button { book.pick(card) } label:{
                        CardFace(card:card).aspectRatio(0.75,contentMode:.fit).shadow(color:ink.opacity(0.22),radius:0,y:1)
                            .opacity(round.order.contains(card) ? 0.24 : 1)
                    }.buttonStyle(.plain).disabled(round.order.contains(card) || round.order.count==5)
                        .accessibilityLabel(card.spokenName).accessibilityIdentifier("pick-\(card.id)")
                }
            }.frame(maxWidth:shortDesk ? 327 : 670).frame(maxWidth:.infinity)
        }
    }
    private var patternPicks:some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:type.isAccessibilitySize ? 260 : 142))],spacing:8) {
            ForEach(task.options,id:\.self) { p in
                Button { book.rounds[book.active]?.pattern=p } label:{
                    HStack { Text(tr(p.rawValue)).font(.headline); Spacer(); Image(systemName:round.pattern == p ? "largecircle.fill.circle" : "circle") }
                        .padding(10).frame(maxWidth:.infinity,minHeight:46).overlay(RoundedRectangle(cornerRadius:5).strokeBorder(ink.opacity(0.42))).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityAddTraits(round.pattern == p ? .isSelected : []).accessibilityIdentifier("pattern-\(p.rawValue)")
            }
        }
    }

    @ViewBuilder private func review(wide:Bool) -> some View {
        let points=round.score(task)
        let perfect=points == (task.mode == .order ? 5 : 1)
        VStack(alignment:.leading,spacing:5) {
            imprint("Study result")
            Text(task.mode == .order ? tr("%@ of 5 positions correct", numeral(points)) : tr(perfect ? "Correct" : "Try this one again"))
                .font(.system(.title2,design:.serif,weight:.bold)).accessibilityIdentifier("score")
        }.padding(16).frame(maxWidth:.infinity,alignment:.leading).foregroundStyle(task.mode.onColour).background(task.mode.colour,in:RoundedRectangle(cornerRadius:6))
        switch task.mode {
        case .order:
            ForEach(task.cards.indices,id:\.self) { i in
                let expected=task.cards[i], actual=round.order[i]
                HStack(spacing:13) {
                    CardFace(card:expected).frame(width:38,height:53).accessibilityHidden(true)
                    VStack(alignment:.leading) { Text(tr("%1$@. %2$@", numeral(i+1), expected.spokenName)).bold(); if actual != expected { Text(tr("Your pick: %@", actual.spokenName)).font(.subheadline) } }
                    Spacer(); Image(systemName:expected == actual ? "checkmark" : "arrow.triangle.2.circlepath")
                }
                Divider()
            }
        case .change:
            if let index=task.changedIndex, let new=task.replacement {
                HStack(spacing:18) {
                    CardFace(card:task.cards[index]).aspectRatio(0.7,contentMode:.fit)
                    Image(systemName:"arrow.forward")
                    CardFace(card:new).aspectRatio(0.7,contentMode:.fit)
                }.frame(height:wide ? 205 : 135)
                Text(tr("Position %1$@ changed from %2$@ to %3$@.", numeral(index+1), task.cards[index].spokenName, new.spokenName))
                if !perfect, let picked=round.spot { Text(tr("You chose position %@.", numeral(picked+1))).font(.subheadline) }
            }
        case .pattern:
            if let correct=task.expected {
                Text(tr(correct.rawValue)).font(.title2.bold())
                Text(tr(correct.rule))
                if !perfect, let guess=round.pattern { Text(tr("Your answer: %@", tr(guess.rawValue))).font(.subheadline) }
                handStage(wide:wide)
            }
        }
        action(book.active == -1 ? "New hand" : book.completed == 30 ? (book.mistakes.isEmpty ? "Back to studio" : "Revisit errors") : "Next study","arrow.forward","next") { book.next() }
        Button("Practise again") { book.retry() }.frame(minHeight:44).accessibilityIdentifier("retry")
        if book.active == -1 {
            Text(tr("%1$@ practice hands · %2$@%% accuracy", numeral(book.practice.completed), numeral(book.practice.correctPositions * 100 / max(1,book.practice.completed * 5)))).font(.footnote)
        }
    }
}
