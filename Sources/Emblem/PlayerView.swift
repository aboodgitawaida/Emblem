import SwiftUI

/// The menu bar player, modelled on macOS's own Now Playing module.
/// For a brand's artist (Drake, Kanye…) it keeps the exact layout and swaps in that brand's logo and
/// colours taken from the playing album's art (the brand's own palette until the art arrives);
/// when such a track starts, a shimmer sweeps across once and the cover's glow swells.
struct PlayerView: View {
    @ObservedObject var model: NowPlayingModel
    @Environment(\.colorScheme) private var systemScheme
    @State private var shimmer: CGFloat = -1     // band position, -1 (off left) … 1.4 (off right)
    @State private var swell = false             // cover glow brightens during the shimmer

    init(model: NowPlayingModel, previewShimmer: CGFloat? = nil) {   // previewShimmer: DebugRender only
        self.model = model
        if let p = previewShimmer { _shimmer = State(initialValue: p); _swell = State(initialValue: true) }
    }

    static let width: CGFloat = 308

    var body: some View {
        let theme = Theme(brand: model.brand, palette: model.palette)
        Group {
            if let info = model.current {
                FullPlayer(info: info, theme: theme, model: model, glow: theme.branded ? (swell ? 0.7 : 0.38) : 0)
            } else { NotPlaying(theme: theme) }
        }
        .frame(width: Self.width)
        .background { PanelBackground(theme: theme) }
        .overlay { ShimmerBand(position: shimmer, palette: model.palette ?? Brand.ovo.palette).allowsHitTesting(false) }
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous))
        .environment(\.colorScheme, theme.branded ? .dark : systemScheme)
        // Springs, like Apple's own motion: switching looks settles with a little give.
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: model.brand?.id)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: model.palette?.accent)
        .onChange(of: model.brand?.id) { _, id in if id != nil { celebrate() } }
        .onChange(of: model.current?.trackID) { _, _ in if model.brand != nil { celebrate() } }
    }

    /// Runs alongside the menu bar logo tracing in (~0.75s).
    private func celebrate() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { shimmer = -1 }
        withAnimation(.easeInOut(duration: 1.15).delay(0.1)) { shimmer = 1.4 }
        // The cover's glow blooms with a bounce, then relaxes slowly.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { swell = true }
        withAnimation(.spring(response: 1.1, dampingFraction: 0.9).delay(0.9)) { swell = false }
    }
}

/// A soft diagonal band of the brand's light, swept across the player once.
private struct ShimmerBand: View {
    var position: CGFloat
    var palette: Brand.Palette
    var body: some View {
        GeometryReader { geo in
            let band = geo.size.width * 0.45
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: palette.accent.opacity(0.22), location: 0.35),
                .init(color: palette.highlight.opacity(0.38), location: 0.5),
                .init(color: palette.accent.opacity(0.22), location: 0.65),
                .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: band, height: geo.size.height * 2)
            .rotationEffect(.degrees(18))
            .offset(x: position * (geo.size.width + band) - band / 2, y: -geo.size.height / 2)
            .blendMode(.plusLighter)
            .opacity(position > -1 && position < 1.4 ? 1 : 0)
        }
    }
}

// MARK: - Layouts

/// Laid out on the exact coordinates of the system Now Playing module (measured via Accessibility, macOS 27):
/// 308×140 panel, 112pt artwork inset 14, text column at x=140 (154 wide), 26pt buttons 56pt apart.
private enum Layout {
    static let size = CGSize(width: 308, height: 140)
    static let art = CGRect(x: 14, y: 14, width: 112, height: 112)
    static let column: CGFloat = 140, columnWidth: CGFloat = 154
    static let text = CGRect(x: 140, y: 15, width: 136, height: 31.5)
    static let meter = CGRect(x: 281.5, y: 26, width: 13.5, height: 8.5)
    /// Brand tracks only: the artist's logo, ending at the meter's right edge, centred on the text block.
    static let mark = CGRect(x: 295 - 20, y: 30.75 - 10, width: 20, height: 20)
    static let buttonY: CGFloat = 63.5, button: CGFloat = 26
    static let buttonX: [CGFloat] = [148, 204, 260]
    static let slider = CGRect(x: 140, y: 101, width: 154, height: 12)   // track drawn ~1pt above the AX frame centre
    static let timesY: CGFloat = 113.2, timesHeight: CGFloat = 13

    /// The system player's controls column is 2pt wider (156) whenever the title or the artist line is
    /// too long and scrolls: the bar and times stretch, and the buttons, centred in it, move 1pt right.
    /// Checked on five tracks (two that fit, three that scroll).
    static func columnExtra(for info: NowPlayingInfo) -> CGFloat {
        func width(_ s: String, _ font: NSFont) -> CGFloat { (s as NSString).size(withAttributes: [.font: font]).width }
        let scrolls = width(info.title, .systemFont(ofSize: 13, weight: .semibold)) > text.width
            || width(TitleBlock.subtitle(for: info), .systemFont(ofSize: 11)) > text.width
        return scrolls ? 2 : 0
    }
}

private struct FullPlayer: View {
    let info: NowPlayingInfo
    let theme: Theme
    let model: NowPlayingModel
    var glow: Double = 0
    /// Where the pointer is over the player (0…1), for the foil logo's highlight. nil when it's away.
    @State private var pointer: CGPoint?

    var body: some View {
        let extra = Layout.columnExtra(for: info)
        ZStack(alignment: .topLeading) {
            Color.clear
            Artwork(info: info, theme: theme, size: Layout.art.width, glow: glow)
                .modifier(TiltCard(enabled: theme.branded, size: Layout.art.width))
                .contentShape(Rectangle())
                .onTapGesture { model.openSource() }
                .offset(x: Layout.art.minX, y: Layout.art.minY)

            TitleBlock(info: info, theme: theme)
                // Brand tracks: stop the text 4pt short of the bigger logo.
                .frame(width: theme.branded ? Layout.mark.minX - 4 - Layout.text.minX : Layout.text.width,
                       height: Layout.text.height, alignment: .leading)
                .offset(x: Layout.text.minX, y: Layout.text.minY)

            if let brand = theme.brand, let palette = theme.palette {
                // The artist's logo takes a bigger spot than Apple's audio bars: a 20pt box in the top-right
                // corner, right-aligned with the controls and centred on the title and artist lines.
                FoilMark(logo: brand.logo, palette: palette, weight: brand.markWeight * 1.4, pointer: pointer)
                    .frame(width: Layout.mark.width, height: Layout.mark.height)
                    // Pops in where it sits. (A scale transition here grew it from the panel's corner,
                    // because the offset below moves it away from its layout box.)
                    .modifier(PopIn(id: brand.id))
                    .offset(x: Layout.mark.minX, y: Layout.mark.minY)
                    .transition(.opacity)
            } else {
                LevelMeter(playing: info.isPlaying, color: theme.meter)
                    .frame(width: Layout.meter.width, height: 12.5)
                    .offset(x: Layout.meter.minX, y: Layout.meter.midY - 6.25)
                    .transition(.opacity)
            }

            ControlButton(symbol: info.isWebVideo ? "15.arrow.trianglehead.counterclockwise" : "backward.fill", size: info.isWebVideo ? 19 : 16,
                          theme: theme, label: info.isWebVideo ? nil : "previous") { model.send(info.isWebVideo ? .skipBack15 : .previous) }
                .offset(x: extra / 2 + Layout.buttonX[0], y: Layout.buttonY)
            ControlButton(symbol: info.isPlaying ? "pause.fill" : "play.fill", size: 23.5, theme: theme,
                          label: info.isPlaying ? "pause" : "play") {
                model.send(.togglePlayPause)
            }
            .offset(x: extra / 2 + Layout.buttonX[1], y: Layout.buttonY)
            ControlButton(symbol: info.isWebVideo ? "15.arrow.trianglehead.clockwise" : "forward.fill", size: info.isWebVideo ? 19 : 16,
                          theme: theme, label: info.isWebVideo ? nil : "next") { model.send(info.isWebVideo ? .skipForward15 : .next) }
                .offset(x: extra / 2 + Layout.buttonX[2], y: Layout.buttonY)

            Scrubber(info: info, theme: theme) { model.seek(to: $0) }
                .frame(width: Layout.slider.width + extra)
                .offset(x: Layout.slider.minX, y: Layout.slider.minY)
        }
        .frame(width: Layout.size.width, height: Layout.size.height)
        .onContinuousHover(coordinateSpace: .local) { phase in
            guard theme.branded else { return }
            switch phase {
            case .active(let p):
                pointer = CGPoint(x: p.x / Layout.size.width, y: p.y / Layout.size.height)
            case .ended:
                pointer = nil
            }
        }
    }
}

/// Springs the view in from 60% around its own centre when it appears, and again when `id` changes
/// (switching straight from one artist to another).
private struct PopIn: ViewModifier {
    let id: String
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
            .onAppear { pop() }
            .onChange(of: id) { _, _ in shown = false; pop() }
    }

    private func pop() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62).delay(0.05)) { shown = true }
    }
}

/// For brand tracks, the cover tilts toward the pointer and a soft sheen slides across it,
/// like the posters on Apple TV. It springs back flat when the pointer leaves.
private struct TiltCard: ViewModifier {
    let enabled: Bool
    let size: CGFloat
    @State private var tilt: CGPoint = .zero    // -1…1 on each axis
    @State private var hovering = false
    private let maxDegrees: Double = 9

    func body(content: Content) -> some View {
        if enabled {
            content
                .overlay {
                    // The sheen: a soft diagonal band of light that follows the pointer.
                    let c = 0.5 + tilt.x * 0.45
                    LinearGradient(stops: [
                        .init(color: .white.opacity(0), location: max(0, c - 0.32)),
                        .init(color: .white.opacity(0.2), location: c),
                        .init(color: .white.opacity(0), location: min(1, c + 0.32)),
                    ], startPoint: UnitPoint(x: 0, y: 0.15 - tilt.y * 0.3), endPoint: UnitPoint(x: 1, y: 0.85 + tilt.y * 0.3))
                    .blendMode(.plusLighter)
                    .opacity(hovering ? 1 : 0)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .allowsHitTesting(false)
                }
                .rotation3DEffect(.degrees(-Double(tilt.y) * maxDegrees), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
                .rotation3DEffect(.degrees(Double(tilt.x) * maxDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
                .scaleEffect(hovering ? 1.025 : 1)
                .onContinuousHover(coordinateSpace: .local) { phase in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        switch phase {
                        case .active(let p):
                            hovering = true
                            tilt = CGPoint(x: min(max(p.x / size * 2 - 1, -1), 1), y: min(max(p.y / size * 2 - 1, -1), 1))
                        case .ended:
                            hovering = false
                            tilt = .zero
                        }
                    }
                }
        } else {
            content
        }
    }
}

/// The player's small logo, foil-stamped in the album's colour: a metallic gradient whose highlight
/// follows the pointer across the player, and drifts slowly on its own when the pointer is away.
private struct FoilMark: View {
    let logo: Logo
    let palette: Brand.Palette
    var weight: CGFloat = 0
    var pointer: CGPoint?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: pointer != nil)) { ctx in
            let drift = 0.5 + 0.4 * sin(ctx.date.timeIntervalSinceReferenceDate * 0.55)
            let c = pointer.map { Double($0.x) } ?? drift
            let foil = LinearGradient(stops: [
                .init(color: palette.accent.opacity(0.62), location: 0),
                .init(color: palette.accent, location: max(0, c - 0.3)),
                .init(color: palette.highlight, location: c),
                .init(color: palette.accent, location: min(1, c + 0.3)),
                .init(color: palette.accent.opacity(0.62), location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            LogoShape(logo: logo).fill(foil, style: FillStyle(eoFill: logo.evenOdd))
                .overlay { if weight > 0 { LogoShape(logo: logo).stroke(foil, style: StrokeStyle(lineWidth: weight, lineJoin: .round)) } }
                .shadow(color: palette.accent.opacity(0.35), radius: 2)
        }
    }
}

private struct NotPlaying: View {
    let theme: Theme
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.placeholder)
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: "music.note").font(.system(size: 18)).foregroundStyle(theme.tertiary))
            Text("Not Playing").font(.system(size: 14, weight: .semibold)).foregroundStyle(theme.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Pieces

private struct TitleBlock: View {
    let info: NowPlayingInfo
    let theme: Theme

    var subtitle: String { Self.subtitle(for: info) }

    static func subtitle(for info: NowPlayingInfo) -> String {
        let artist = info.artist.isEmpty ? info.appName : info.artist
        // Like the system player: "Artist – Album", and "Artist – " when the source sends an empty album.
        return info.album.isEmpty && !info.hasAlbum ? artist : "\(artist) – \(info.album)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            MarqueeText(text: info.title, font: .system(size: 13, weight: .semibold), color: theme.primary)
            MarqueeText(text: subtitle, font: .system(size: 11), color: theme.secondary)
        }
    }
}

/// Square artwork fills the 112pt square. Non-square artwork (video thumbnails) is shown whole,
/// letterboxed in the square, with the source app's icon in the bottom-right corner, like the system player.
private struct Artwork: View {
    let info: NowPlayingInfo
    let theme: Theme
    let size: CGFloat
    var glow: Double = 0

    private var aspect: CGFloat? {
        guard let a = info.artwork, a.size.height > 0 else { return nil }
        return a.size.width / a.size.height
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if let art = info.artwork, let aspect, abs(aspect - 1) > 0.05 {
            let w = aspect > 1 ? size : size * aspect
            let h = aspect > 1 ? size / aspect : size
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: art).resizable().interpolation(.high)
                    .frame(width: w, height: h)
                    .clipShape(shape)
                    .overlay { if theme.branded { shape.strokeBorder(theme.accent.opacity(0.35), lineWidth: 0.5) } }
                    .shadow(color: theme.accent.opacity(glow), radius: 11)
                    .frame(width: size, height: size)
                if let icon = info.appIcon {
                    // 19pt frame (icon art ~16pt) overhanging the square's corner by 3pt, as measured.
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 19, height: 19)
                        .offset(x: 3, y: 3)
                }
            }
            .frame(width: size, height: size)
        } else {
            ZStack {
                shape.fill(theme.placeholder)
                if let art = info.artwork {
                    Image(nsImage: art).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                } else if let brand = theme.brand {
                    LogoMark(logo: brand.logo, color: theme.accent.opacity(0.7)).padding(size * 0.24)
                } else {
                    Image(systemName: "music.note").font(.system(size: size * 0.36)).foregroundStyle(theme.tertiary)
                }
            }
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay { if theme.branded { shape.strokeBorder(theme.accent.opacity(0.35), lineWidth: 0.5) } }
            .shadow(color: theme.accent.opacity(glow), radius: 11)
        }
    }
}

/// Progress bar like the system one: thin and knob-less at rest; on hover it gains a knob and can be dragged.
private struct Scrubber: View {
    let info: NowPlayingInfo
    let theme: Theme
    let onSeek: (TimeInterval) -> Void
    @State private var scrub: Double?
    @State private var hover = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let canSeek = info.duration > 0
            let live = canSeek ? info.elapsed(at: ctx.date) / info.duration : 0
            let fraction = min(max(scrub ?? live, 0), 1)
            let elapsed = scrub.map { $0 * info.duration } ?? info.elapsed(at: ctx.date)
            let showKnob = canSeek && (hover || scrub != nil)
            VStack(spacing: Layout.timesY - Layout.slider.maxY) {
                GeometryReader { geo in
                    let w = geo.size.width
                    // The system thumb is a soft capsule, ~15.5×11.5pt (measured from screenshots).
                    let knob: CGFloat = 15.5, knobHeight: CGFloat = 11.5
                    let centre = Self.knobCentre(fraction, width: w)
                    let fill = Self.fillEnd(fraction, width: w)
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.track).frame(height: 4)
                        Capsule().fill(theme.progress).frame(width: fill, height: 4).opacity(fill > 0 ? 1 : 0)
                        Capsule()
                            .fill(theme.knob)
                            .frame(width: knob, height: knobHeight)
                            .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                            .opacity(showKnob ? 1 : 0)   // the system knob fades in place; it doesn't grow
                            .offset(x: centre - knob / 2)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle().inset(by: -6))   // easier to grab than the thin bar
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { g in if canSeek { scrub = min(max(g.location.x / w, 0), 1) } }
                        .onEnded { g in
                            guard canSeek else { return }
                            onSeek(min(max(g.location.x / w, 0), 1) * info.duration)
                            scrub = nil
                        })
                    .onHover { hover = $0 }
                    .animation(.easeInOut(duration: 0.2), value: showKnob)
                    // For VoiceOver it's a slider in seconds, like the system bar.
                    .accessibilityRepresentation {
                        Slider(value: Binding(get: { elapsed }, set: { if canSeek { onSeek($0) } }),
                               in: 0...max(info.duration, 1))
                    }
                }
                .frame(height: Layout.slider.height)
                HStack {
                    Text(Self.format(elapsed))
                    Spacer()
                    Text(canSeek ? "\u{2212}" + Self.format(info.duration - elapsed) : "")
                }
                .frame(height: Layout.timesHeight)
                .font(.system(size: 10, weight: .regular).monospacedDigit())
                .foregroundStyle(theme.tertiary)
            }
        }
    }

    /// Measured on the system bar (154pt wide, at 2×, across a whole song): the knob's centre travels
    /// from 8pt to width − 8pt, so progress is mapped onto that path, not onto the whole bar.
    static let knobInset: CGFloat = 8

    static func knobCentre(_ fraction: Double, width: CGFloat) -> CGFloat {
        knobInset + CGFloat(fraction) * (width - 2 * knobInset)
    }

    /// Where the played part of the bar ends. It follows the knob's centre, except right at the start:
    /// at 0 there's no fill, and over the first ~2% it grows at 3.64× the bar's width per unit of
    /// progress until it meets the knob's centre (system bar: 2.5, 5, 7, 9.5pt at 1–4s of a 3:46 song).
    static func fillEnd(_ fraction: Double, width: CGFloat) -> CGFloat {
        guard fraction > 0 else { return 0 }
        return min(knobCentre(fraction, width: width), CGFloat(fraction) * width * 3.64)
    }

    static func format(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        return s >= 3600 ? String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                         : String(format: "%02d:%02d", s / 60, s % 60)
    }
}

/// Single-line text that, when too long, scrolls sideways in a loop after a pause (like the system player).
/// Single-line text that scrolls when too long, timed like the system Now Playing module
/// (measured via Accessibility): rests 3s, scrolls at 30pt/s until a repeated copy (21pt behind)
/// lines up, jumps back invisibly, and rests again. The timer starts when the player opens.
/// The left edge only fades while the text is moving, so the first letter is crisp at rest.
private struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    @State private var textWidth: CGFloat = 0
    @State private var boxWidth: CGFloat = 0
    @State private var start = Date()

    private let gap: CGFloat = 21
    private let speed: CGFloat = 30     // points per second
    private let pause: Double = 3.0     // seconds at rest before each scroll
    private let fade: CGFloat = 10      // edge fade width, points

    var body: some View {
        let label = Text(text).font(font).foregroundStyle(color).lineLimit(1).fixedSize()
        let overflow = textWidth > boxWidth + 0.5 && boxWidth > 0
        Text(text).font(font).lineLimit(1)
            .opacity(0)   // sizes the row's height without forcing its width
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GeometryReader { g in Color.clear.onAppear { boxWidth = g.size.width }
                .onChange(of: g.size.width) { _, w in boxWidth = w } })
            .overlay(alignment: .leading) {
                TimelineView(.animation(paused: !overflow)) { ctx in
                    let x = offset(at: ctx.date, overflow: overflow)
                    HStack(spacing: gap) {
                        label.background(GeometryReader { g in Color.clear.onAppear { textWidth = g.size.width }
                            .onChange(of: g.size.width) { _, w in textWidth = w } })
                        if overflow { label }
                    }
                    .offset(x: x)
                    .frame(width: boxWidth, alignment: .leading)
                    .clipped()
                    .mask { edgeMask(moving: x < 0, overflow: overflow) }
                }
            }
            .onChange(of: text) { _, _ in start = Date() }
    }

    private func offset(at date: Date, overflow: Bool) -> CGFloat {
        guard overflow else { return 0 }
        let travel = textWidth + gap
        let cycle = pause + Double(travel / speed)
        let t = date.timeIntervalSince(start).truncatingRemainder(dividingBy: cycle)
        return t > pause ? -CGFloat(t - pause) * speed : 0
    }

    @ViewBuilder private func edgeMask(moving: Bool, overflow: Bool) -> some View {
        if overflow && boxWidth > 0 {
            let f = fade / boxWidth
            LinearGradient(stops: [
                .init(color: moving ? .clear : .black, location: 0),
                .init(color: .black, location: f),
                .init(color: .black, location: 1 - f),
                .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
        } else {
            Color.black
        }
    }
}

/// The little live-audio bars shown top-right of the system player.
private struct LevelMeter: View {
    let playing: Bool
    let color: Color
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: !playing)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 1.5) {
                ForEach(0..<5, id: \.self) { i in
                    let phase = sin(t * (4.6 + Double(i) * 1.3) + Double(i) * 1.9)
                    let h = playing ? 4 + 7 * (0.5 + 0.5 * phase) : 1.5   // paused: a row of dots
                    Capsule().fill(color).frame(width: 1.5, height: h)
                }
            }
            .frame(height: 11)
        }
    }
}

private struct ControlButton: View {
    let symbol: String
    let size: CGFloat
    let theme: Theme
    /// The system player's VoiceOver name ("previous", "pause", "play", "next"); nil keeps the symbol's.
    var label: String? = nil
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(theme.control)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressStyle())
        .brightness(hover ? (theme.branded ? 0.12 : 0.08) : 0)
        .onHover { hover = $0 }
        .accessibilityLabel(label.map { Text($0) } ?? Text(Image(systemName: symbol)))
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct PanelBackground: View {
    let theme: Theme
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous)
        ZStack {
            if let p = theme.palette {
                if #available(macOS 26.0, *) {
                    // Real glass tinted with the album's colour, so the panel catches light at its edges like
                    // native macOS panels; the album's colours flow inside it, slightly see-through.
                    Color.clear.glassEffect(.regular.tint(p.accent.opacity(0.22)), in: shape)
                    if p.mesh.count >= 4 {
                        LivingBackground(colors: p.mesh).opacity(0.86).clipShape(shape)
                    } else {
                        shape.fill(p.background.opacity(0.86))
                    }
                } else {
                    shape.fill(p.background)
                    if #available(macOS 15.0, *), p.mesh.count >= 4 {
                        LivingBackground(colors: p.mesh).clipShape(shape)
                    }
                }
                // A faint glow from the top corner, like light catching a black OVO box.
                shape.fill(RadialGradient(colors: [p.ambient, .clear],
                                          center: .topLeading, startRadius: 0, endRadius: 260))
                shape.strokeBorder(p.accent.opacity(0.28), lineWidth: 0.5)
            } else if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.regular, in: shape)
            } else {
                shape.fill(.regularMaterial)
            }
        }
    }
}

/// The album's colours flowing slowly behind the player, like Apple Music's full-screen player:
/// a 3×3 mesh gradient whose inner points drift on slow, out-of-step cycles (~12–20s), under a dark
/// scrim so the white title and the accent-coloured controls stay readable.
@available(macOS 15.0, *)
private struct LivingBackground: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let c = colors
            MeshGradient(
                width: 3, height: 3,
                points: Self.points(at: t),
                colors: [c[0], c[1], c[2],
                         c[3], c[0], c[1],
                         c[2], c[3], c[0]],
                smoothsColors: true)
        }
        .overlay(Color.black.opacity(0.46))
        // A little extra shade behind the text column.
        .overlay(LinearGradient(colors: [.clear, .black.opacity(0.14)], startPoint: .leading, endPoint: .trailing))
    }

    /// Corners stay put; edge midpoints slide along their edges and the centre wanders.
    static func points(at t: TimeInterval) -> [SIMD2<Float>] {
        func s(_ speed: Double, _ phase: Double) -> Float { Float(sin(t * speed + phase)) }
        return [
            [0, 0], [0.5 + 0.2 * s(0.41, 0), 0], [1, 0],
            [0, 0.5 + 0.22 * s(0.33, 1.7)], [0.5 + 0.22 * s(0.29, 0.6), 0.5 + 0.2 * s(0.37, 2.4)], [1, 0.5 + 0.22 * s(0.45, 4.1)],
            [0, 1], [0.5 + 0.2 * s(0.38, 3.3), 1], [1, 1],
        ]
    }
}

// MARK: - Theme

struct Theme {
    let brand: Brand?
    let palette: Brand.Palette?
    var branded: Bool { brand != nil }
    private var p: Brand.Palette? { palette }
    var accent: Color { p?.accent ?? .accentColor }
    var primary: Color { branded ? .white : .primary }
    var secondary: Color { p?.accent ?? .secondary }
    var tertiary: Color { p.map { $0.accent.opacity(0.7) } ?? Color.secondary.opacity(0.75) }
    var control: Color { p?.accent ?? Color.primary.opacity(0.42) }
    var track: Color { branded ? Color.white.opacity(0.12) : Color.primary.opacity(0.14) }
    var progress: Color { p?.accent ?? .accentColor }
    var knob: Color { p?.knob ?? .white }
    var meter: Color { p.map { $0.accent.opacity(0.55) } ?? Color.primary.opacity(0.3) }
    var placeholder: Color { branded ? Color(white: 0.1) : Color.primary.opacity(0.08) }
}

enum PanelMetrics { static let cornerRadius: CGFloat = 16 }
