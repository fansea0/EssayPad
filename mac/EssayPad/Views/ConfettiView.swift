import SwiftUI

struct ConfettiView: View {
    let origin: CGPoint
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        let startX, startY: CGFloat
        let endX, endY: CGFloat
        let rotation: Double
        let color: Color
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(p.color)
                    .rotationEffect(.degrees(p.rotation))
                    .position(x: p.endX, y: p.endY)
                    .opacity(0.85)
            }
        }
        .allowsHitTesting(false)
        .onAppear { spawn() }
    }

    private func spawn() {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .pink, .purple]
        var seed: [Particle] = []
        for _ in 0..<16 {
            let angle = Double.random(in: 0..<2 * .pi)
            let speed = CGFloat.random(in: 90...160)
            let vx = CGFloat(Darwin.cos(angle) * Double(speed))
            let vy = CGFloat(Darwin.sin(angle) * Double(speed)) - 40
            let endX = origin.x + vx
            let endY = origin.y + vy + 70
            let rotation = Double.random(in: 360...720)
            let color = colors.randomElement() ?? .yellow
            seed.append(Particle(
                startX: origin.x, startY: origin.y,
                endX: endX, endY: endY,
                rotation: rotation, color: color
            ))
        }
        particles = seed
    }
}