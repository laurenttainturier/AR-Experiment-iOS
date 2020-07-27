//
//  ViewController.swift
//  AR Experiment - iOS
//
//  Created by Laurent Tainturier on 09/07/2020.
//  Copyright © 2020 Laurent Tainturier. All rights reserved.
//

import UIKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    // MARK: Properties
    @IBOutlet weak var sceneView: ARSCNView!
    
    var detectedPlanes: [String: SCNNode] = [:]
    var dominoes: [SCNNode] = []
    var previousDominoPosition: SCNVector3?
    let dominoColors: [UIColor] = [.red, .blue, .green, .yellow, .orange, .cyan, .magenta, .purple]
    
    // MARK: Actions
    @IBAction func startButtonPressed(_ sender: UIButton) {
        guard let firstDomino = dominoes.first else { return }
        
        let power: Float = 0.7
        
        firstDomino.physicsBody?.applyForce(
            SCNVector3Make(firstDomino.worldRight.x * power, firstDomino.worldRight.y * power, firstDomino.worldRight.z * power), asImpulse: true)
    }
    
    @IBAction func removeAllDominoes(_ sender: UIButton) {
        for domino in dominoes {
            domino.removeFromParentNode()
        }
        
        previousDominoPosition = nil
        dominoes = []
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.scene.physicsWorld.timeStep = 1/200
        addTapGestureToSceneView()
        addLights()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpSceneView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func setUpSceneView() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        
        sceneView.delegate = self
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        plane.firstMaterial?.colorBufferWriteMask = .init(rawValue: 0)
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        planeNode.rotation = SCNVector4Make(1, 0, 0, -Float.pi / 2.0)
        
        let box = SCNBox(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z), length: 0.001, chamferRadius: 0)
        
        planeNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
        node.addChildNode(planeNode)
        
        detectedPlanes[planeAnchor.identifier.uuidString] = planeNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        guard let planeNode = detectedPlanes[planeAnchor.identifier.uuidString] else { return }
        let planeGeometry = planeNode.geometry as! SCNPlane
        planeGeometry.width = CGFloat(planeAnchor.extent.x)
        planeGeometry.height = CGFloat(planeAnchor.extent.z)
        planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        
        let box = SCNBox(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z), length: 0.001, chamferRadius: 0)
        planeNode.physicsBody?.physicsShape = SCNPhysicsShape(geometry: box, options: nil)
    }
    
    func addLights() {
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 500
        directionalLight.castsShadow = true
        directionalLight.shadowMode = .deferred
        directionalLight.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        
        let directionalLightNode = SCNNode()
        directionalLightNode.light = directionalLight
        directionalLightNode.rotation = SCNVector4Make(1, 0, 0, -Float.pi / 3)
        
        sceneView.scene.rootNode.addChildNode(directionalLightNode)
        
        let ambientLight = SCNLight()
        ambientLight.intensity = 50
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        
        sceneView.scene.rootNode.addChildNode(ambientLightNode)
    }
    
    func addBox(x: Float = 0, y: Float = 0, z: Float = -0.2) {
        let box = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0)
        
        let boxNode = SCNNode()
        boxNode.geometry = box
        boxNode.position = SCNVector3(x, y, z)
        
        sceneView.scene.rootNode.addChildNode(boxNode)
    }
    
    func addTapGestureToSceneView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.didTap(withGestureRecognizer:)))
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(screenPanned))
        
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        sceneView.addGestureRecognizer(panGesture)
    }
    
    @objc func screenPanned(gesture: UIPanGestureRecognizer) {
        
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
        
        let location = gesture.location(in: sceneView)
        guard let hitTestResult = sceneView.hitTest(location, types: .existingPlane).first else { return }
        
        guard let previousPosition = previousDominoPosition else {
            self.previousDominoPosition = SCNVector3Make(
                hitTestResult.worldTransform.columns.3.x,
                hitTestResult.worldTransform.columns.3.y,
                hitTestResult.worldTransform.columns.3.z
            )
            return
        }
        
        let currentPosition = SCNVector3Make(
            hitTestResult.worldTransform.columns.3.x,
            hitTestResult.worldTransform.columns.3.y,
            hitTestResult.worldTransform.columns.3.z
        )
        
        let minimumDistanceBetweenDominoes: Float = 0.03
        let distance = distanceBetween(point1: previousPosition, andPoint2: currentPosition)
        if distance >= minimumDistanceBetweenDominoes {
            let dominoGeometry = SCNBox(width: 0.007, height: 0.06, length: 0.03, chamferRadius: 0.0)
            dominoGeometry.firstMaterial?.diffuse.contents = dominoColors.randomElement()
            
            var currentAngle: Float = pointPairToBearingDegrees(startingPoint: CGPoint(x: CGFloat(currentPosition.x), y: CGFloat(currentPosition.z)), secondPoint: CGPoint(x: CGFloat(previousPosition.x), y: CGFloat(previousPosition.z)))
            currentAngle *= .pi / 180
            
            let dominoNode = SCNNode(geometry: dominoGeometry)
            dominoNode.position = SCNVector3Make(currentPosition.x, currentPosition.y + 0.03, currentPosition.z)
            dominoNode.rotation = SCNVector4Make(0, 1, 0, -currentAngle)
            dominoNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            dominoNode.physicsBody?.mass = 2.0
            dominoNode.physicsBody?.friction = 0.8
            
            sceneView.scene.rootNode.addChildNode(dominoNode)
            dominoes.append(dominoNode)
            
            self.previousDominoPosition = currentPosition
        }
    }
    
    // Create or remove a box depending on its existence
    @objc func didTap(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation)
        guard let node = hitTestResults.first?.node else {
            // Show a new box
            let hitTestResultsWithFeaturesPoints = sceneView.hitTest(tapLocation, types: .featurePoint)
            if let hitTestResultWithFeaturesPoints = hitTestResultsWithFeaturesPoints.first {
                let translation = hitTestResultWithFeaturesPoints.worldTransform.translation
                addBox(x: translation.x, y: translation.y, z: translation.z)
            }
            return
        }
        node.removeFromParentNode()
    }
    
    func distanceBetween(point1: SCNVector3, andPoint2 point2: SCNVector3) -> Float {
        return hypotf(Float(point1.x - point2.x), Float(point1.z - point2.z))
    }
    
    func pointPairToBearingDegrees(startingPoint: CGPoint, secondPoint endingPoint: CGPoint) -> Float{
        let originPoint: CGPoint = CGPoint(x: startingPoint.x - endingPoint.x, y: startingPoint.y - endingPoint.y)
        let bearingRadians = atan2f(Float(originPoint.y), Float(originPoint.x))
        let bearingDegrees = bearingRadians * (180.0 / Float.pi)
        return bearingDegrees
    }
}

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        let translation = self.columns.3
        return SIMD3(translation.x, translation.y, translation.z)
    }
}

