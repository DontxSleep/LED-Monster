import SwiftUI

struct ColourWheel: View {
    @Binding var red: Double
    @Binding var green: Double
    @Binding var blue: Double
    var onCommit: () -> Void
    private var maximum: Double { max(red, green, blue) }
    private var minimum: Double { min(red, green, blue) }
    private var saturation: Double { maximum == 0 ? 0 : (maximum - minimum) / maximum }
    private var hue: Double {
        let delta = maximum - minimum
        guard delta > 0 else { return 0 }
        var h: Double
        if maximum == red { h = (green - blue) / delta }
        else if maximum == green { h = (blue - red) / delta + 2 }
        else { h = (red - green) / delta + 4 }
        return (h / 6 + 1).truncatingRemainder(dividingBy: 1)
    }
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let radius = size / 2 - 14
            ZStack {
                Circle().fill(AngularGradient(colors: (0...6).map { Color(hue: Double($0) / 6, saturation: 1, brightness: 1) }, center: .center))
                Circle().fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: radius))
                Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1)
                Circle().fill(Color(red: red, green: green, blue: blue))
                    .frame(width: 23, height: 23)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .offset(x: cos(hue * 2 * .pi) * saturation * radius,
                            y: sin(hue * 2 * .pi) * saturation * radius)
                    .allowsHitTesting(false)
            }
            .frame(width: radius * 2, height: radius * 2)
            .position(x: size / 2, y: size / 2)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("colour-wheel"))
                .onChanged { value in update(at: value.location, centre: size / 2, radius: radius) }
                .onEnded { _ in onCommit() })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Colour wheel")
            .accessibilityValue("Hue \(Int(hue * 360)) degrees, saturation \(Int(saturation * 100)) percent")
            .accessibilityHint("Use arrow adjustments to change hue. RGB sliders are also available under Fine tune.")
            .accessibilityAdjustableAction { direction in
                let offset = direction == .increment ? 1.0 / 36 : -1.0 / 36
                set(hue: (hue + offset + 1).truncatingRemainder(dividingBy: 1), saturation: max(0.1, saturation))
                onCommit()
            }
        }.coordinateSpace(name: "colour-wheel").aspectRatio(1, contentMode: .fit)
    }
    private func update(at point: CGPoint, centre: Double, radius: Double) {
        let x = point.x - centre, y = point.y - centre
        var angle = atan2(y, x) / (2 * .pi)
        if angle < 0 { angle += 1 }
        set(hue: angle, saturation: min(1, hypot(x, y) / radius))
    }
    private func set(hue: Double, saturation: Double) {
        let sector = hue * 6
        let fraction = sector - floor(sector)
        let p = 1 - saturation
        let q = 1 - fraction * saturation
        let t = 1 - (1 - fraction) * saturation
        switch Int(floor(sector)) % 6 {
        case 0: (red, green, blue) = (1, t, p)
        case 1: (red, green, blue) = (q, 1, p)
        case 2: (red, green, blue) = (p, 1, t)
        case 3: (red, green, blue) = (p, q, 1)
        case 4: (red, green, blue) = (t, p, 1)
        default: (red, green, blue) = (1, p, q)
        }
    }
}
