import UIKit
import RealityKit
import ARKit
import UniformTypeIdentifiers

class ViewController: UIViewController {
    
    var arView: ARView!
    var defaultModels: [Entity] = []
    var currentModelIndex = 0
    var modelNameLabel: UILabel!
    var modelDropdownButton: UIButton!
    var previewEntity: Entity?
    var previewAnchor: AnchorEntity?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupARView()
        setupDefaultModels()
        setupUI()
        setupSwipeGestures()
    }
    
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        // Add environment lighting for better visibility
        arView.environment.lighting.intensityExponent = 2.0
        
        // For simulator testing, add a light gray background
        #if targetEnvironment(simulator)
        arView.environment.background = .color(.lightGray)
        
        // Add a camera anchor for simulator
        let cameraAnchor = AnchorEntity(world: [0, 0, 0])
        arView.scene.addAnchor(cameraAnchor)
        
        // Add directional light for better visibility
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1000
        directionalLight.light.color = .white
        directionalLight.look(at: [0, -1, 0], from: [0, 1, 0], relativeTo: nil)
        cameraAnchor.addChild(directionalLight)
        #else
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        #endif
        
    }
    
    private func setupDefaultModels() {
        // Create cube model
        let cubeMesh = MeshResource.generateBox(size: 0.2)
        let cubeMaterial = SimpleMaterial(color: .systemBlue, roughness: 0.5, isMetallic: false)
        let cubeEntity = ModelEntity(mesh: cubeMesh, materials: [cubeMaterial])
        cubeEntity.name = "Cube"
        
        // Create sphere model
        let sphereMesh = MeshResource.generateSphere(radius: 0.1)
        let sphereMaterial = SimpleMaterial(color: .systemRed, roughness: 0.3, isMetallic: false)
        let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
        sphereEntity.name = "Sphere"
        
        // Create box model with different dimensions
        let boxMesh = MeshResource.generateBox(size: [0.16, 0.24, 0.08])
        let boxMaterial = SimpleMaterial(color: .systemGreen, roughness: 0.4, isMetallic: false)
        let boxEntity = ModelEntity(mesh: boxMesh, materials: [boxMaterial])
        boxEntity.name = "Box"
        
        // Create large sphere model
        let largeSphereMesh = MeshResource.generateSphere(radius: 0.15)
        let largeSphereMaterial = SimpleMaterial(color: .systemPurple, roughness: 0.2, isMetallic: false)
        let largeSphereEntity = ModelEntity(mesh: largeSphereMesh, materials: [largeSphereMaterial])
        largeSphereEntity.name = "Large Sphere"
        
        defaultModels = [cubeEntity, sphereEntity, boxEntity, largeSphereEntity]
        
        // Set the first model as current
        if !defaultModels.isEmpty {
            currentModelEntity = defaultModels[currentModelIndex]
            print("Debug: Created \(defaultModels.count) models")
            print("Debug: Current model is \(currentModelEntity?.name ?? "nil")")
            updatePreview()
        }
    }
    
    private func updatePreview() {
        // Remove existing preview
        previewEntity?.removeFromParent()
        previewAnchor?.removeFromParent()
        
        guard let modelEntity = currentModelEntity else { return }
        
        // Create preview anchor - move it further back since objects are bigger
        previewAnchor = AnchorEntity(world: [0, 0, -0.5])
        
        // Clone the current model for preview
        previewEntity = modelEntity.clone(recursive: true)
        
        // Add a slight rotation animation to the preview
        if let preview = previewEntity as? ModelEntity {
            preview.position = [0, 0, 0]
        }
        
        previewAnchor?.addChild(previewEntity!)
        arView.scene.addAnchor(previewAnchor!)
    }
    
    private func setupSwipeGestures() {
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        leftSwipe.direction = .left
        arView.addGestureRecognizer(leftSwipe)
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        rightSwipe.direction = .right
        arView.addGestureRecognizer(rightSwipe)
    }
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard !defaultModels.isEmpty else { return }
        
        if gesture.direction == .left {
            currentModelIndex = (currentModelIndex + 1) % defaultModels.count
        } else if gesture.direction == .right {
            currentModelIndex = (currentModelIndex - 1 + defaultModels.count) % defaultModels.count
        }
        
        currentModelEntity = defaultModels[currentModelIndex]
        updateModelNameLabel()
        updatePreview()
    }
    
    private func updateModelNameLabel() {
        if let modelName = currentModelEntity?.name {
            modelDropdownButton?.setTitle("\(modelName) ▼", for: .normal)
            modelDropdownButton?.menu = createModelMenu()
        }
    }
    
    private func createModelMenu() -> UIMenu {
        let actions = defaultModels.enumerated().map { index, model in
            UIAction(title: model.name, 
                     state: index == currentModelIndex ? .on : .off) { _ in
                self.currentModelIndex = index
                self.currentModelEntity = self.defaultModels[index]
                self.updateModelNameLabel()
                self.updatePreview()
            }
        }
        return UIMenu(children: actions)
    }
    
    private func setupUI() {
        // Load button (now at top)
        let loadButton = UIButton(type: .system)
        loadButton.setTitle("Load USDZ", for: .normal)
        loadButton.backgroundColor = UIColor.systemBlue
        loadButton.setTitleColor(.white, for: .normal)
        loadButton.layer.cornerRadius = 8
        loadButton.translatesAutoresizingMaskIntoConstraints = false
        loadButton.addTarget(self, action: #selector(loadUSDZButtonTapped), for: .touchUpInside)
        
        view.addSubview(loadButton)
        
        // Model dropdown button (now at bottom)
        let modelButton = UIButton(type: .system)
        modelButton.setTitle("Cube ▼", for: .normal)
        modelButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        modelButton.setTitleColor(.white, for: .normal)
        modelButton.layer.cornerRadius = 8
        modelButton.translatesAutoresizingMaskIntoConstraints = false
        modelButton.showsMenuAsPrimaryAction = true
        modelButton.menu = createModelMenu()
        
        // Store reference to update menu later
        modelNameLabel = modelButton.titleLabel
        modelDropdownButton = modelButton
        
        view.addSubview(modelButton)
        
        NSLayoutConstraint.activate([
            // Load button constraints (now at top)
            loadButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            loadButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadButton.widthAnchor.constraint(equalToConstant: 150),
            loadButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Model dropdown button constraints (now at bottom)
            modelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            modelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            modelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            modelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func loadUSDZButtonTapped() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.usdz])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
    
    
    private func loadUSDZ(from url: URL) {
        do {
            let entity = try Entity.loadModel(contentsOf: url)
            
            entity.setScale(SIMD3<Float>(repeating: 0.1), relativeTo: nil)
            entity.name = url.lastPathComponent
            
            // Add to models array and select it
            defaultModels.append(entity)
            currentModelIndex = defaultModels.count - 1
            currentModelEntity = entity
            updateModelNameLabel()
            updatePreview()
            
            showAlert(title: "Success", message: "USDZ file loaded successfully.")
        } catch {
            showAlert(title: "Error", message: "Failed to load USDZ file: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private var currentModelEntity: Entity?
}

extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            loadUSDZ(from: url)
        }
    }
}

extension UTType {
    static let usdz = UTType(filenameExtension: "usdz")!
}
