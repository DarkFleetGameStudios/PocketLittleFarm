import SpriteKit
import UIKit

protocol FarmSceneDelegate: AnyObject {
    func farmScene(_ scene: FarmScene, didTapPlotId id: Int)
    func farmSceneDidTapChickenPen(_ scene: FarmScene)
}

/// Rich isometric paper tapestry — scrapbook diorama, not a vanilla grid.
final class FarmScene: SKScene {
    weak var farmDelegate: FarmSceneDelegate?

    private let tileW: CGFloat = 84
    private let tileH: CGFloat = 42
    private let gridRows = SaveGame.gridRows
    private let gridCols = SaveGame.gridCols

    private var plotNodes: [Int: SKNode] = [:]
    private var cameraNode = SKCameraNode()
    private var penNode: SKNode?
    private var worldRoot: SKNode?
    private var plotsLayer: SKNode?
    private var decorLayer: SKNode?
    private var builtStatic = false

    private var pinchGesture: UIPinchGestureRecognizer?
    private var panGesture: UIPanGestureRecognizer?

    // MARK: - Iso

    private func isoPoint(col: Int, row: Int) -> CGPoint {
        let x = CGFloat(col - row) * (tileW * 0.5)
        let y = CGFloat(col + row) * (tileH * 0.5)
        return CGPoint(x: x, y: -y)
    }

    private func isoDepth(col: Int, row: Int) -> CGFloat {
        CGFloat(col + row) * 2
    }

    private var gridCenterOffset: CGPoint {
        let mid = isoPoint(col: (gridCols - 1) / 2, row: (gridRows - 1) / 2)
        return CGPoint(x: -mid.x, y: -mid.y + 24)
    }

    private func plotPosition(col: Int, row: Int) -> CGPoint {
        let p = isoPoint(col: col, row: row)
        let o = gridCenterOffset
        return CGPoint(x: p.x + o.x, y: p.y + o.y)
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.62, green: 0.72, blue: 0.58, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        if camera == nil {
            addChild(cameraNode)
            camera = cameraNode
            cameraNode.setScale(0.95)
        }

        if !builtStatic {
            buildTapestry()
            builtStatic = true
        }
        installGestures(on: view)
    }

    override func willMove(from view: SKView) {
        if let pinch = pinchGesture { view.removeGestureRecognizer(pinch) }
        if let pan = panGesture { view.removeGestureRecognizer(pan) }
        pinchGesture = nil
        panGesture = nil
    }

    func apply(save: SaveGame) {
        rebuildPlots(from: save)
        rebuildPen(from: save)
        rebuildDecor(from: save)
    }

    // MARK: - Tapestry world

    private func buildTapestry() {
        let world = SKNode()
        world.name = "world"
        addChild(world)
        worldRoot = world

        // 1) Desk blotter (full soft field)
        let blotter = SKSpriteNode(texture: PaperMaterials.blotter(), size: CGSize(width: 920, height: 1100))
        blotter.zPosition = -100
        blotter.name = "blotter"
        world.addChild(blotter)

        // 2) Cork corner patches
        for (i, pos) in [
            CGPoint(x: -280, y: 320), CGPoint(x: 300, y: -280), CGPoint(x: -260, y: -300)
        ].enumerated() {
            let cork = SKSpriteNode(texture: PaperMaterials.cork(), size: CGSize(width: 160, height: 120))
            cork.position = pos
            cork.zRotation = CGFloat(i) * 0.2 - 0.15
            cork.alpha = 0.55
            cork.zPosition = -90
            world.addChild(cork)
        }

        // 3) Under-scraps (angled papers under main page)
        let scrapColors: [UIColor] = [
            UIColor(red: 0.93, green: 0.88, blue: 0.78, alpha: 1),
            UIColor(red: 0.88, green: 0.82, blue: 0.90, alpha: 1),
            UIColor(red: 0.82, green: 0.90, blue: 0.86, alpha: 1),
            UIColor(red: 0.95, green: 0.86, blue: 0.80, alpha: 1),
        ]
        let scrapLayouts: [(CGPoint, CGFloat, CGSize)] = [
            (CGPoint(x: -40, y: 20), 0.12, CGSize(width: 420, height: 480)),
            (CGPoint(x: 50, y: -30), -0.08, CGSize(width: 400, height: 460)),
            (CGPoint(x: -20, y: -10), 0.04, CGSize(width: 380, height: 440)),
        ]
        for (idx, layout) in scrapLayouts.enumerated() {
            let scrap = texturedTornCard(
                size: layout.2,
                color: scrapColors[idx % scrapColors.count],
                jagged: 7
            )
            scrap.position = layout.0
            scrap.zRotation = layout.1
            scrap.zPosition = CGFloat(-80 + idx)
            scrap.alpha = 0.95
            world.addChild(scrap)

            let sh = shadowFor(size: layout.2, corner: 8)
            sh.position = CGPoint(x: layout.0.x + 10, y: layout.0.y - 14)
            sh.zRotation = layout.1
            sh.zPosition = scrap.zPosition - 0.5
            world.addChild(sh)
        }

        // 4) Main scrapbook page (hero paper)
        let pageSize = CGSize(width: 460, height: 540)
        let pageShadow = shadowFor(size: pageSize, corner: 6)
        pageShadow.position = CGPoint(x: 12, y: -18)
        pageShadow.zPosition = -50
        world.addChild(pageShadow)

        let page = texturedTornCard(
            size: pageSize,
            color: UIColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 1),
            jagged: 5,
            fiber: 0.18
        )
        page.name = "main_page"
        page.zPosition = -40
        world.addChild(page)

        // Ruled faint lines on page (journal)
        for i in 0..<16 {
            let line = SKShapeNode(rectOf: CGSize(width: 380, height: 1))
            line.fillColor = UIColor(red: 0.55, green: 0.62, blue: 0.75, alpha: 0.12)
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: 200 - CGFloat(i) * 26)
            line.zPosition = -39
            world.addChild(line)
        }
        // Red journal margin
        let margin = SKShapeNode(rectOf: CGSize(width: 2, height: 460))
        margin.fillColor = UIColor(red: 0.85, green: 0.35, blue: 0.35, alpha: 0.25)
        margin.strokeColor = .clear
        margin.position = CGPoint(x: -170, y: 0)
        margin.zPosition = -39
        world.addChild(margin)

        // 5) Washi tape strips pinning the page
        addWashiTape(to: world, at: CGPoint(x: -150, y: 230), rotation: -0.2, hue: 0.08)
        addWashiTape(to: world, at: CGPoint(x: 160, y: 220), rotation: 0.25, hue: 0.55)
        addWashiTape(to: world, at: CGPoint(x: -140, y: -240), rotation: 0.15, hue: 0.35)
        addWashiTape(to: world, at: CGPoint(x: 150, y: -230), rotation: -0.18, hue: 0.95)

        // 6) Ephemera collage around the farm
        addStamp(to: world, text: "FARM", at: CGPoint(x: -150, y: 175), rotation: -0.12, color: UIColor(red: 0.55, green: 0.2, blue: 0.18, alpha: 0.75))
        addStamp(to: world, text: "EST. 2026", at: CGPoint(x: 145, y: 165), rotation: 0.1, color: UIColor(red: 0.2, green: 0.35, blue: 0.55, alpha: 0.7))
        addTicketStub(to: world, at: CGPoint(x: 175, y: -40), rotation: 0.35)
        addPaperFlower(to: world, at: CGPoint(x: -175, y: -60), rotation: -0.2)
        addPaperSun(to: world, at: CGPoint(x: 0, y: 210))
        addCloudCutout(to: world, at: CGPoint(x: -100, y: 195), scale: 0.7)
        addCloudCutout(to: world, at: CGPoint(x: 110, y: 200), scale: 0.55)

        // Title plate
        let titlePlate = texturedTornCard(
            size: CGSize(width: 200, height: 44),
            color: UIColor(red: 0.99, green: 0.97, blue: 0.93, alpha: 1),
            jagged: 3
        )
        titlePlate.position = CGPoint(x: 0, y: -248)
        titlePlate.zPosition = 90
        world.addChild(titlePlate)
        let title = SKLabelNode(text: "Little Paper Farm")
        title.fontName = "AvenirNext-DemiBold"
        title.fontSize = 16
        title.fontColor = PaperTheme.UI.ink
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: -248)
        title.zPosition = 91
        world.addChild(title)

        // 7) House as layered paper cottage
        let houseAnchor = plotPosition(col: 0, row: 0)
        let house = buildPaperHouse()
        house.position = CGPoint(x: houseAnchor.x - 95, y: houseAnchor.y + 95)
        house.zPosition = -8
        house.name = "house"
        world.addChild(house)

        // Layers for dynamic content
        let plots = SKNode()
        plots.name = "plots"
        plots.zPosition = 0
        world.addChild(plots)
        plotsLayer = plots

        let decor = SKNode()
        decor.name = "decor"
        decor.zPosition = 50
        world.addChild(decor)
        decorLayer = decor

        // Soft bright wash (stage lights — keeps it readable, not gloomy)
        let wash = SKSpriteNode(color: UIColor(red: 1, green: 0.98, blue: 0.92, alpha: 0.12), size: CGSize(width: 900, height: 1100))
        wash.zPosition = 200
        wash.blendMode = .alpha
        wash.isUserInteractionEnabled = false
        // Don't block touches — SKSpriteNode doesn't by default for touches on scene
        world.addChild(wash)
    }

    // MARK: - Ephemera builders

    private func texturedTornCard(
        size: CGSize,
        color: UIColor,
        jagged: CGFloat,
        fiber: CGFloat = 0.12
    ) -> SKNode {
        let root = SKNode()
        let path = PaperMaterials.tornRectPath(size: size, jagged: jagged)
        let shape = SKShapeNode(path: path)
        shape.fillColor = color
        shape.strokeColor = UIColor(white: 0.25, alpha: 0.2)
        shape.lineWidth = 1.2
        shape.lineJoin = .round

        let tex = PaperMaterials.paper(base: color, size: CGSize(width: 256, height: 256), fiber: fiber)
        let fill = SKSpriteNode(texture: tex, size: size)
        // Mask fill to torn shape via crop node
        let crop = SKCropNode()
        let mask = SKShapeNode(path: path)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask
        crop.addChild(fill)
        root.addChild(crop)

        let edge = SKShapeNode(path: path)
        edge.fillColor = .clear
        edge.strokeColor = UIColor(red: 0.45, green: 0.38, blue: 0.28, alpha: 0.45)
        edge.lineWidth = 1.5
        edge.lineJoin = .round
        root.addChild(edge)

        // Inner paper edge highlight
        let hi = SKShapeNode(path: path)
        hi.fillColor = .clear
        hi.strokeColor = UIColor(white: 1, alpha: 0.35)
        hi.lineWidth = 1
        hi.setScale(0.985)
        root.addChild(hi)

        return root
    }

    private func shadowFor(size: CGSize, corner: CGFloat) -> SKShapeNode {
        let s = SKShapeNode(rectOf: CGSize(width: size.width * 0.98, height: size.height * 0.98), cornerRadius: corner)
        s.fillColor = UIColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 0.18)
        s.strokeColor = .clear
        s.glowWidth = 12
        return s
    }

    private func addWashiTape(to parent: SKNode, at: CGPoint, rotation: CGFloat, hue: CGFloat) {
        let tape = SKSpriteNode(texture: PaperMaterials.washi(hueShift: hue), size: CGSize(width: 92, height: 22))
        tape.position = at
        tape.zRotation = rotation
        tape.zPosition = 85
        tape.alpha = 0.92
        // torn ends
        let leftNibble = SKShapeNode(circleOfRadius: 5)
        leftNibble.fillColor = UIColor(red: 0.76, green: 0.84, blue: 0.70, alpha: 1)
        leftNibble.strokeColor = .clear
        leftNibble.position = CGPoint(x: -48, y: 0)
        // Don't nibble with blotter color on tape — use semi transparent shadow instead
        parent.addChild(tape)

        let edge = SKShapeNode(rectOf: CGSize(width: 92, height: 22), cornerRadius: 2)
        edge.fillColor = .clear
        edge.strokeColor = UIColor(white: 1, alpha: 0.35)
        edge.lineWidth = 1
        edge.position = at
        edge.zRotation = rotation
        edge.zPosition = 86
        parent.addChild(edge)
    }

    private func addStamp(to parent: SKNode, text: String, at: CGPoint, rotation: CGFloat, color: UIColor) {
        let box = SKShapeNode(rectOf: CGSize(width: CGFloat(text.count) * 9 + 16, height: 28), cornerRadius: 3)
        box.strokeColor = color
        box.fillColor = color.withAlphaComponent(0.06)
        box.lineWidth = 2
        box.position = at
        box.zRotation = rotation
        box.zPosition = 70

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 11
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        box.addChild(label)
        parent.addChild(box)
    }

    private func addTicketStub(to parent: SKNode, at: CGPoint, rotation: CGFloat) {
        let stub = texturedTornCard(
            size: CGSize(width: 70, height: 110),
            color: UIColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 1),
            jagged: 2
        )
        stub.position = at
        stub.zRotation = rotation
        stub.zPosition = 60
        parent.addChild(stub)

        let stripe = SKShapeNode(rectOf: CGSize(width: 70, height: 14))
        stripe.fillColor = UIColor(red: 0.75, green: 0.25, blue: 0.22, alpha: 0.85)
        stripe.strokeColor = .clear
        stripe.position = CGPoint(x: at.x, y: at.y + 35)
        stripe.zRotation = rotation
        stripe.zPosition = 61
        parent.addChild(stripe)

        let t = SKLabelNode(text: "PASS")
        t.fontName = "AvenirNext-Bold"
        t.fontSize = 10
        t.fontColor = PaperTheme.UI.ink
        t.verticalAlignmentMode = .center
        t.position = at
        t.zRotation = rotation
        t.zPosition = 62
        parent.addChild(t)
    }

    private func addPaperFlower(to parent: SKNode, at: CGPoint, rotation: CGFloat) {
        let root = SKNode()
        root.position = at
        root.zRotation = rotation
        root.zPosition = 65
        let petals: [(CGFloat, UIColor)] = [
            (0, UIColor(red: 0.95, green: 0.55, blue: 0.55, alpha: 1)),
            (0.8, UIColor(red: 0.95, green: 0.7, blue: 0.55, alpha: 1)),
            (1.6, UIColor(red: 0.95, green: 0.55, blue: 0.7, alpha: 1)),
            (2.4, UIColor(red: 0.9, green: 0.6, blue: 0.55, alpha: 1)),
            (3.2, UIColor(red: 0.92, green: 0.5, blue: 0.55, alpha: 1)),
        ]
        for (angle, color) in petals {
            let petal = SKShapeNode(ellipseOf: CGSize(width: 18, height: 28))
            petal.fillColor = color
            petal.strokeColor = UIColor(white: 0.3, alpha: 0.2)
            petal.lineWidth = 1
            petal.position = CGPoint(x: cos(angle) * 8, y: sin(angle) * 8)
            petal.zRotation = angle
            root.addChild(petal)
        }
        let center = SKShapeNode(circleOfRadius: 7)
        center.fillColor = UIColor(red: 0.95, green: 0.85, blue: 0.35, alpha: 1)
        center.strokeColor = UIColor(white: 0.3, alpha: 0.25)
        root.addChild(center)
        parent.addChild(root)
    }

    private func addPaperSun(to parent: SKNode, at: CGPoint) {
        let sun = SKShapeNode(circleOfRadius: 22)
        sun.fillColor = UIColor(red: 0.98, green: 0.82, blue: 0.35, alpha: 1)
        sun.strokeColor = UIColor(red: 0.85, green: 0.55, blue: 0.15, alpha: 0.5)
        sun.lineWidth = 2
        sun.position = at
        sun.zPosition = 55
        parent.addChild(sun)
        for i in 0..<8 {
            let ray = SKShapeNode(rectOf: CGSize(width: 4, height: 12), cornerRadius: 2)
            ray.fillColor = UIColor(red: 0.98, green: 0.78, blue: 0.3, alpha: 0.85)
            ray.strokeColor = .clear
            let a = CGFloat(i) * (.pi / 4)
            ray.position = CGPoint(x: at.x + cos(a) * 30, y: at.y + sin(a) * 30)
            ray.zRotation = a
            ray.zPosition = 54
            parent.addChild(ray)
        }
    }

    private func addCloudCutout(to parent: SKNode, at: CGPoint, scale: CGFloat) {
        let cloud = SKNode()
        cloud.position = at
        cloud.setScale(scale)
        cloud.zPosition = 52
        for (dx, dy, r) in [(-12, 0, 14), (0, 4, 16), (14, 0, 13), (4, -4, 11)] as [(CGFloat, CGFloat, CGFloat)] {
            let p = SKShapeNode(circleOfRadius: r)
            p.fillColor = UIColor(white: 0.98, alpha: 0.92)
            p.strokeColor = UIColor(white: 0.4, alpha: 0.15)
            p.lineWidth = 1
            p.position = CGPoint(x: dx, y: dy)
            cloud.addChild(p)
        }
        parent.addChild(cloud)
    }

    private func buildPaperHouse() -> SKNode {
        let root = SKNode()

        // Shadow
        let sh = SKShapeNode(ellipseOf: CGSize(width: 100, height: 28))
        sh.fillColor = UIColor(white: 0.2, alpha: 0.15)
        sh.strokeColor = .clear
        sh.position = CGPoint(x: 4, y: -36)
        root.addChild(sh)

        // Body layers (stacked paper)
        for i in 0..<3 {
            let body = SKShapeNode(rectOf: CGSize(width: 88 - CGFloat(i), height: 58 - CGFloat(i)), cornerRadius: 4)
            body.fillColor = UIColor(red: 0.99, green: 0.96 - CGFloat(i) * 0.02, blue: 0.90, alpha: 1)
            body.strokeColor = UIColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 0.5)
            body.lineWidth = 1.5
            body.position = CGPoint(x: CGFloat(i) * 1.5, y: CGFloat(i) * 1.5 - 4)
            body.zPosition = CGFloat(i)
            root.addChild(body)
        }

        // Roof triangle paper
        let roofPath = UIBezierPath()
        roofPath.move(to: CGPoint(x: -52, y: 22))
        roofPath.addLine(to: CGPoint(x: 0, y: 58))
        roofPath.addLine(to: CGPoint(x: 52, y: 22))
        roofPath.close()
        let roof = SKShapeNode(path: roofPath.cgPath)
        roof.fillColor = UIColor(red: 0.78, green: 0.38, blue: 0.32, alpha: 1)
        roof.strokeColor = UIColor(red: 0.45, green: 0.2, blue: 0.15, alpha: 0.6)
        roof.lineWidth = 1.5
        roof.zPosition = 5
        root.addChild(roof)

        // Door
        let door = SKShapeNode(rectOf: CGSize(width: 18, height: 28), cornerRadius: 2)
        door.fillColor = UIColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1)
        door.strokeColor = UIColor(white: 0.2, alpha: 0.3)
        door.position = CGPoint(x: 0, y: -16)
        door.zPosition = 6
        root.addChild(door)

        // Windows
        for dx in [-26, 26] as [CGFloat] {
            let w = SKShapeNode(rectOf: CGSize(width: 14, height: 14), cornerRadius: 2)
            w.fillColor = UIColor(red: 0.65, green: 0.82, blue: 0.92, alpha: 1)
            w.strokeColor = UIColor(white: 0.3, alpha: 0.35)
            w.lineWidth = 1.2
            w.position = CGPoint(x: dx, y: 2)
            w.zPosition = 6
            root.addChild(w)
        }

        let label = SKLabelNode(text: "Home")
        label.fontName = "AvenirNext-Medium"
        label.fontSize = 11
        label.fontColor = PaperTheme.UI.ink
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -48)
        label.zPosition = 7
        root.addChild(label)

        return root
    }

    // MARK: - Plots (rich paper tiles)

    private func rebuildPlots(from save: SaveGame) {
        plotNodes.values.forEach { $0.removeFromParent() }
        plotNodes.removeAll()
        let parent = plotsLayer ?? worldRoot ?? self

        for plot in save.plots {
            let pos = plotPosition(col: plot.col, row: plot.row)
            // Tiny organic offset so tapestry isn't rigid
            let jitter = CGPoint(
                x: CGFloat((plot.id * 17) % 5) - 2,
                y: CGFloat((plot.id * 13) % 5) - 2
            )
            let root = SKNode()
            root.position = CGPoint(x: pos.x + jitter.x * 0.4, y: pos.y + jitter.y * 0.3)
            root.name = "plot_\(plot.id)"
            root.zPosition = isoDepth(col: plot.col, row: plot.row)
            root.zRotation = CGFloat((plot.id % 7) - 3) * 0.008

            // Drop shadow diamond
            let shadow = SKShapeNode(path: PaperMaterials.diamondPath(width: tileW - 4, height: tileH - 2))
            shadow.fillColor = UIColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 0.2)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 4, y: -5)
            shadow.zPosition = -1
            root.addChild(shadow)

            // Stacked paper thickness (2–3 layers)
            let layers = 3
            for i in 0..<layers {
                let layerPath = PaperMaterials.diamondPath(
                    width: tileW - 10 - CGFloat(i),
                    height: tileH - 6 - CGFloat(i) * 0.5,
                    wobble: i == layers - 1 ? 1.2 : 0.4
                )
                let layer = SKShapeNode(path: layerPath)
                let base = soilColor(for: plot, layer: i)
                layer.fillColor = base
                layer.strokeColor = UIColor(red: 0.4, green: 0.32, blue: 0.22, alpha: 0.55)
                layer.lineWidth = i == layers - 1 ? 1.8 : 1
                layer.lineJoin = .round
                layer.position = CGPoint(x: CGFloat(i) * 0.8, y: CGFloat(i) * 1.6)
                layer.zPosition = CGFloat(i)
                if i == layers - 1 {
                    layer.name = "soil"
                    // Grain overlay via textured sprite cropped to diamond
                    let crop = SKCropNode()
                    let mask = SKShapeNode(path: layerPath)
                    mask.fillColor = .white
                    mask.strokeColor = .clear
                    crop.maskNode = mask
                    let grain = SKSpriteNode(
                        texture: PaperMaterials.paper(base: base, fiber: 0.16, freckle: 0.1),
                        size: CGSize(width: tileW, height: tileH)
                    )
                    grain.alpha = 0.55
                    crop.addChild(grain)
                    crop.zPosition = 0.5
                    layer.addChild(crop)
                }
                root.addChild(layer)
            }

            // Stitch marks on empty plots (handcrafted)
            if plot.phase == .empty {
                for s in 0..<3 {
                    let stitch = SKShapeNode(rectOf: CGSize(width: 5, height: 1.2))
                    stitch.fillColor = UIColor(white: 0.3, alpha: 0.2)
                    stitch.strokeColor = .clear
                    stitch.position = CGPoint(x: CGFloat(s - 1) * 10, y: 2)
                    stitch.zPosition = 4
                    root.addChild(stitch)
                }
            }

            if plot.phase != .empty {
                let cropNode = buildPaperCrop(for: plot)
                cropNode.position = CGPoint(x: 0, y: tileH * 0.22)
                cropNode.zPosition = 8
                root.addChild(cropNode)

                if let chip = statusChip(for: plot) {
                    chip.position = CGPoint(x: 0, y: -tileH * 0.62)
                    chip.zPosition = 12
                    root.addChild(chip)
                }
            }

            parent.addChild(root)
            plotNodes[plot.id] = root
        }
    }

    /// Paper-cut plant: layered shapes + emoji accent (readable + crafty).
    private func buildPaperCrop(for plot: PlotState) -> SKNode {
        let root = SKNode()
        let phase = plot.phase
        let cropId = plot.cropId ?? "radish"

        // Stem paper strip
        if phase != .lost {
            let stem = SKShapeNode(rectOf: CGSize(width: 5, height: phase == .ripe ? 22 : 16), cornerRadius: 1)
            stem.fillColor = UIColor(red: 0.35, green: 0.55, blue: 0.28, alpha: 1)
            stem.strokeColor = UIColor(white: 0.2, alpha: 0.25)
            stem.position = CGPoint(x: 0, y: 4)
            root.addChild(stem)
        }

        // Leaf cutouts
        let leafColor: UIColor = {
            switch phase {
            case .wilted, .lost: return UIColor(red: 0.55, green: 0.5, blue: 0.32, alpha: 1)
            case .thirsty: return UIColor(red: 0.55, green: 0.65, blue: 0.35, alpha: 1)
            case .ripe: return UIColor(red: 0.35, green: 0.62, blue: 0.32, alpha: 1)
            default: return UIColor(red: 0.42, green: 0.7, blue: 0.38, alpha: 1)
            }
        }()

        for (dx, rot, sc) in [(-8, CGFloat(-0.5), CGFloat(1)), (8, CGFloat(0.5), CGFloat(0.9)), (0, CGFloat(0.1), CGFloat(0.75))] as [(CGFloat, CGFloat, CGFloat)] {
            let leaf = SKShapeNode(ellipseOf: CGSize(width: 16 * sc, height: 10 * sc))
            leaf.fillColor = leafColor
            leaf.strokeColor = UIColor(white: 0.25, alpha: 0.25)
            leaf.lineWidth = 1
            leaf.position = CGPoint(x: dx, y: phase == .ripe ? 16 : 12)
            leaf.zRotation = rot
            root.addChild(leaf)
        }

        // Produce paper shape when ripening
        if phase == .ripe || phase == .growing {
            let produce = produceCutout(cropId: cropId, ripe: phase == .ripe)
            produce.position = CGPoint(x: 0, y: phase == .ripe ? 20 : 10)
            produce.setScale(phase == .ripe ? 1 : 0.55)
            produce.alpha = phase == .ripe ? 1 : 0.7
            root.addChild(produce)
        }

        if phase == .wilted {
            let droop = SKLabelNode(text: "🥀")
            droop.fontSize = 18
            droop.verticalAlignmentMode = .center
            droop.position = CGPoint(x: 10, y: 18)
            root.addChild(droop)
        }

        // Soft white paper edge ring for pop
        if phase == .ripe {
            let glow = SKShapeNode(circleOfRadius: 16)
            glow.fillColor = UIColor(red: 1, green: 0.95, blue: 0.5, alpha: 0.2)
            glow.strokeColor = .clear
            glow.position = CGPoint(x: 0, y: 18)
            glow.zPosition = -1
            root.addChild(glow)
        }

        return root
    }

    private func produceCutout(cropId: String, ripe: Bool) -> SKNode {
        let n = SKNode()
        switch cropId {
        case "tomato":
            let t = SKShapeNode(circleOfRadius: ripe ? 10 : 6)
            t.fillColor = UIColor(red: 0.9, green: 0.28, blue: 0.22, alpha: 1)
            t.strokeColor = UIColor(white: 0.2, alpha: 0.3)
            t.lineWidth = 1.2
            n.addChild(t)
            let shine = SKShapeNode(circleOfRadius: 3)
            shine.fillColor = UIColor(white: 1, alpha: 0.45)
            shine.strokeColor = .clear
            shine.position = CGPoint(x: -3, y: 3)
            n.addChild(shine)
        case "pumpkin":
            let p = SKShapeNode(ellipseOf: CGSize(width: 22, height: 16))
            p.fillColor = UIColor(red: 0.92, green: 0.5, blue: 0.15, alpha: 1)
            p.strokeColor = UIColor(white: 0.25, alpha: 0.3)
            n.addChild(p)
        case "corn":
            let c = SKShapeNode(ellipseOf: CGSize(width: 10, height: 22))
            c.fillColor = UIColor(red: 0.95, green: 0.82, blue: 0.25, alpha: 1)
            c.strokeColor = UIColor(white: 0.3, alpha: 0.3)
            n.addChild(c)
        case "lettuce":
            for i in 0..<4 {
                let l = SKShapeNode(ellipseOf: CGSize(width: 14, height: 10))
                l.fillColor = UIColor(red: 0.45, green: 0.75, blue: 0.4, alpha: 1)
                l.strokeColor = UIColor(white: 0.2, alpha: 0.2)
                l.zRotation = CGFloat(i) * 0.7
                l.position = CGPoint(x: cos(CGFloat(i)) * 3, y: sin(CGFloat(i)) * 2)
                n.addChild(l)
            }
        default: // radish
            let bulb = SKShapeNode(circleOfRadius: 8)
            bulb.fillColor = UIColor(red: 0.9, green: 0.35, blue: 0.4, alpha: 1)
            bulb.strokeColor = UIColor(white: 0.25, alpha: 0.3)
            n.addChild(bulb)
            let top = SKShapeNode(ellipseOf: CGSize(width: 6, height: 4))
            top.fillColor = UIColor(white: 0.95, alpha: 1)
            top.strokeColor = .clear
            top.position = CGPoint(x: 0, y: 6)
            n.addChild(top)
        }
        return n
    }

    private func rebuildPen(from save: SaveGame) {
        penNode?.removeFromParent()
        let parent = worldRoot ?? self
        let anchor = plotPosition(col: gridCols - 1, row: 0)

        let root = SKNode()
        root.position = CGPoint(x: anchor.x + 88, y: anchor.y + 88)
        root.zPosition = isoDepth(col: gridCols - 1, row: 0) + 4
        root.name = "chicken_pen"

        let sh = SKShapeNode(ellipseOf: CGSize(width: 150, height: 40))
        sh.fillColor = UIColor(white: 0.2, alpha: 0.14)
        sh.strokeColor = .clear
        sh.position = CGPoint(x: 6, y: -42)
        root.addChild(sh)

        // Layered kraft coop card
        let card = texturedTornCard(
            size: CGSize(width: 148, height: 100),
            color: UIColor(red: 0.93, green: 0.86, blue: 0.72, alpha: 1),
            jagged: 3
        )
        root.addChild(card)

        // Wire fence marks
        for i in 0..<5 {
            let wire = SKShapeNode(rectOf: CGSize(width: 1.5, height: 70))
            wire.fillColor = UIColor(white: 0.35, alpha: 0.25)
            wire.strokeColor = .clear
            wire.position = CGPoint(x: -50 + CGFloat(i) * 25, y: 0)
            wire.zPosition = 2
            root.addChild(wire)
        }

        let hens = save.animals.filter { $0.kind == "chicken" }
        let moods = hens.map(\.mood)
        let worst: AnimalMood = moods.contains(.neglected) ? .neglected
            : (moods.contains(.hungry) ? .hungry : .content)

        // Paper chicken silhouettes
        for (i, _) in hens.enumerated() {
            let hen = paperChicken()
            hen.position = CGPoint(x: -28 + CGFloat(i) * 40, y: 8)
            hen.zPosition = 5
            hen.setScale(0.9)
            root.addChild(hen)
        }

        let eggs = hens.reduce(0) { $0 + $1.pendingProduce }
        if eggs > 0 {
            for e in 0..<min(eggs, 4) {
                let egg = SKShapeNode(ellipseOf: CGSize(width: 10, height: 13))
                egg.fillColor = UIColor(red: 0.98, green: 0.96, blue: 0.9, alpha: 1)
                egg.strokeColor = UIColor(white: 0.4, alpha: 0.35)
                egg.position = CGPoint(x: -20 + CGFloat(e) * 14, y: -22)
                egg.zPosition = 6
                root.addChild(egg)
            }
        }

        let status: String
        let statusColor: UIColor
        switch worst {
        case .content:
            status = eggs > 0 ? "Eggs ×\(eggs)" : "Content"
            statusColor = UIColor(red: 0.18, green: 0.42, blue: 0.24, alpha: 1)
        case .hungry:
            status = "Hungry"
            statusColor = UIColor(red: 0.85, green: 0.40, blue: 0.08, alpha: 1)
        case .neglected:
            status = "Neglected"
            statusColor = UIColor(red: 0.72, green: 0.18, blue: 0.14, alpha: 1)
        }

        let badge = SKShapeNode(rectOf: CGSize(width: 88, height: 20), cornerRadius: 8)
        badge.fillColor = UIColor(white: 1, alpha: 0.9)
        badge.strokeColor = statusColor.withAlphaComponent(0.5)
        badge.lineWidth = 1.5
        badge.position = CGPoint(x: 0, y: -40)
        badge.zPosition = 8
        root.addChild(badge)

        let label = SKLabelNode(text: status)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 12
        label.fontColor = statusColor
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -40)
        label.zPosition = 9
        root.addChild(label)

        parent.addChild(root)
        penNode = root
    }

    private func paperChicken() -> SKNode {
        let n = SKNode()
        let body = SKShapeNode(ellipseOf: CGSize(width: 22, height: 16))
        body.fillColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
        body.strokeColor = UIColor(white: 0.3, alpha: 0.35)
        body.lineWidth = 1.2
        n.addChild(body)
        let head = SKShapeNode(circleOfRadius: 6)
        head.fillColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
        head.strokeColor = UIColor(white: 0.3, alpha: 0.35)
        head.position = CGPoint(x: 10, y: 6)
        n.addChild(head)
        let comb = SKShapeNode(ellipseOf: CGSize(width: 6, height: 5))
        comb.fillColor = UIColor(red: 0.85, green: 0.25, blue: 0.22, alpha: 1)
        comb.strokeColor = .clear
        comb.position = CGPoint(x: 10, y: 12)
        n.addChild(comb)
        let beak = SKShapeNode(path: {
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 15, y: 6))
            p.addLine(to: CGPoint(x: 22, y: 5))
            p.addLine(to: CGPoint(x: 15, y: 3))
            p.close()
            return p.cgPath
        }())
        beak.fillColor = UIColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 1)
        beak.strokeColor = .clear
        n.addChild(beak)
        return n
    }

    private func rebuildDecor(from save: SaveGame) {
        let parent = decorLayer ?? worldRoot ?? self
        parent.children.filter { $0.name?.hasPrefix("deco_") == true }.forEach { $0.removeFromParent() }

        for deco in save.decorations {
            let def = DecorationDefinition.byId[deco.decorationId]
            let pos = plotPosition(col: deco.col, row: deco.row)
            let node = SKLabelNode(text: decorEmoji(def))
            node.fontSize = 26
            node.verticalAlignmentMode = .center
            node.position = CGPoint(x: pos.x, y: pos.y + tileH * 0.4)
            node.zPosition = isoDepth(col: deco.col, row: deco.row) + 3
            node.name = "deco_\(deco.id)"
            parent.addChild(node)
        }
    }

    // MARK: - Status / color

    private func statusChip(for plot: PlotState) -> SKNode? {
        let text: String
        let fill: UIColor
        switch plot.phase {
        case .growing:
            if let cropId = plot.cropId, let crop = CropDefinition.crop(id: cropId), crop.growDuration > 0 {
                text = "\(min(99, Int((plot.growProgress / crop.growDuration) * 100)))%"
                fill = UIColor(white: 1, alpha: 0.95)
            } else { return nil }
        case .thirsty:
            text = "WATER"
            fill = PaperTheme.UI.chipThirst
        case .wilted:
            text = "WILT"
            fill = PaperTheme.UI.chipWilt
        case .ripe:
            text = "RIPE"
            fill = PaperTheme.UI.chipRipe
        case .lost:
            text = "LOST"
            fill = PaperTheme.UI.chipLost
        case .empty:
            return nil
        }

        let root = SKNode()
        let w: CGFloat = plot.phase == .growing ? 38 : 50
        // Paper chip with shadow
        let sh = SKShapeNode(rectOf: CGSize(width: w, height: 17), cornerRadius: 8)
        sh.fillColor = UIColor(white: 0.2, alpha: 0.15)
        sh.strokeColor = .clear
        sh.position = CGPoint(x: 1, y: -1)
        root.addChild(sh)

        let bg = SKShapeNode(rectOf: CGSize(width: w, height: 17), cornerRadius: 8)
        bg.fillColor = fill
        bg.strokeColor = PaperTheme.UI.ink.withAlphaComponent(0.3)
        bg.lineWidth = 1
        root.addChild(bg)

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 10
        label.fontColor = (plot.phase == .thirsty || plot.phase == .lost) ? .white : PaperTheme.UI.ink
        label.verticalAlignmentMode = .center
        root.addChild(label)
        return root
    }

    private func soilColor(for plot: PlotState, layer: Int) -> UIColor {
        let shade = CGFloat(layer) * 0.04
        func adj(_ c: UIColor) -> UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getRed(&r, green: &g, blue: &b, alpha: &a)
            return UIColor(red: max(0, r - shade), green: max(0, g - shade), blue: max(0, b - shade), alpha: 1)
        }
        switch plot.phase {
        case .empty: return adj(UIColor(red: 0.80, green: 0.64, blue: 0.44, alpha: 1))
        case .growing: return adj(UIColor(red: 0.62, green: 0.48, blue: 0.32, alpha: 1))
        case .thirsty: return adj(UIColor(red: 0.88, green: 0.74, blue: 0.42, alpha: 1))
        case .wilted: return adj(UIColor(red: 0.58, green: 0.52, blue: 0.38, alpha: 1))
        case .ripe: return adj(UIColor(red: 0.55, green: 0.72, blue: 0.42, alpha: 1))
        case .lost: return adj(UIColor(red: 0.48, green: 0.44, blue: 0.40, alpha: 1))
        }
    }

    private func decorEmoji(_ def: DecorationDefinition?) -> String {
        guard let def else { return "✨" }
        switch def.id {
        case "deco_flower_pot": return "🪴"
        case "deco_scarecrow": return "🧍"
        case "deco_bench": return "🪑"
        case "deco_lantern": return "🏮"
        case "deco_wagon": return "🛒"
        case "deco_well": return "🪣"
        case "deco_path_stone": return "🪨"
        case "deco_fence_rose": return "🌹"
        default: return "✨"
        }
    }

    // MARK: - Touch

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let sceneLoc = touch.location(in: self)

        for node in nodes(at: sceneLoc) {
            var c: SKNode? = node
            while let n = c {
                if n.name == "chicken_pen" {
                    farmDelegate?.farmSceneDidTapChickenPen(self)
                    return
                }
                c = n.parent
            }
        }

        let location = touch.location(in: plotsLayer ?? worldRoot ?? self)
        var bestId: Int?
        var bestDist: CGFloat = .greatestFiniteMagnitude
        for (id, node) in plotNodes {
            let dx = node.position.x - location.x
            let dy = node.position.y - location.y
            let d = dx * dx + (dy * 1.7) * (dy * 1.7)
            if d < bestDist {
                bestDist = d
                bestId = id
            }
        }
        if let bestId, bestDist < (tileW * 0.48) * (tileW * 0.48) {
            farmDelegate?.farmScene(self, didTapPlotId: bestId)
        }
    }

    // MARK: - Gestures

    private func installGestures(on view: SKView) {
        if pinchGesture == nil {
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinch)
            pinchGesture = pinch
        }
        if panGesture == nil {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.maximumNumberOfTouches = 1
            view.addGestureRecognizer(pan)
            panGesture = pan
        }
    }

    @objc private func handlePinch(_ gr: UIPinchGestureRecognizer) {
        guard let camera else { return }
        if gr.state == .changed || gr.state == .ended {
            camera.setScale(min(max(camera.xScale / gr.scale, 0.6), 1.85))
            gr.scale = 1
        }
    }

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        guard let camera, let view = view else { return }
        let t = gr.translation(in: view)
        camera.position = CGPoint(
            x: camera.position.x - t.x * camera.xScale,
            y: camera.position.y + t.y * camera.yScale
        )
        gr.setTranslation(.zero, in: view)
        let limit: CGFloat = 300
        camera.position.x = min(max(camera.position.x, -limit), limit)
        camera.position.y = min(max(camera.position.y, -limit), limit)
    }
}
