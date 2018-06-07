//
//  ViewController.swift
//  ARKitCarGeolocation
//
//  Created by Esteban Herrera on 11/22/17.
//  Copyright © 2017 Esteban Herrera. All rights reserved.
//

import UIKit
import ARKit
import SpriteKit
import SceneKit
import CoreLocation
import PusherSwift

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var statusTextView: UITextView!
    
    //POI
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var annotations = [ARAnnotation]()
    
    
    
    // set anchor distances (m) for nearest and farthest
    let anchorDistNearest: Float = 1
    let anchorDistFarthest: Float = 4
    // set anchor heights (degrees) for nearest and farthest
    let anchorDegreesNearest: Double = 0
    let anchorDegreesFarthest: Double = 15
    
    let locationManager = CLLocationManager()
    var userLocation = CLLocation()
    
    var heading : Double! = 0.0
    var distance : Float! = 0.0 {
        didSet {
            setStatusText()
        }
    }
    var status: String! {
        didSet {
            setStatusText()
        }
    }
    
    var modelNode:SCNNode!
    let rootNodeName = "Car"
    
    var originalTransform:SCNMatrix4!
    
    let pusher = Pusher(
        key: "1ba5d4eeb10aa3690502",
        options: PusherClientOptions(
            authMethod: .inline(secret: "bff2538929f1884e5ab4"),
            host: .cluster("us2")
        )
    )
    
    var channel: PusherChannel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and node count
        // sceneView.showsFPS = true
        // sceneView.showsNodeCount = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        sceneView.overlaySKScene = SKScene()
        
        // Start location services
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
        // Set the initial status
        status = "Getting user location..."
        
        // Set a padding in the text view
        statusTextView.textContainerInset = UIEdgeInsetsMake(30.0, 10.0, 10.0, 0.0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    
    
    
    
    
    func activateARView() {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        sceneView.session.run(config)
    }
    
    // MARK: - POIs
    
    func getAndDisplayItemsAroundLocation(_ location: CLLocation, completion: @escaping (Int) -> Void) {
        
        let searchTerm = "bar"
        let loader = PlaceLoader()
        
        let anchorDistSpread = anchorDistFarthest - anchorDistNearest
        let anchorHeightSpread = anchorDegreesFarthest - anchorDegreesNearest
        
        loader.getStaticPOIsFor(location: location) { (resultPOIs, errMsg) in
            //loader.requestPOIsWithGoogleSearch(term: searchTerm, location: location) { (resultPOIs, errMsg) in
            if let err = errMsg {
                self.appDelegate.alertWithTitle("Error", message: err)
                completion(0)
            }
            else if let pois = resultPOIs {
                var poiNearest: Double = 0
                var poiFarthest: Double = 0
                // determine nearest and farthest poi
                for poi in pois {
                    let geometry = poi["geometry"] as? [String: Any]
                    let poiLoc = loader.getLocationFrom(dict: geometry!)!
                    let distanceMeters: Double = location.distance(from: poiLoc)
                    if distanceMeters > poiFarthest {
                        poiFarthest = distanceMeters
                    }
                    if poiNearest == 0 {
                        poiNearest = distanceMeters
                    }
                    else if distanceMeters < poiNearest {
                        poiNearest = distanceMeters
                    }
                }
                let annotRect = CGRect(x: 0, y: 0, width: 240, height: 73)
                let poiSpread = poiFarthest - poiNearest
                // create annotations
                for poi in pois {
                    // get properties from poi
                    let title = poi["name"] as! String
                    let geometry = poi["geometry"] as? [String: Any]
                    let poiLoc = loader.getLocationFrom(dict: geometry!)!
                    let distanceMeters: Double = location.distance(from: poiLoc)
                    let distance = loader.metersToRecognizableString(meters: distanceMeters)
                    let bearing = MatrixHelper.bearingBetween(startLocation: location, endLocation: poiLoc)
                    // calculate anchor distance and height from user based on actual distance
                    let anchorDist = (distanceMeters * Double(anchorDistSpread) / poiSpread) + Double(self.anchorDistNearest)
                    let anchorHeightDegrees = (distanceMeters * anchorHeightSpread / poiSpread) + self.anchorDegreesNearest
                    let angleMultiplier: Float = (bearing > 270 || bearing < 90) ? 1.0 : -1.0
                    let angleAdjust = Float(anchorHeightDegrees) * angleMultiplier
                    // transformation matrix for placing poi
                    let origin = MatrixHelper.translate(x: 0, y: 0, z: Float(anchorDist * -1))
                    let bearingTransform = MatrixHelper.rotateMatrixAroundY(degrees: bearing * -1, matrix: origin)
                    let transform = MatrixHelper.translateMatrixFromHorizon(degrees: angleAdjust, matrix: bearingTransform)
                    // anchor
                    let anchor = ARAnchor(transform: transform)
                    // create an append annotation
                    let annot = ARAnnotation(frame: annotRect, identifier: anchor.identifier, title: title)
                    annot.distanceText = distance.0
                    annot.distanceUnitsText = distance.1
                    let _ = annot.validateAndSetLocation(location: poiLoc) // not used here, but might be useful for handling tap on annotation
                    self.annotations.append(annot)
                    //print("add anchor for title: \(title) and id \(anchor.identifier), bearing: \(bearing)˚, distance: \(anchorDist)")
                    self.sceneView.session.add(anchor: anchor)
                }
                completion(pois.count)
                //                print(pois)
            }
            else {
                completion(0)
            }
        }
    }
    
    @objc func removeNodes() {
        sceneView.overlaySKScene?.enumerateChildNodes(withName: "poi", using: { (node, stop) in
            node.removeFromParent()
        })
    }
    
    // MARK: - ARSKViewDelegate
    
    func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? {
        // Create and configure a node for the anchor added to the view's session.
        let annots = annotations.filter {
            $0.identifier! == anchor.identifier
        }
        if annots.count > 0 {
            let annot = annots.first
            let image = annot?.getTooltipImage()
            let tooltip = SKTexture(image: image!)
            let sprite = SKSpriteNode(texture: tooltip)
            sprite.name = "poi"
            return sprite
        }
        return nil
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        if case .limited(let reason) = camera.trackingState {
            print("tracking state is limited: \(reason)")
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setStatusText() {
        var text = "Status: \(status!)\n"
        text += "Distance: \(String(format: "%.2f m", distance))"
        statusTextView.text = text
    }
    
    //MARK: - CLLocationManager
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            userLocation = location
            status = "Connecting to Pusher..."
            
            self.connectToPusher()
        }
    }

    //MARK: - Utility methods
    func connectToPusher() {
        // subscribe to channel and bind to event
        let channel = pusher.subscribe("private-channel")
        
        let _ = channel.bind(eventName: "client-new-location", callback: { (data: Any?) -> Void in
            if let data = data as? [String : AnyObject] {
                print(data)
                
                if let latitude = Double(data["latitude"] as! String),
                      let longitude = Double(data["longitude"] as! String),
                      let heading = Double(data["heading"] as! String)  {
                    self.status = "Bus' location received"
                    
                    self.heading = heading
                    self.updateLocation(latitude, longitude)
                }
            }
        })
        
        pusher.connect()
        status = "Waiting to receive bus route..."
    }
    
    func updateLocation(_ latitude : Double, _ longitude : Double) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        self.distance = Float(location.distance(from: self.userLocation))
        
        if self.modelNode == nil {
            let modelScene = SCNScene(named: "art.scnassets/Car.dae")!
            self.modelNode = modelScene.rootNode.childNode(withName: rootNodeName, recursively: true)!
            
            // Move model's pivot to its center in the Y axis
            let (minBox, maxBox) = self.modelNode.boundingBox
            self.modelNode.pivot = SCNMatrix4MakeTranslation(0, (maxBox.y - minBox.y)/2, 0)
            
            // Save original transform to calculate future rotations
            self.originalTransform = self.modelNode.transform
            
            // Position the model in the correct place
            positionModel(location)
            
            // Add the model to the scene
            sceneView.scene.rootNode.addChildNode(self.modelNode)
            
            // Create arrow from the emoji
            let arrow = makeBillboardNode("⬇️".image()!)
            // Position it on top of the car
            arrow.position = SCNVector3Make(0, 4, 0)
            // Add it as a child of the car model
            self.modelNode.addChildNode(arrow)
        } else {
            // Begin animation
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.0
            
            // Position the model in the correct place
            positionModel(location)
            
            // End animation
            SCNTransaction.commit()
        }
    }
    
    func positionModel(_ location: CLLocation) {
        // Rotate node
        self.modelNode.transform = rotateNode(Float(-1 * (self.heading - 180).toRadians()), self.originalTransform)
        
        // Translate node
        self.modelNode.position = translateNode(location)
        
        // Scale node
        self.modelNode.scale = scaleNode(location)
    }
    
    func rotateNode(_ angleInRadians: Float, _ transform: SCNMatrix4) -> SCNMatrix4 {
        let rotation = SCNMatrix4MakeRotation(angleInRadians, 0, 1, 0)
        return SCNMatrix4Mult(transform, rotation)
    }
    
    func translateNode (_ location: CLLocation) -> SCNVector3 {
        let locationTransform = transformMatrix(matrix_identity_float4x4, userLocation, location)
        return positionFromTransform(locationTransform)
    }
    
    func scaleNode (_ location: CLLocation) -> SCNVector3 {
        let scale = max( min( Float(1000/distance), 1.5 ), 3 )
        print(scale)
        return SCNVector3(x: scale, y: scale, z: scale)
    }
    
    func positionFromTransform(_ transform: simd_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
    
    func transformMatrix(_ matrix: simd_float4x4, _ originLocation: CLLocation, _ driverLocation: CLLocation) -> simd_float4x4 {
        let bearing = bearingBetweenLocations(userLocation, driverLocation)
        let rotationMatrix = rotateAroundY(matrix_identity_float4x4, Float(bearing))
        
        
        // third position was 'distance', now hard-coded to -100
        let position = vector_float4(0.0, 0.0, -100, 0.0)
        print(position)
        let translationMatrix = getTranslationMatrix(matrix_identity_float4x4, position)
        print(translationMatrix)
        
        let transformMatrix = simd_mul(rotationMatrix, translationMatrix)
        
        return simd_mul(matrix, transformMatrix)
    }
    
    func getTranslationMatrix(_ matrix: simd_float4x4, _ translation : vector_float4) -> simd_float4x4 {
        var matrix = matrix
        matrix.columns.3 = translation
        return matrix
    }
    
    func rotateAroundY(_ matrix: simd_float4x4, _ degrees: Float) -> simd_float4x4 {
        var matrix = matrix
        
        matrix.columns.0.x = cos(degrees)
        matrix.columns.0.z = -sin(degrees)
        
        matrix.columns.2.x = sin(degrees)
        matrix.columns.2.z = cos(degrees)
        return matrix.inverse
    }
    
    func bearingBetweenLocations(_ originLocation: CLLocation, _ driverLocation: CLLocation) -> Double {
        let lat1 = originLocation.coordinate.latitude.toRadians()
        let lon1 = originLocation.coordinate.longitude.toRadians()
        
        let lat2 = driverLocation.coordinate.latitude.toRadians()
        let lon2 = driverLocation.coordinate.longitude.toRadians()
        
        let longitudeDiff = lon2 - lon1
        
        let y = sin(longitudeDiff) * cos(lat2);
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(longitudeDiff);
        
        return atan2(y, x)
    }
    
    func makeBillboardNode(_ image: UIImage) -> SCNNode {
        let plane = SCNPlane(width: 10, height: 10)
        plane.firstMaterial!.diffuse.contents = image
        let node = SCNNode(geometry: plane)
        node.constraints = [SCNBillboardConstraint()]
        return node
    }

}

