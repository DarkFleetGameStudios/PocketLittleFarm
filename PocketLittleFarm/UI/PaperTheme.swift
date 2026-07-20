import SwiftUI
import UIKit

/// KISS paper diorama palette — high contrast, stage lights up.
enum PaperTheme {
    // Desk / world
    static let desk = Color(red: 0.72, green: 0.80, blue: 0.66)       // blotter green
    static let stage = Color(red: 0.98, green: 0.95, blue: 0.88)      // scrapbook cream
    static let stageEdge = Color(red: 0.72, green: 0.62, blue: 0.48)
    static let ink = Color(red: 0.18, green: 0.14, blue: 0.10)        // near-black brown
    static let inkMuted = Color(red: 0.32, green: 0.26, blue: 0.20)   // readable secondary
    static let kraft = Color(red: 0.72, green: 0.55, blue: 0.36)
    static let accent = Color(red: 0.18, green: 0.45, blue: 0.72)     // clear blue
    static let ripe = Color(red: 0.78, green: 0.42, blue: 0.12)
    static let warn = Color(red: 0.85, green: 0.45, blue: 0.10)
    static let danger = Color(red: 0.72, green: 0.22, blue: 0.18)
    static let good = Color(red: 0.22, green: 0.48, blue: 0.28)

    // UIKit counterparts for SpriteKit
    enum UI {
        static let desk = UIColor(red: 0.72, green: 0.80, blue: 0.66, alpha: 1)
        static let stage = UIColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 1)
        static let stageEdge = UIColor(red: 0.62, green: 0.52, blue: 0.38, alpha: 1)
        static let ink = UIColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 1)
        static let inkMuted = UIColor(red: 0.32, green: 0.26, blue: 0.20, alpha: 1)
        static let kraftEmpty = UIColor(red: 0.78, green: 0.62, blue: 0.42, alpha: 1)
        static let kraftGrowing = UIColor(red: 0.62, green: 0.48, blue: 0.32, alpha: 1)
        static let kraftThirsty = UIColor(red: 0.88, green: 0.72, blue: 0.42, alpha: 1)
        static let kraftWilted = UIColor(red: 0.58, green: 0.52, blue: 0.40, alpha: 1)
        static let kraftRipe = UIColor(red: 0.55, green: 0.72, blue: 0.42, alpha: 1)
        static let kraftLost = UIColor(red: 0.48, green: 0.44, blue: 0.40, alpha: 1)
        static let house = UIColor(red: 0.99, green: 0.96, blue: 0.90, alpha: 1)
        static let pen = UIColor(red: 0.94, green: 0.88, blue: 0.74, alpha: 1)
        static let shadow = UIColor(red: 0.25, green: 0.20, blue: 0.12, alpha: 0.22)
        static let chipFill = UIColor(red: 1, green: 1, blue: 1, alpha: 0.92)
        static let chipRipe = UIColor(red: 0.95, green: 0.78, blue: 0.25, alpha: 1)
        static let chipThirst = UIColor(red: 0.35, green: 0.62, blue: 0.95, alpha: 1)
        static let chipWilt = UIColor(red: 0.90, green: 0.55, blue: 0.20, alpha: 1)
        static let chipLost = UIColor(red: 0.75, green: 0.30, blue: 0.28, alpha: 1)
    }
}

// Solid paper card chrome for SwiftUI
struct PaperCardBackground: ViewModifier {
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PaperTheme.stage)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(PaperTheme.stageEdge.opacity(0.45), lineWidth: 1.5)
            )
    }
}

extension View {
    func paperCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(PaperCardBackground(cornerRadius: cornerRadius))
    }
}
