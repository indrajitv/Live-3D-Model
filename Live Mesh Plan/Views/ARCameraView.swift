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
    lazy var coachingOverlay = ARCoachingOverlayView()

    lazy var buttonFinish: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Finish", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 15)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.addTarget(self, action: #selector(self.buttonFinishClicked),
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

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
    }
    
    private func setUpViews() {
        self.view.backgroundColor = .white
        if has_lidar_camera {
            self.view.addSubview(arView)
            self.view.addSubview(buttonFinish)
            
            buttonFinish.setHeightAndWidth(height: 45, width: 150)
            buttonFinish.setCenterX()
            buttonFinish.setBottom(with: self.view.safeAreaLayoutGuide.bottomAnchor,
                                       constant: -40)
            
            arView.setFullOnSuperView(safeArea: false)
            arView.addSubview(coachingOverlay)
            coachingOverlay.setFullOnSuperView()
            
            arView.session.run(configuration)
            coachingOverlay.session = arView.session
            coachingOverlay.delegate = self
        } else {
            self.view.addSubview(errorLabel)
            errorLabel.setFullOnSuperView(withSpacing: 10)
        }
        
        self.buttonFinish.isHidden = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.buttonFinish.isHidden = false
        }
    }
    
    @objc func buttonFinishClicked() {
        guard let meshAnchors = self.arView.session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor }) else { return }
        let objectExplorerView = ObjectExplorerView(meshAnchors: meshAnchors)
        let navigation = UINavigationController(rootViewController: objectExplorerView)
        self.present(navigation, animated: true, completion: nil)
    }
    
}


