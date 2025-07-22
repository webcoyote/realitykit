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
    var cameraDistance: Float = 0.5
    var cameraRotation: Float = 0
    var cameraElevation: Float = 0
    var cameraEntity: PerspectiveCamera?
    var modelBounds: BoundingBox = BoundingBox(min: .zero, max: .zero)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupARView()
        loadBundledModels()
        setupDefaultModels()
        setupUI()
        setupSwipeGestures()
        
        // Update UI to show the first model
        updateModelNameLabel()
        updatePreview()
    }
    
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        // Use non-AR camera mode for better control
        arView.cameraMode = .nonAR
        
        // Add environment lighting for better visibility
        arView.environment.lighting.intensityExponent = 2.0
        arView.environment.background = .color(.lightGray)
        
        // Create and add camera
        cameraEntity = PerspectiveCamera()
        cameraEntity?.camera.fieldOfViewInDegrees = 60
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(cameraEntity!)
        arView.scene.addAnchor(cameraAnchor)
        
        // Add directional light for better visibility
        let lightAnchor = AnchorEntity(world: [0, 1, 0])
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1000
        directionalLight.light.color = .white
        directionalLight.look(at: [0, 0, 0], from: [0, 1, 0], relativeTo: nil)
        lightAnchor.addChild(directionalLight)
        arView.scene.addAnchor(lightAnchor)
    }
    
    private func loadBundledModels() {
        print("Loading bundled models...")
        
        // Load cat.usdz from Assets.xcassets
        if let catAsset = NSDataAsset(name: "cat") {
            print("Found cat asset")
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("cat.usdz")
            do {
                try catAsset.data.write(to: tempURL)
                let catEntity = try Entity.loadModel(contentsOf: tempURL)
                catEntity.name = "Cat"
                // Scale the model appropriately
                catEntity.scale = SIMD3<Float>(repeating: 0.1)
                defaultModels.append(catEntity)
                print("Successfully loaded cat.usdz")
                try? FileManager.default.removeItem(at: tempURL)
            } catch {
                print("Failed to load cat.usdz: \(error)")
            }
        } else {
            print("Cat asset not found in Assets.xcassets")
        }
        
        // Load cosmonaut.reality
        if let cosmonautURL = Bundle.main.url(forResource: "cosmonaut", withExtension: "reality") {
            print("Found cosmonaut.reality at: \(cosmonautURL)")
            do {
                let cosmonautEntity = try Entity.load(contentsOf: cosmonautURL)
                cosmonautEntity.name = "Cosmonaut"
                // Scale the model appropriately
                cosmonautEntity.scale = SIMD3<Float>(repeating: 0.1)
                defaultModels.append(cosmonautEntity)
                print("Successfully loaded cosmonaut.reality")
            } catch {
                print("Failed to load cosmonaut.reality: \(error)")
            }
        } else {
            print("Cosmonaut.reality not found in bundle")
        }
        
        print("Total models after loading bundled: \(defaultModels.count)")
    }
    
    private func setupDefaultModels() {
        // Create cube model
        let cubeMesh = MeshResource.generateBox(size: 0.1)
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
        
        defaultModels.append(contentsOf: [cubeEntity, sphereEntity, boxEntity])
        
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
        
        // Create preview anchor at origin
        previewAnchor = AnchorEntity(world: [0, 0, 0])
        
        // Clone the current model for preview
        previewEntity = modelEntity.clone(recursive: true)
        
        // Calculate bounding box and center the model
        if let preview = previewEntity {
            let bounds = preview.visualBounds(relativeTo: nil)
            modelBounds = bounds
            let center = (bounds.min + bounds.max) / 2
            
            // Offset the model so its center is at origin
            preview.position = -center
            
            // Calculate appropriate camera distance based on model size
            let size = bounds.max - bounds.min
            let maxDimension = max(size.x, max(size.y, size.z))
            cameraDistance = maxDimension * 2.16  // 1.8 * 1.2 = 2.16 (20% further back)
        }
        
        previewAnchor?.addChild(previewEntity!)
        arView.scene.addAnchor(previewAnchor!)
        
        // Update camera position to look at the model
        updateCameraPosition()
    }
    
    private func setupSwipeGestures() {
        // Use pan gesture for continuous rotation
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        arView.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        arView.addGestureRecognizer(pinchGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: arView)
        let rotationSpeed: Float = 0.01
        
        cameraRotation += Float(translation.x) * rotationSpeed
        cameraElevation -= Float(translation.y) * rotationSpeed
        
        // Clamp elevation to prevent flipping
        cameraElevation = max(min(cameraElevation, Float.pi / 2.5), -Float.pi / 2.5)
        
        gesture.setTranslation(.zero, in: arView)
        updateCameraPosition()
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            guard let entity = previewEntity else { return }
            
            let scale = Float(gesture.scale)
            entity.scale *= SIMD3<Float>(repeating: scale)
            
            // Clamp scale to reasonable limits
            let minScale: Float = 0.01
            let maxScale: Float = 10.0
            entity.scale = SIMD3<Float>(
                repeating: min(max(entity.scale.x, minScale), maxScale)
            )
            
            gesture.scale = 1.0
        }
    }
    
    private func updateCameraPosition() {
        guard let camera = cameraEntity else { return }
        
        // Calculate camera position with both horizontal rotation and vertical elevation
        let horizontalDistance = cos(cameraElevation) * cameraDistance
        let x = sin(cameraRotation) * horizontalDistance
        let y = sin(cameraElevation) * cameraDistance
        let z = cos(cameraRotation) * horizontalDistance
        let cameraPosition = SIMD3<Float>(x, y, z)
        
        // Update camera position
        camera.position = cameraPosition
        
        // Make camera look at origin
        camera.look(at: [0, 0, 0], from: cameraPosition, relativeTo: nil)
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
