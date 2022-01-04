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
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.queue.async {
                if let device = MTLCreateSystemDefaultDevice(),
                   let meshAnchors = self.arView.session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor }) {
                    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let filename = directory.appendingPathComponent("mesh.obj")
                    try? meshAnchors.save(to: filename, device: device)
                    let asset = MDLAsset(url: filename)
                    let scene = SCNScene(mdlAsset: asset)
                    
                    let cameraNode = SCNNode()
                    cameraNode.name = self.realTimeObjectName
                    cameraNode.camera = SCNCamera()
                   // cameraNode.position = .init(asset.boundingBox.maxBounds.z, 0, 0)
                    scene.rootNode.addChildNode(cameraNode)
                    
                    self.sceneView.scene = scene
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
            if let prev = previousTouch {
                let alert = UIAlertController(title: "Distance is \(distanceTravelled(between: prev, and: current))",
                                              message: nil, preferredStyle: .alert)
                alert.addAction(.init(title: "Hide", style: .default, handler: nil))
                self.present(alert, animated: true) {
                    self.previousTouch = nil
                }
            }
            previousTouch = current
            print(result.localCoordinates)
        }
    }
    
    func distanceTravelled(between v1: SCNVector3, and v2: SCNVector3) -> Float {
        let xDist = v1.x - v2.x
        let yDist = v1.y - v2.y
        let zDist = v1.z - v2.z
        func distanceTravelled(xDist: Float, yDist: Float, zDist: Float) -> Float{
            return sqrt((xDist*xDist)+(yDist*yDist)+(zDist*zDist))
        }
        return distanceTravelled(xDist: xDist, yDist: yDist, zDist: zDist)
    }

}

