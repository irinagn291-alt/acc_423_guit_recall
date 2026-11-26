import XCTest

final class RecallJourney: XCTestCase {
    func testThirtyAnswerKeysAndWorkbookMigration() throws {
        XCTAssertEqual(Lesson.course.map(\.id),Array(0..<30))
        XCTAssertEqual(Set(Lesson.course.map(\.title)).count,30)
        XCTAssertEqual(Set(Lesson.course.map { $0.cards.map(\.id) }).count,30)
        XCTAssertEqual(Dictionary(grouping:Lesson.course,by:\.tier).mapValues(\.count),["Foundation":10,"Development":10,"Mastery":10])
        var book=Workbook()
        for lesson in Lesson.course {
            XCTAssertEqual(Set(lesson.cards).count,lesson.cards.count)
            XCTAssertTrue(lesson.cards.allSatisfy { (0..<52).contains($0.id) })
            book.open(lesson.id);book.reveal()
            switch lesson.mode {
            case .order:
                XCTAssertEqual(Set(lesson.tray).count,lesson.tray.count)
                XCTAssertTrue(Set(lesson.cards).isSubset(of:Set(lesson.tray)))
                XCTAssertNotEqual(lesson.tray.filter(lesson.cards.contains),lesson.cards)
                for card in lesson.cards { book.pick(card);book.pick(card) }
            case .change:
                XCTAssertEqual(Set(lesson.revealed).count,lesson.cards.count)
                XCTAssertEqual(zip(lesson.cards,lesson.revealed).filter { $0 != $1 }.count,1)
                book.rounds[lesson.id]?.spot=lesson.changedIndex
            case .pattern:
                XCTAssertEqual(Pattern.classify(lesson.cards),lesson.expected,lesson.title)
                XCTAssertEqual(lesson.options.filter { $0 == lesson.expected }.count,1)
                book.rounds[lesson.id]?.pattern=Pattern.classify(lesson.cards)
            }
            let restored=Workbook.restore(try JSONEncoder().encode(book),legacy:nil)
            XCTAssertEqual(restored,book)
            book.finish();book.finish()
            XCTAssertEqual(book.records[lesson.id]?.attempts,1)
            XCTAssertEqual(book.records[lesson.id]?.needsPractice,false)
        }
        XCTAssertEqual(book.completed,30)
        var old=RecallSession.deal()
        old.completed=4;old.correctPositions=16;old.phase = .recall;old.choose(old.target[0])
        let migrated=Workbook.restore(nil,legacy:try JSONEncoder().encode(old))
        XCTAssertEqual(migrated.active,-1);XCTAssertEqual(migrated.round.phase,.recall)
        XCTAssertEqual(migrated.round.order,[old.target[0]]);XCTAssertEqual(migrated.practice.completed,4)
    }

    @MainActor private func tapSwitch(_ app:XCUIApplication,_ identifier:String) {
        let control=app.switches[identifier].firstMatch
        XCTAssertTrue(control.waitForExistence(timeout:5));control.tap()
    }

    @MainActor func testAllStudiesAndRevisitErrors() throws {
        continueAfterFailure=false
        let app=XCUIApplication()
        app.launchEnvironment["UI_TEST_SUITE"]="test.recall."+UUID().uuidString
        app.launch()
        func shot(_ name:String) {
            let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)
        }
        func tap(_ id:String) {
            let b=app.buttons[id].firstMatch
            XCTAssertTrue(b.exists || b.waitForExistence(timeout:5),id)
            b.tap()
        }
        func answer(_ lesson:Lesson,wrong:Bool=false) {
            switch lesson.mode {
            case .order:
                tap("hide")
                var cards=lesson.cards
                if wrong { cards.swapAt(0,1) }
                for card in cards { tap("pick-\(card.id)") }
            case .change:
                tap("hide")
                tap("change-\((lesson.changedIndex!+(wrong ? 1 : 0)) % lesson.cards.count)")
            case .pattern:
                let p=wrong ? lesson.options.first(where:{ $0 != lesson.expected })! : lesson.expected!
                tap("pattern-\(p.rawValue)")
                XCTAssertTrue(app.buttons["pattern-\(p.rawValue)"].isSelected)
            }
            XCTAssertTrue(app.buttons["check"].isEnabled,lesson.title)
            tap("check")
            let score=app.staticTexts["score"]
            XCTAssertTrue(score.exists || score.waitForExistence(timeout:5))
        }
        XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout:10))
        shot("01-Print-studio")
        tap("mode-0");shot("02-Sequence-contents");tap("lesson-0")
        shot("03-Sequence-hand")
        answer(Lesson.course[0],wrong:true)
        XCTAssertEqual(app.staticTexts["score"].label,"3 of 5 positions correct")
        app.terminate();app.launch()
        XCTAssertTrue(app.staticTexts["score"].waitForExistence(timeout:8))
        tap("studio");tap("errors");tap("lesson-0");tap("retry")
        for mode in RecallMode.allCases {
            for task in Lesson.course.filter({ $0.mode == mode }) {
                XCTAssertTrue(app.staticTexts[task.title].firstMatch.waitForExistence(timeout:6),task.title)
                if task.id==1 {
                    answer(task,wrong:true)
                    XCTAssertEqual(app.staticTexts["score"].label,"Try this one again")
                    shot("04-Change-comparison");tap("retry")
                }
                if task.id==2 {
                    shot("05-Pattern-hand");tap("Pattern guide");tap("Close")
                    answer(task,wrong:true);tap("retry")
                }
                if task.id==6 { shot("06-Court-cards") }
                answer(task)
                XCTAssertEqual(app.staticTexts["score"].label,mode == .order ? "5 of 5 positions correct" : "Correct")
                tap("next")
            }
        }
        XCTAssertTrue(app.buttons["practice"].waitForExistence(timeout:6))
        XCTAssertFalse(app.buttons["errors"].isEnabled)
        shot("07-Complete-studio")
        tap("deck");tapSwitch(app,"monochrome")
        XCTAssertEqual(app.switches["monochrome"].firstMatch.value as? String,"1")
        for suit in PlayingCard.suits { XCTAssertTrue(app.staticTexts[suit].exists) }
        shot("08-Monochrome-deck");tap("Close deck")
        app.terminate();app.launch();tap("deck")
        XCTAssertEqual(app.switches["monochrome"].firstMatch.value as? String,"1")
        tap("Close deck")
        tap("practice")
        XCTAssertTrue(app.buttons["hide"].waitForExistence(timeout:5))
        XCUIDevice.shared.orientation = .landscapeLeft
        let settled=expectation(for:NSPredicate { _,_ in
            let bounds=app.windows.firstMatch.frame
            return bounds.width > bounds.height
        }, evaluatedWith:app)
        wait(for:[settled], timeout:8)
        // An accessibility query may finish before UIKit finishes its rotation animation.
        RunLoop.current.run(until:Date(timeIntervalSinceNow:0.9))
        let landscape=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        landscape.name="09-Landscape-practice";landscape.lifetime = .keepAlways;add(landscape)
        XCUIDevice.shared.orientation = .portrait
    }
}

final class StudioLayout: XCTestCase {
    @MainActor func testLandscapeDeck() {
        continueAfterFailure=false
        let device=XCUIDevice.shared
        device.orientation = .landscapeLeft
        defer { device.orientation = .portrait }
        let app=XCUIApplication()
        app.launchEnvironment["UI_TEST_SUITE"]="test.wide."+UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["mode-2"].waitForExistence(timeout:8))
        app.buttons["mode-2"].tap();app.buttons["lesson-2"].tap()
        XCTAssertTrue(app.staticTexts["Two alike"].exists)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width,app.windows.firstMatch.frame.height)
        let screen=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        screen.name="Landscape-hand";screen.lifetime = .keepAlways;add(screen)
        XCTAssertTrue(app.buttons["pattern-One pair"].isHittable)
        app.buttons["pattern-One pair"].tap()
        XCTAssertTrue(app.buttons["check"].isEnabled)
        app.buttons["check"].tap()
        XCTAssertEqual(app.staticTexts["score"].label,"Correct")
        app.buttons["studio"].tap()
        app.buttons["mode-0"].tap();app.buttons["lesson-0"].tap()
        app.buttons["hide"].tap()
        for card in Lesson.course[0].cards {
            let pick=app.buttons["pick-\(card.id)"]
            XCTAssertTrue(pick.isHittable)
            pick.tap()
        }
        XCTAssertTrue(app.buttons["check"].isHittable)
        app.buttons["check"].tap()
        XCTAssertEqual(app.staticTexts["score"].label,"5 of 5 positions correct")
        app.buttons["studio"].tap()
        app.buttons["mode-1"].tap();app.buttons["lesson-1"].tap()
        app.buttons["hide"].tap()
        let position=app.buttons["change-1"]
        XCTAssertTrue(position.waitForExistence(timeout:4))
        XCTAssertTrue(position.isHittable)
        position.tap();app.buttons["check"].tap()
        XCTAssertEqual(app.staticTexts["score"].label,"Correct")
    }
}

final class LocalizedRecall: XCTestCase {
    @MainActor func testReadingOrderVoiceOverAndReview() {
        continueAfterFailure = false
        let app = XCUIApplication()
        for (lang, region, title, firstCard, score, rtl) in [
            ("ar", "ar_SA", "الانطباع الأول", "آس البستوني", "مواضع صحيحة", true),
            ("zh-Hant", "zh_TW", "第一印象", "黑桃A", "個位置中答對", false)
        ] {
            app.launchArguments = ["-AppleLanguages", "(\(lang))", "-AppleLocale", region]
            app.launchEnvironment["UI_TEST_SUITE"] = "test.locale.recall." + UUID().uuidString
            app.launch()
            XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 8))
            app.buttons["continue"].tap()
            XCTAssertTrue(app.staticTexts[title].exists)
            XCTAssertEqual(app.buttons["studio"].frame.midX > app.buttons["studies"].frame.midX, rtl)
            let first = app.descendants(matching:.any)["slot-0"].firstMatch
            let second = app.descendants(matching:.any)["slot-1"].firstMatch
            // Foundation isolates substituted card names for bidirectional speech.
            let spoken = first.label.components(separatedBy: CharacterSet(charactersIn: "\u{2066}\u{2067}\u{2068}\u{2069}")).joined()
            XCTAssertEqual(spoken, firstCard)
            XCTAssertEqual(first.frame.midX > second.frame.midX, rtl)
            app.buttons["hide"].tap()
            for card in Lesson.course[0].cards { app.buttons["pick-\(card.id)"].tap() }
            XCTAssertEqual(first.frame.midX > second.frame.midX, rtl)
            app.buttons["check"].tap()
            XCTAssertTrue(app.staticTexts["score"].label.contains(score))
            app.buttons["studio"].tap()
            app.buttons["mode-2"].tap()
            app.buttons["lesson-2"].tap()
            let correct = app.buttons["pattern-One pair"]
            XCTAssertTrue(correct.label.contains(rtl ? "زوج واحد" : "一對"))
            correct.tap()
            app.buttons["check"].tap()
            XCTAssertEqual(app.staticTexts["score"].label, rtl ? "إجابة صحيحة" : "答對了")
            app.terminate()
        }
    }
}
