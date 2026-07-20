import SpriteKit
import UIKit

/// Procedural paper materials — no external art required, still reads as a tapestry.
enum PaperMaterials {

    // MARK: - Cached textures

    private static var cache: [String: SKTexture] = [:]

    static func paper(
        base: UIColor,
        size: CGSize = CGSize(width: 256, height: 256),
        fiber: CGFloat = 0.14,
        freckle: CGFloat = 0.08,
        warm: Bool = true
    ) -> SKTexture {
        let key = "p-\(base.rgbaKey)-f\(fiber)-fr\(freckle)-\(Int(size.width))"
        if let t = cache[key] { return t }
        let img = render(size: size) { ctx, w, h in
            base.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

            // Fibers
            for _ in 0..<Int(180 * fiber * 10) {
                let a = CGFloat.random(in: 0.02...0.07) * fiber * 3
                UIColor(white: warm ? 0.35 : 0.2, alpha: a).setStroke()
                ctx.setLineWidth(CGFloat.random(in: 0.4...1.2))
                let y = CGFloat.random(in: 0...h)
                ctx.move(to: CGPoint(x: 0, y: y + CGFloat.random(in: -2...2)))
                ctx.addLine(to: CGPoint(x: w, y: y + CGFloat.random(in: -3...3)))
                ctx.strokePath()
            }
            // Freckles / pulp
            for _ in 0..<Int(120 * freckle * 10) {
                let r = CGFloat.random(in: 0.4...1.8)
                let rect = CGRect(
                    x: CGFloat.random(in: 0...w),
                    y: CGFloat.random(in: 0...h),
                    width: r, height: r
                )
                UIColor(white: CGFloat.random(in: 0.2...0.5), alpha: CGFloat.random(in: 0.03...0.1)).setFill()
                ctx.fillEllipse(in: rect)
            }
            // Soft vignette edge
            let colors = [
                UIColor.clear.cgColor,
                UIColor(white: 0.2, alpha: 0.06).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.55, 1]) {
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: w / 2, y: h / 2),
                    startRadius: 0,
                    endCenter: CGPoint(x: w / 2, y: h / 2),
                    endRadius: max(w, h) * 0.72,
                    options: []
                )
            }
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        cache[key] = tex
        return tex
    }

    static func washi(hueShift: CGFloat) -> SKTexture {
        let key = "washi-\(hueShift)"
        if let t = cache[key] { return t }
        let base = UIColor(hue: hueShift, saturation: 0.28, brightness: 0.92, alpha: 1)
        let img = render(size: CGSize(width: 128, height: 64)) { ctx, w, h in
            base.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            for i in 0..<12 {
                let y = CGFloat(i) * (h / 12)
                UIColor(white: 1, alpha: 0.12).setStroke()
                ctx.setLineWidth(1)
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: w, y: y + 1))
                ctx.strokePath()
            }
            for _ in 0..<40 {
                UIColor(white: 1, alpha: CGFloat.random(in: 0.05...0.15)).setFill()
                ctx.fillEllipse(in: CGRect(
                    x: CGFloat.random(in: 0...w),
                    y: CGFloat.random(in: 0...h),
                    width: CGFloat.random(in: 1...3),
                    height: CGFloat.random(in: 1...3)
                ))
            }
        }
        let tex = SKTexture(image: img)
        cache[key] = tex
        return tex
    }

    static func cork() -> SKTexture {
        if let t = cache["cork"] { return t }
        let img = render(size: CGSize(width: 256, height: 256)) { ctx, w, h in
            UIColor(red: 0.72, green: 0.58, blue: 0.40, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            for _ in 0..<90 {
                let c = UIColor(
                    red: CGFloat.random(in: 0.55...0.78),
                    green: CGFloat.random(in: 0.42...0.62),
                    blue: CGFloat.random(in: 0.28...0.45),
                    alpha: CGFloat.random(in: 0.25...0.55)
                )
                c.setFill()
                let rw = CGFloat.random(in: 8...28)
                let rh = CGFloat.random(in: 6...22)
                let rect = CGRect(
                    x: CGFloat.random(in: 0...w),
                    y: CGFloat.random(in: 0...h),
                    width: rw, height: rh
                )
                ctx.fillEllipse(in: rect)
            }
        }
        let tex = SKTexture(image: img)
        cache["cork"] = tex
        return tex
    }

    static func blotter() -> SKTexture {
        if let t = cache["blotter"] { return t }
        let img = render(size: CGSize(width: 512, height: 512)) { ctx, w, h in
            UIColor(red: 0.76, green: 0.84, blue: 0.70, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            // grid dots like blotting paper
            UIColor(white: 0.35, alpha: 0.06).setFill()
            stride(from: CGFloat(0), to: w, by: 14).forEach { x in
                stride(from: CGFloat(0), to: h, by: 14).forEach { y in
                    ctx.fillEllipse(in: CGRect(x: x, y: y, width: 2.2, height: 2.2))
                }
            }
            // soft color washes
            for _ in 0..<6 {
                let wash = UIColor(
                    red: CGFloat.random(in: 0.7...0.9),
                    green: CGFloat.random(in: 0.75...0.92),
                    blue: CGFloat.random(in: 0.55...0.75),
                    alpha: 0.07
                )
                wash.setFill()
                ctx.fillEllipse(in: CGRect(
                    x: CGFloat.random(in: -40...w),
                    y: CGFloat.random(in: -40...h),
                    width: CGFloat.random(in: 80...200),
                    height: CGFloat.random(in: 60...160)
                ))
            }
        }
        let tex = SKTexture(image: img)
        cache["blotter"] = tex
        return tex
    }

    // MARK: - Shape helpers

    static func tornRectPath(size: CGSize, jagged: CGFloat = 4) -> CGPath {
        let path = UIBezierPath()
        let w = size.width, h = size.height
        let hw = w / 2, hh = h / 2
        func j() -> CGFloat { CGFloat.random(in: -jagged...jagged) }

        path.move(to: CGPoint(x: -hw + j(), y: hh + j()))
        // top edge
        var x = -hw
        while x < hw {
            x += CGFloat.random(in: 8...18)
            path.addLine(to: CGPoint(x: min(x, hw) + j() * 0.3, y: hh + j()))
        }
        // right
        var y = hh
        while y > -hh {
            y -= CGFloat.random(in: 8...18)
            path.addLine(to: CGPoint(x: hw + j(), y: max(y, -hh) + j() * 0.3))
        }
        // bottom
        x = hw
        while x > -hw {
            x -= CGFloat.random(in: 8...18)
            path.addLine(to: CGPoint(x: max(x, -hw) + j() * 0.3, y: -hh + j()))
        }
        // left
        y = -hh
        while y < hh {
            y += CGFloat.random(in: 8...18)
            path.addLine(to: CGPoint(x: -hw + j(), y: min(y, hh) + j() * 0.3))
        }
        path.close()
        return path.cgPath
    }

    static func diamondPath(width: CGFloat, height: CGFloat, wobble: CGFloat = 0) -> CGPath {
        let path = UIBezierPath()
        let t = CGPoint(x: CGFloat.random(in: -wobble...wobble), y: height * 0.5 + CGFloat.random(in: -wobble...wobble))
        let r = CGPoint(x: width * 0.5 + CGFloat.random(in: -wobble...wobble), y: CGFloat.random(in: -wobble...wobble))
        let b = CGPoint(x: CGFloat.random(in: -wobble...wobble), y: -height * 0.5 + CGFloat.random(in: -wobble...wobble))
        let l = CGPoint(x: -width * 0.5 + CGFloat.random(in: -wobble...wobble), y: CGFloat.random(in: -wobble...wobble))
        path.move(to: t)
        path.addLine(to: r)
        path.addLine(to: b)
        path.addLine(to: l)
        path.close()
        return path.cgPath
    }

    // MARK: - Private

    private static func render(size: CGSize, draw: (CGContext, CGFloat, CGFloat) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { rc in
            draw(rc.cgContext, size.width, size.height)
        }
    }
}

private extension UIColor {
    var rgbaKey: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return "\(Int(r*255))-\(Int(g*255))-\(Int(b*255))"
    }
}
