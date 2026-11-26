import SwiftUI

private struct MonochromeKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var monochromeCards: Bool {
        get { self[MonochromeKey.self] }
        set { self[MonochromeKey.self]=newValue }
    }
}

struct CardFace: View {
    @Environment(\.monochromeCards) private var monochrome
    let card: PlayingCard

    private var pips: [CGPoint] {
        let centre = CGPoint(x: 0.5, y: 0.5)
        let upper = CGPoint(x: 0.5, y: 0.23), lower = CGPoint(x: 0.5, y: 0.77)
        let corners = [CGPoint(x: 0.32, y: 0.23), CGPoint(x: 0.68, y: 0.23),
                       CGPoint(x: 0.32, y: 0.77), CGPoint(x: 0.68, y: 0.77)]
        let middle = [CGPoint(x: 0.32, y: 0.5), CGPoint(x: 0.68, y: 0.5)]
        let high = CGPoint(x: 0.5, y: 0.36), low = CGPoint(x: 0.5, y: 0.64)
        let eight = corners + [CGPoint(x: 0.32, y: 0.41), CGPoint(x: 0.68, y: 0.41),
                               CGPoint(x: 0.32, y: 0.59), CGPoint(x: 0.68, y: 0.59)]
        switch card.id % 13 {
        case 1: return [upper, lower]
        case 2: return [upper, centre, lower]
        case 3: return corners
        case 4: return corners + [centre]
        case 5: return corners + middle
        case 6: return corners + middle + [high]
        case 7: return corners + middle + [high, low]
        case 8: return eight + [centre]
        case 9: return eight + [CGPoint(x: 0.5, y: 0.31), CGPoint(x: 0.5, y: 0.69)]
        default: return [centre]
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width, height = proxy.size.height
            let unit = min(width, height / 1.4)
            let colour = monochrome || card.suit.isMultiple(of: 2) ? ink : redInk
            let isCourt = card.id % 13 >= 10
            let suit = PlayingCard.symbols[card.suit]
            ZStack {
                RoundedRectangle(cornerRadius: unit * 0.09).fill(ivory)
                RoundedRectangle(cornerRadius: unit * 0.045).strokeBorder(colour.opacity(0.30))
                    .padding(unit * 0.065)
                if isCourt {
                    Image(["JackPrint","QueenPrint","KingPrint"][card.id % 13 - 10])
                        .resizable().scaledToFill().grayscale(monochrome ? 1 : 0)
                        .frame(width:width*0.54,height:height*0.64).clipped()
                    Text(verbatim:suit).font(.system(size:unit*0.19,weight:.bold,design:.serif))
                        .position(x:width*0.18,y:height*0.33)
                    Text(verbatim:suit).font(.system(size:unit*0.19,weight:.bold,design:.serif))
                        .rotationEffect(.degrees(180)).position(x:width*0.82,y:height*0.67)
                } else {
                    ForEach(Array(pips.enumerated()), id: \.offset) { _, point in
                        Text(verbatim:suit)
                            .font(.system(size:unit*(pips.count == 1 ? 0.60 : 0.225),design:.serif))
                            .rotationEffect(.degrees(point.y > 0.5 ? 180 : 0))
                            .position(x:width*point.x,y:height*point.y)
                    }
                }
                ForEach([false, true], id: \.self) { reverse in
                    Text(verbatim: card.rank).font(.system(size: unit * 0.23, weight: .bold, design: .serif))
                        .rotationEffect(.degrees(reverse ? 180 : 0))
                        .position(x: width * (reverse ? 0.81 : 0.19), y: height * (reverse ? 0.86 : 0.14))
                }
            }.foregroundStyle(colour)
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore).accessibilityLabel(card.spokenName)
    }
}

