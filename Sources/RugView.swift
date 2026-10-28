import AppKit
import SceneKit
import QuartzCore
import simd

private final class FabricSceneView: SCNView {
    // The parent owns every gesture, including clicks on transparent corners.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class RugView: NSView {
    enum DragMode { case move, resize, lift }
    private var dragMode: DragMode = .move
    private var lastScreenPoint = NSPoint.zero
    private var startScreenPoint = NSPoint.zero
    private var liftTarget: Float = 0
    private var lift: Float = 0
    private var liftVelocity: Float = 0
    private var ripple: Float = 0
    private var sway = SIMD2<Float>.zero
    private var elapsed: Float = 0
    private var lastTick: CFTimeInterval = 0
    private var timer: Timer?
    private var isDragging = false
    private(set) var liftAmount: CGFloat = 0
    var onGeometryChange: (() -> Void)?

    private let sceneView = FabricSceneView()
    private let scene = SCNScene()
    private let cameraNode = SCNNode()
    private let faceNode = SCNNode()
    private let backNode = SCNNode()
    private let edgeNode = SCNNode()
    private let fringeNode = SCNNode()
    private var gripNodes = [SCNNode]()
    private let faceMaterial = SCNMaterial()
    private let backMaterial = SCNMaterial()
    private let edgeMaterial = SCNMaterial()
    private var textureKey = ""
    private var cloth = RugCloth(size: SIMD2(514, 334), lift: 0, ripple: 0, time: 0)
    private var initialized = false
    private var layoutSize = NSSize.zero
    private static let vertexCount = (RugCloth.columns + 1) * (RugCloth.rows + 1)
    private var topVertices = [SCNVector3](repeating: SCNVector3Zero, count: vertexCount)
    private var bottomVertices = [SCNVector3](repeating: SCNVector3Zero, count: vertexCount)
    private var faceNormals = [SCNVector3](repeating: SCNVector3Zero, count: vertexCount)
    private var backNormals = [SCNVector3](repeating: SCNVector3Zero, count: vertexCount)
    private var textureSource: SCNGeometrySource!
    private var faceElement: SCNGeometryElement!
    private var backElement: SCNGeometryElement!
    private var edgeElement: SCNGeometryElement!
    private var perimeter = [Int]()
    private var edgeVertices = [SCNVector3]()
    private var fringeVertices = [SCNVector3]()
    private var fringeCoordinates = [SIMD2<Float>]()
    private var fringeElement: SCNGeometryElement!
    private let fringeMaterial = SCNMaterial()
    private var fringeStrandCount = 0

    private func prepareTopology() {
        let nx = RugCloth.columns, ny = RugCloth.rows
        var uv = [CGPoint](), front = [UInt16](), back = [UInt16]()
        for row in 0...ny { for column in 0...nx {
            uv.append(CGPoint(x: CGFloat(column) / CGFloat(nx), y: CGFloat(row) / CGFloat(ny)))
        } }
        for row in 0..<ny { for column in 0..<nx {
            let a = UInt16(row * (nx + 1) + column), b = a + 1, c = a + UInt16(nx + 1), d = c + 1
            front += [a, b, c, b, d, c]; back += [a, c, b, b, c, d]
        } }
        textureSource = SCNGeometrySource(textureCoordinates: uv)
        faceElement = SCNGeometryElement(indices: front, primitiveType: .triangles)
        backElement = SCNGeometryElement(indices: back, primitiveType: .triangles)
        perimeter = Array(0...nx)
        perimeter += (1...ny).map { $0 * (nx + 1) + nx }
        perimeter += (0..<nx).reversed().map { ny * (nx + 1) + $0 }
        perimeter += (1..<ny).reversed().map { $0 * (nx + 1) }
        edgeVertices = [SCNVector3](repeating: SCNVector3Zero, count: perimeter.count * 2)
        var edgeIndices = [UInt16]()
        for i in 0..<perimeter.count {
            let a = UInt16(i * 2), b = UInt16(((i + 1) % perimeter.count) * 2)
            edgeIndices += [a, a + 1, b, b, a + 1, b + 1]
        }
        edgeElement = SCNGeometryElement(indices: edgeIndices, primitiveType: .triangles)
        fringeMaterial.lightingModel = .constant
        fringeMaterial.diffuse.contents = NSColor(calibratedRed: 0.82, green: 0.74, blue: 0.59, alpha: 1)
        fringeMaterial.isDoubleSided = true
    }

    private func prepareFringe() {
        let strands = max(24, Int(cloth.size.x / 6))
        guard strands != fringeStrandCount || layoutSize != bounds.size else { return }
        fringeStrandCount = strands
        fringeCoordinates.removeAll(keepingCapacity: true)
        var indices = [UInt16]()
        for side: Float in [0, 1] { for i in 1..<strands {
            let u = Float(i) / Float(strands)
            let end = side == 0 ? -7 / cloth.size.y : 1 + 7 / cloth.size.y
            let index = UInt16(fringeCoordinates.count)
            fringeCoordinates += [SIMD2(u - 0.0012, side), SIMD2(u + 0.0012, side), SIMD2(u - 0.0006, end), SIMD2(u + 0.0006, end)]
            indices += [index, index + 1, index + 2, index + 1, index + 3, index + 2]
        } }
        fringeVertices = [SCNVector3](repeating: SCNVector3Zero, count: fringeCoordinates.count)
        fringeElement = SCNGeometryElement(indices: indices, primitiveType: .triangles)
    }

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupScene()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setupScene() }
    deinit { timer?.invalidate() }

    private func setupScene() {
        prepareTopology()
        wantsLayer = true
        sceneView.frame = bounds
        sceneView.autoresizingMask = [.width, .height]
        sceneView.backgroundColor = .clear
        sceneView.scene = scene
        sceneView.antialiasingMode = .multisampling4X
        sceneView.rendersContinuously = false
        sceneView.isPlaying = false
        sceneView.autoenablesDefaultLighting = false
        sceneView.preferredFramesPerSecond = 120
        addSubview(sceneView)
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.zNear = 1; camera.zFar = 2000
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode
        let ambient = SCNLight(); ambient.type = .ambient; ambient.intensity = 300
        let ambientNode = SCNNode(); ambientNode.light = ambient; scene.rootNode.addChildNode(ambientNode)
        let light = SCNLight(); light.type = .omni; light.intensity = 850
        let lightNode = SCNNode(); lightNode.light = light
        lightNode.position = SCNVector3(-300, 900, 800)
        scene.rootNode.addChildNode(lightNode)
        for node in [faceNode, backNode, edgeNode, fringeNode] { scene.rootNode.addChildNode(node) }
        for material in [faceMaterial, backMaterial, edgeMaterial] {
            material.lightingModel = .lambert
            material.specular.contents = NSColor(white: 0.08, alpha: 1)
            material.diffuse.mipFilter = .linear
            material.diffuse.minificationFilter = .linear
            material.diffuse.magnificationFilter = .linear
            material.isDoubleSided = false
        }
        edgeMaterial.diffuse.contents = NSColor(calibratedRed: 0.47, green: 0.36, blue: 0.25, alpha: 1)
        let gripMaterial = SCNMaterial()
        gripMaterial.lightingModel = .constant
        gripMaterial.diffuse.contents = NSColor.white.withAlphaComponent(0.75)
        for _ in 0..<4 {
            let sphere = SCNSphere(radius: 2.2); sphere.segmentCount = 8; sphere.materials = [gripMaterial]
            let node = SCNNode(geometry: sphere); scene.rootNode.addChildNode(node); gripNodes.append(node)
        }
        initialized = true
        synchronizeAppearance()
        updateSurface()
    }

    override func layout() {
        super.layout()
        guard initialized, layoutSize != bounds.size else { return }
        fringeStrandCount = 0
        layoutSize = bounds.size
        synchronizeAppearance()
        updateSurface()
    }

    private func synchronizeAppearance() {
        let aspect: CGFloat = 1.55 // Resizing reuses material maps instead of repainting them.
        let p = Preferences.shared
        let modified: TimeInterval
        if p.style == .custom, let path = p.customImagePath,
           let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let date = attrs[.modificationDate] as? Date { modified = date.timeIntervalSinceReferenceDate }
        else { modified = 0 }
        let key = "\(p.style.rawValue)|\(p.customImagePath ?? "")|\(modified)"
        if key != textureKey {
            textureKey = key
            faceMaterial.diffuse.contents = RugTexture.image(style: p.style, customPath: p.customImagePath, aspect: aspect)
            backMaterial.diffuse.contents = RugTexture.image(style: p.style, customPath: nil, aspect: aspect, back: true)
        }
        for node in [faceNode, backNode, edgeNode, fringeNode] + gripNodes { node.opacity = p.opacity }
        sceneView.needsDisplay = true
    }

    private func updateSurface() {
        guard initialized, bounds.width > 26, bounds.height > 26 else { return }
        SCNTransaction.begin(); SCNTransaction.disableActions = true
        cameraNode.position = SCNVector3(Float(bounds.midX), Float(bounds.midY), 1000)
        cameraNode.camera?.orthographicScale = Double(bounds.height / 2)
        cloth = RugCloth(size: SIMD2(Float(bounds.width - 26), Float(bounds.height - 26)),
                         lift: max(0, min(1, lift)), ripple: ripple, time: elapsed, sway: sway)
        let nx = RugCloth.columns, ny = RugCloth.rows
        for row in 0...ny {
            for column in 0...nx {
                let u = Float(column) / Float(nx), v = Float(row) / Float(ny)
                let p = cloth.point(u, v), n = cloth.normal(u, v)
                let i = row * (nx + 1) + column
                topVertices[i] = SCNVector3(p.x + 13, p.y + 13, p.z)
                bottomVertices[i] = SCNVector3(p.x + 13 - n.x * RugCloth.thickness, p.y + 13 - n.y * RugCloth.thickness, p.z - n.z * RugCloth.thickness)
                faceNormals[i] = SCNVector3(n.x, n.y, n.z)
                backNormals[i] = SCNVector3(-n.x, -n.y, -n.z)
            }
        }
        func surface(_ vertices: [SCNVector3], _ ns: [SCNVector3], _ element: SCNGeometryElement, _ material: SCNMaterial) -> SCNGeometry {
            let geometry = SCNGeometry(sources: [.init(vertices: vertices), .init(normals: ns), textureSource], elements: [element])
            geometry.materials = [material]; return geometry
        }
        faceNode.geometry = surface(topVertices, faceNormals, faceElement, faceMaterial)
        backNode.geometry = surface(bottomVertices, backNormals, backElement, backMaterial)
        // Topology and material maps are reused; only moving vertex buffers upload.
        for (i, index) in perimeter.enumerated() {
            edgeVertices[i * 2] = topVertices[index]; edgeVertices[i * 2 + 1] = bottomVertices[index]
        }
        let edge = SCNGeometry(sources: [.init(vertices: edgeVertices)], elements: [edgeElement])
        edgeMaterial.isDoubleSided = true; edge.materials = [edgeMaterial]; edgeNode.geometry = edge
        prepareFringe()
        for (i, uv) in fringeCoordinates.enumerated() {
            let p = cloth.point(uv.x, uv.y)
            fringeVertices[i] = SCNVector3(p.x + 13, p.y + 13, p.z - 0.6)
        }
        let fringe = SCNGeometry(sources: [.init(vertices: fringeVertices)], elements: [fringeElement])
        fringe.materials = [fringeMaterial]; fringeNode.geometry = fringe
        let grips: [(Float, Float)] = [(1 - 12 / cloth.size.x, 1 - 12 / cloth.size.y),
            (1 - 12 / cloth.size.x, 12 / cloth.size.y), (1 - 20 / cloth.size.x, 12 / cloth.size.y),
            (1 - 12 / cloth.size.x, 20 / cloth.size.y)]
        for (node, uv) in zip(gripNodes, grips) {
            let p = cloth.point(uv.0, uv.1), n = cloth.normal(uv.0, uv.1)
            node.position = SCNVector3(p.x + 13 + n.x * 2, p.y + 13 + n.y * 2, p.z + n.z * 2)
        }
        SCNTransaction.commit()
        liftAmount = CGFloat(lift) * min(bounds.width, bounds.height) * 0.58
        needsDisplay = true
        sceneView.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        synchronizeAppearance()
        context.clear(bounds)
        if Preferences.shared.showsShadow {
            let path = CGMutablePath()
            let samples = 64
            var points = [SIMD3<Float>]()
            for i in 0...samples { points.append(cloth.point(Float(i) / Float(samples), 0)) }
            for i in 1...samples { points.append(cloth.point(1, Float(i) / Float(samples))) }
            for i in (0..<samples).reversed() { points.append(cloth.point(Float(i) / Float(samples), 1)) }
            for i in (1..<samples).reversed() { points.append(cloth.point(0, Float(i) / Float(samples))) }
            for (i, p) in points.enumerated() {
                let point = CGPoint(x: CGFloat(p.x + 13 + p.z * 0.12), y: CGFloat(p.y + 13 - p.z * 0.16))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            context.saveGState()
            context.setShadow(offset: CGSize(width: 2, height: -3), blur: CGFloat(6 + lift * 11),
                              color: NSColor.black.withAlphaComponent(0.40 * Preferences.shared.opacity).cgColor)
            context.setFillColor(NSColor.black.withAlphaComponent(0.16 * Preferences.shared.opacity).cgColor)
            context.addPath(path); context.fillPath(); context.restoreGState()
        }
    }

    private func startAnimation() {
        guard timer == nil else { return }
        lastTick = CACurrentMediaTime()
        let fps = min(120, max(60, window?.screen?.maximumFramesPerSecond ?? 60))
        let timer = Timer(timeInterval: 1 / Double(fps), repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 0.001
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = CACurrentMediaTime(), dt = Float(min(0.05, now - lastTick))
        lastTick = now; elapsed += dt
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            lift = liftTarget; liftVelocity = 0; ripple = 0; sway = .zero
        } else {
            RugCloth.spring(value: &lift, velocity: &liftVelocity, target: liftTarget, dt: dt)
            ripple *= exp(-dt * 7)
            sway *= exp(-dt * 10)
        }
        updateSurface()
        if abs(lift - liftTarget) < 0.0006 && abs(liftVelocity) < 0.006 && abs(ripple) < 0.03 && simd_length(sway) < 0.03 {
            lift = liftTarget; liftVelocity = 0; ripple = 0; sway = .zero
            updateSurface(); timer?.invalidate(); timer = nil
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        lastScreenPoint = NSEvent.mouseLocation; startScreenPoint = lastScreenPoint
        isDragging = true
        window?.makeFirstResponder(self)
        if p.x > bounds.maxX - 45 && p.y < 45 { dragMode = .resize; NSCursor.resizeLeftRight.push() }
        else if p.x > bounds.maxX - 85 && p.y > bounds.maxY - 85 { dragMode = .lift; NSCursor.closedHand.push() }
        else { dragMode = .move; NSCursor.closedHand.push() }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - lastScreenPoint.x, dy = now.y - lastScreenPoint.y
        switch dragMode {
        case .move:
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x + dx, y: window.frame.origin.y + dy))
            sway = SIMD2(Float(max(-30, min(30, dx * 2))), Float(max(-30, min(30, dy * 2))))
            startAnimation()
        case .resize:
            let current = window.frame
            let width = max(280, current.width + dx), height = max(200, current.height - dy)
            window.setFrame(NSRect(x: current.minX, y: current.maxY - height, width: width, height: height), display: true)
        case .lift:
            // Pull inward in any direction. Diagonal inward motion supplies the
            // most travel; upward pulls also lift naturally instead of locking.
            let travelX = Float(startScreenPoint.x - now.x)
            let travelY = Float(startScreenPoint.y - now.y)
            let inward = max(travelX, travelY, (travelX + travelY) * 0.707, abs(travelY) * 0.55)
            liftTarget = max(0, min(1, inward / Float(min(bounds.width, bounds.height) * 0.48)))
            ripple = min(2.5, ripple + Float(hypot(dx, dy)) * 0.015)
            startAnimation()
        }
        lastScreenPoint = now
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging { NSCursor.pop() }; isDragging = false
        if dragMode == .lift { liftTarget = 0; ripple = max(ripple, lift * 4) }
        startAnimation()
        onGeometryChange?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 || event.keyCode == 36 {
            liftTarget = liftTarget > 0.1 ? 0 : 0.9
            startAnimation()
        } else { super.keyDown(with: event) }
    }

    /// Deterministic rendering for offscreen visual regression checks; no UI input.
    func renderSnapshot(size: NSSize, previewLift: Float = 0) -> NSImage {
        let previous = lift
        lift = previewLift
        updateSurface()
        defer { lift = previous; updateSurface() }
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene; renderer.pointOfView = cameraNode
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
    }
}
