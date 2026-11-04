import SwiftUI

/// Minimal SVG path-data parser (M L H V C S Q T Z, absolute and relative).
/// Enough for the OVO owl; arcs are not supported.
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var path = Path()
        var scanner = Tokenizer(d)
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint? = nil   // for S/s and T/t reflection
        var command: Character = "M"

        while let token = scanner.next() {
            switch token {
            case .command(let c): command = c
            case .number: scanner.pushBack(token)
            }
            let rel = command.isLowercase
            func pt() -> CGPoint? {
                guard let x = scanner.number(), let y = scanner.number() else { return nil }
                let o = rel ? current : .zero
                return CGPoint(x: o.x + x, y: o.y + y)
            }

            repeat {
                switch command.uppercased().first! {
                case "M":
                    guard let p = pt() else { break }
                    path.move(to: p); current = p; start = p; lastControl = nil
                    command = rel ? "l" : "L"   // subsequent pairs are line-tos
                case "L":
                    guard let p = pt() else { break }
                    path.addLine(to: p); current = p; lastControl = nil
                case "H":
                    guard let x = scanner.number() else { break }
                    current = CGPoint(x: (rel ? current.x : 0) + x, y: current.y)
                    path.addLine(to: current); lastControl = nil
                case "V":
                    guard let y = scanner.number() else { break }
                    current = CGPoint(x: current.x, y: (rel ? current.y : 0) + y)
                    path.addLine(to: current); lastControl = nil
                case "C":
                    let b = current
                    guard let x1 = scanner.number(), let y1 = scanner.number(),
                          let x2 = scanner.number(), let y2 = scanner.number(),
                          let x = scanner.number(), let y = scanner.number() else { break }
                    let o = rel ? b : .zero
                    let c1 = CGPoint(x: o.x + x1, y: o.y + y1)
                    let c2 = CGPoint(x: o.x + x2, y: o.y + y2)
                    let p = CGPoint(x: o.x + x, y: o.y + y)
                    path.addCurve(to: p, control1: c1, control2: c2)
                    current = p; lastControl = c2
                case "S":
                    let b = current
                    guard let x2 = scanner.number(), let y2 = scanner.number(),
                          let x = scanner.number(), let y = scanner.number() else { break }
                    let o = rel ? b : .zero
                    let c1 = lastControl.map { CGPoint(x: 2 * b.x - $0.x, y: 2 * b.y - $0.y) } ?? b
                    let c2 = CGPoint(x: o.x + x2, y: o.y + y2)
                    let p = CGPoint(x: o.x + x, y: o.y + y)
                    path.addCurve(to: p, control1: c1, control2: c2)
                    current = p; lastControl = c2
                case "Q":
                    let b = current
                    guard let x1 = scanner.number(), let y1 = scanner.number(),
                          let x = scanner.number(), let y = scanner.number() else { break }
                    let o = rel ? b : .zero
                    let c = CGPoint(x: o.x + x1, y: o.y + y1)
                    let p = CGPoint(x: o.x + x, y: o.y + y)
                    path.addQuadCurve(to: p, control: c)
                    current = p; lastControl = c
                case "T":
                    let b = current
                    guard let x = scanner.number(), let y = scanner.number() else { break }
                    let o = rel ? b : .zero
                    let c = lastControl.map { CGPoint(x: 2 * b.x - $0.x, y: 2 * b.y - $0.y) } ?? b
                    let p = CGPoint(x: o.x + x, y: o.y + y)
                    path.addQuadCurve(to: p, control: c)
                    current = p; lastControl = c
                case "Z":
                    path.closeSubpath(); current = start; lastControl = nil
                default:
                    // Unsupported command: skip its numbers.
                    while scanner.number() != nil {}
                }
            } while command.uppercased() != "Z" && scanner.peekIsNumber()
        }
        return path
    }

    private enum Token { case command(Character), number(Double) }

    private struct Tokenizer {
        let chars: [Character]
        var i = 0
        var pushed: Token? = nil
        init(_ s: String) { chars = Array(s) }

        mutating func skipSeparators() {
            while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i].isNewline || chars[i] == "\t" { i += 1 }
        }
        mutating func pushBack(_ t: Token) { pushed = t }

        mutating func peekIsNumber() -> Bool {
            if case .number = pushed { return true }
            skipSeparators()
            guard i < chars.count else { return false }
            let c = chars[i]
            return c.isNumber || c == "-" || c == "+" || c == "."
        }

        mutating func next() -> Token? {
            if let p = pushed { pushed = nil; return p }
            skipSeparators()
            guard i < chars.count else { return nil }
            let c = chars[i]
            if c.isLetter && c != "e" && c != "E" { i += 1; return .command(c) }
            return readNumber().map { .number($0) }
        }

        mutating func number() -> Double? {
            if let p = pushed {
                if case .number(let n) = p { pushed = nil; return n }
                return nil
            }
            guard peekIsNumber() else { return nil }
            return readNumber()
        }

        private mutating func readNumber() -> Double? {
            skipSeparators()
            var s = ""
            var seenDot = false, seenExp = false
            if i < chars.count, chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
            while i < chars.count {
                let c = chars[i]
                if c.isNumber { s.append(c); i += 1 }
                else if c == "." && !seenDot && !seenExp { seenDot = true; s.append(c); i += 1 }
                else if (c == "e" || c == "E") && !seenExp {
                    seenExp = true; s.append(c); i += 1
                    if i < chars.count, chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
                } else { break }
            }
            return Double(s)
        }
    }
}
