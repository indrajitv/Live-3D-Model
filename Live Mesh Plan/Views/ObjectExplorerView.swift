//
//  ObjectExplorerView.swift
//  Live Mesh Plan
//
//  Created by _indrajit on 11/01/22.
//

import SceneKit
import ARKit

class ObjectExplorerView: UIViewController {
    var previousTouch: SCNVector3?
    let meshAnchors: [ARMeshAnchor]
    
    lazy var sceneView: SCNView = {
        let scene = SCNView()
        scene.backgroundColor = .white.withAlphaComponent(0.5)
        scene.allowsCameraControl = true
        scene.cameraControlConfiguration.allowsTranslation = false
        scene.autoenablesDefaultLighting = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.didTapOnSceneView))
        scene.addGestureRecognizer(tap)
        return scene
    }()
    
    init(meshAnchors: [ARMeshAnchor]) {
        self.meshAnchors = meshAnchors
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpViews()
        loadMesh()
    }
    
    private func setUpViews() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.didTapSendButtonFromNavigation))
        
        self.view.backgroundColor = .white
        self.view.addSubview(sceneView)
        sceneView.setFullOnSuperView(withSpacing: 15)
    }
    
    private func loadMesh() {
        if let device = MTLCreateSystemDefaultDevice() {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let filename = directory.appendingPathComponent("mesh.obj")
            try? self.meshAnchors.save(to: filename, device: device)
            let asset = MDLAsset(url: filename)
            let scene = SCNScene(mdlAsset: asset)
            if let object = asset.object(at: 0) as? MDLMesh {
                let modelNode = SCNNode(mdlObject: object)
                scene.rootNode.addChildNode(modelNode)
                self.sceneView.scene = scene
            }
        }
    }
    
    @objc private func didTapSendButtonFromNavigation() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = directory.appendingPathComponent("mesh.obj")
        do {
            try meshAnchors.save(to: filename, device: device)
            let activityViewController = UIActivityViewController(activityItems: [filename],
                                                                  applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view
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
