//
//  ARCameraView.swift
//  Live Mesh
//
//  Created by Indrajit Chavda on 12/10/21.
//

import RealityKit
import ARKit
import SceneKit
import SceneKit.ModelIO

let has_lidar_camera : Bool = {
    if #available(iOS 13.4, *) {
        return ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    } else {
        return false
    }
}()

class ARCameraView: UIViewController {
    
    private var timer: Timer?
    private let realTimeObjectName = "realtime.property"
    var previousTouch: SCNVector3?
    
    lazy var sceneView: SCNView = {
        let scene = SCNView()
        scene.backgroundColor = .white.withAlphaComponent(0.5)
        scene.alpha = 0
        scene.allowsCameraControl = true
        scene.cameraControlConfiguration.allowsTranslation = false
        scene.autoenablesDefaultLighting = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.didTapOnSceneView))
        scene.addGestureRecognizer(tap)
        return scene
    }()
    
    lazy var buttonExportScan: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Export Scan", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 15)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.addTarget(self, action: #selector(self.buttonExportScanClicked),
                         for: .touchUpInside)
        button.layer.cornerRadius = 6
        return button
    }()
    
    lazy var configuration:ARWorldTrackingConfiguration = {
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.environmentTexturing = .automatic
        config.planeDetection = [.horizontal,
                                 .vertical]
        return config
    }()
    
    lazy var arView: ARView = {
        let view = ARView()
        view.environment.sceneUnderstanding.options = []
        view.environment.sceneUnderstanding.options.insert(.occlusion)
        view.environment.sceneUnderstanding.options.insert(.physics)
        view.debugOptions.insert(.showSceneUnderstanding)
        view.renderOptions = [.disablePersonOcclusion,
                              .disableDepthOfField,
                              .disableMotionBlur]
        view.automaticallyConfigureSession = false
        return view
    }()
    
    lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.text = "Only LiDAR supported devices can scan the LiDAR mesh."
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.numberOfLines = 0
        label.textColor = .black
        label.textAlignment = .center
        return label
    }()
    
    lazy var coachingOverlay = ARCoachingOverlayView()
    
    let queue = DispatchQueue(label: "private_queue")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
            UIView.animate(withDuration: 0.2) {
                self?.sceneView.alpha = 1
            } completion: { finished in
                if finished {
                    self?.startLiveMesh()
                }
            }
        }
    }
    
    private func setUpViews() {
        self.view.backgroundColor = .white
        if has_lidar_camera {
            self.view.addSubview(arView)
            self.view.addSubview(buttonExportScan)
            
            buttonExportScan.setHeightAndWidth(height: 45, width: 150)
            buttonExportScan.setCenterX()
            buttonExportScan.setBottom(with: self.view.safeAreaLayoutGuide.bottomAnchor,
                                       constant: -40)
            
            arView.setFullOnSuperView(safeArea: false)
            arView.addSubview(coachingOverlay)
            coachingOverlay.setFullOnSuperView()
            
            arView.session.run(configuration)
            coachingOverlay.session = arView.session
            coachingOverlay.delegate = self
            
            self.view.addSubview(sceneView)
            sceneView.setHeightAndWidth(height: 300, width: 300)
            sceneView.setTop(with: self.view.safeAreaLayoutGuide.topAnchor,
                             constant: -5)
            sceneView.setRight(with: self.view.safeAreaLayoutGuide.rightAnchor,
                               constant: -10)
            
        } else {
            self.view.addSubview(errorLabel)
            errorLabel.setFullOnSuperView(withSpacing: 10)
        }
    }
    
    private func startLiveMesh() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.queue.async {
                if let device = MTLCreateSystemDefaultDevice(),
                   let meshAnchors = self.arView.session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor }) {
                    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let filename = directory.appendingPathComponent("mesh.obj")
                    try? meshAnchors.save(to: filename, device: device)
                    let asset = MDLAsset(url: filename)
                    let scene = SCNScene(mdlAsset: asset)
                    if let object = asset.object(at: 0) as? MDLMesh {
                        let modelNode = SCNNode(mdlObject: object)
                        scene.rootNode.addChildNode(modelNode)
                        //modelNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 1)))
                        self.sceneView.scene = scene
                    }
                    
                }
            }
        }
    }
    
    @objc func buttonExportScanClicked() {
        self.timer?.invalidate()
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        guard let meshAnchors = arView.session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor }) else { return }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = directory.appendingPathComponent("mesh.obj")
        do {
            try meshAnchors.save(to: filename, device: device)
            let activityViewController = UIActivityViewController(activityItems: [filename],
                                                                  applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.buttonExportScan
            self.present(activityViewController,
                         animated: true,
                         completion: nil)
        } catch {
            print("Unable to save mesh")
        }
    }
    
    @objc func didTapOnSceneView(sender: UITapGestureRecognizer) {
        let location = sender.location(in: sceneView)
        let results = sceneView.hitTest(location, options: [SCNHitTestOption.searchMode : 1])
        guard sender.state == .ended else { return }
        if let result = results.first {
            let current = result.localCoordinates
            let dot = SCNNode(geometry: SCNBox(width: 0.05,
                                               height: 0.05,
                                               length: 0.05,
                                               chamferRadius: 0.05))
            dot.position = current
            self.sceneView.scene?.rootNode.addChildNode(dot)
            if let prev = previousTouch, let scene = self.sceneView.scene {
                let line = lineBetweenNodeA(positionA: current, positionB: prev, inScene: scene)
                scene.rootNode.addChildNode(line)
                self.add(text: "\(distanceTravelled(between: current, and: prev))",
                         on: scene.rootNode,
                         atPosition: line.position)
            }
            previousTouch = current
            
        }
    }
    
    func distanceTravelled(between positionA: SCNVector3, and positionB: SCNVector3) -> Float {
        let vector = SCNVector3(positionA.x - positionB.x,
                                positionA.y - positionB.y,
                                positionA.z - positionB.z)
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }
    
    func lineBetweenNodeA(positionA: SCNVector3,
                          positionB: SCNVector3,
                          inScene: SCNScene) -> SCNNode {
        let midPosition = SCNVector3 (x:(positionA.x + positionB.x) / 2,
                                      y:(positionA.y + positionB.y) / 2,
                                      z:(positionA.z + positionB.z) / 2)
        
        let lineGeometry = SCNCylinder()
        lineGeometry.radius = 0.015
        lineGeometry.height = CGFloat(distanceTravelled(between: positionA, and: positionB))
        lineGeometry.radialSegmentCount = 5
        lineGeometry.firstMaterial!.diffuse.contents = UIColor.white
        
        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.position = midPosition
        lineNode.look(at: positionB,
                      up: inScene.rootNode.worldUp,
                      localFront: lineNode.worldUp)
        return lineNode
    }
    
    func add(text string: String, on node: SCNNode,
             atPosition: SCNVector3) {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 10, width: 50, height: 25)
        layer.backgroundColor = UIColor.white.cgColor
        
        let textLayer = CATextLayer()
        textLayer.frame = layer.bounds
        textLayer.fontSize = layer.bounds.size.height/3
        textLayer.string = string
        textLayer.alignmentMode = .center
        textLayer.foregroundColor = UIColor.black.cgColor
        textLayer.display()
        layer.addSublayer(textLayer)
        
        let geometry = SCNBox(width: 0.2,
                              height: 0.05,
                              length: 0.2,
                              chamferRadius: 0.0)
        
        geometry.firstMaterial?.locksAmbientWithDiffuse = true
        geometry.firstMaterial?.diffuse.contents = layer
        
        let geometryNode = SCNNode(geometry: geometry)
        geometryNode.position = atPosition
        
        node.addChildNode(geometryNode)
    }
    
}


