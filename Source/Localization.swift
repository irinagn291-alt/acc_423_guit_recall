import Foundation

/// Resolve authored content and format whole sentences in the app's selected language.
func tr(_ key: String, _ arguments: String...) -> String {
    let format = Bundle.main.localizedString(forKey: key, value: key, table: nil)
    guard !arguments.isEmpty else { return format }
    return String(format: format, locale: interfaceLocale, arguments: arguments)
}

let interfaceLocale: Locale = {
    let language = Bundle.main.preferredLocalizations.first ?? "en-GB"
    if language == "ar" { return Locale(identifier: "ar-SA") }
    return Locale(identifier: language)
}()

func numeral(_ value: Int, padded: Bool = false) -> String {
    let format = IntegerFormatStyle<Int>.number.locale(interfaceLocale).grouping(.never)
    return value.formatted(padded ? format.precision(.integerLength(2...)) : format)
}

extension PlayingCard {
    var spokenName: String {
        tr("%1$@ of %2$@", tr(Self.names[id % 13]), tr(Self.suits[suit]))
    }
}
