//
//  ViewController.swift
//  MP4
//
//  Created by Oti Oritsejafor on 10/28/19.
//  Copyright © 2019 Magloboid. All rights reserved.
//

import UIKit
import MapKit
import Mapbox
import CoreLocation

class MapViewController: UIViewController {

    // MARK: Outlets
    @IBOutlet weak var mapView: MGLMapView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var currentSpeedLabel: UILabel!
    @IBOutlet weak var averageSpeedLabel: UILabel!
    @IBOutlet weak var caloriesBurnedLabel: UILabel!
    
    // MARK: Location and Time
    var run: Run?
    private var seconds: Int = 0
    private var timer: Timer?
    private var lineTimer: Timer?
    private var distance = Measurement(value: 0, unit: UnitLength.meters)
    private var paces: [Double] = []
    private var calories: [Double] = []
    private var locationList: [CLLocation] = []
    private var coordinateList: [CLLocationCoordinate2D] = []
    var polylineSource: MGLShapeSource?
    var userLocation: CLLocation?
    
    var coordinates = CLLocationCoordinate2D()
    fileprivate let locationManager: CLLocationManager = CLLocationManager()
    let current_loc = MGLPointAnnotation()
    
    // MARK: Counters
    var mode = 0
    var currentIndex = 1
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpButton()
        let onBoarded = UserDefaults.standard.bool(forKey: "Onboarded")
        if !(onBoarded) {
            presentCustomAlertOnMainThread(title: "Get Started!", message: "Please input your weight (lbs) to estimate your calories burned each run", buttonTitle: "Done")
        }
        //configureUI()
        
        enableLocationServices()
        setUpLocation()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func startTapped() {
        startRun()
    }
    
    func configureUI() {
        let label = UILabel()
        label.textColor = UIColor.black
        label.text = "Past Runs"
       
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(customView: label)
    }
    
    private func saveRun() {
        let averagePace = paces.average()
        let newRun = Run(context: DataStack.context)
        newRun.distance = distance.value
        newRun.duration = Int16(seconds)
        newRun.timestamp = Date()
        newRun.averageSpeed = averagePace
        newRun.calories = calories.sum()
        //newRun. 
        
        for location in locationList {
            let locationObject = Location(context: DataStack.context)
            locationObject.latitude = location.coordinate.latitude
            locationObject.longitude = location.coordinate.longitude
            locationObject.timestamp = location.timestamp
            newRun.addToLocations(locationObject)
        }
        
        DataStack.saveContext()
        run = newRun
    }
    
    func setUpButton() {
        startButton.backgroundColor = .systemPurple//#colorLiteral(red: 0, green: 0.6711811423, blue: 0.9963676333, alpha: 1)
        startButton.layer.cornerRadius = 25.0
        startButton.tintColor = UIColor.white
        startButton.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.25).cgColor
        startButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        startButton.layer.shadowOpacity = 1.0
        startButton.layer.shadowRadius = 10.0
        startButton.layer.masksToBounds = false
    }
    
    func setUpLocation() {
        guard let _ = locationManager.location?.coordinate else {
            return
        }
        
        coordinates = (locationManager.location?.coordinate)!
        
        current_loc.coordinate = CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude)
        current_loc.title = "You"
        
        mapView.setCenter(CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude), zoomLevel: 15, animated: false)
        
        mapView.delegate = self
        mapView.addAnnotation(current_loc)
        
        locationManager.stopUpdatingLocation()
    }
    
    private func startLocationUpdates() {
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.startUpdatingLocation()
    }
    
    private func startRun() {
        if mode == 0 {
            startButton.backgroundColor = #colorLiteral(red: 1, green: 0.1248341114, blue: 0.1351750396, alpha: 1)
            startButton.setTitle("Stop", for: .normal)
            mode = 1
           
            mapView.userTrackingMode = .followWithHeading
            
            //mapView.removeAnnotation(current_loc)
            currentIndex = 1
            seconds = 0
            distance = Measurement(value: 0, unit: UnitLength.meters)
            calories.removeAll()
            locationList.removeAll()
            coordinateList.removeAll()
            
            updateDisplay()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.eachSecond()
            }
            startLocationUpdates()
            mapView.locationManager.startUpdatingLocation()
            mapView.locationManager.startUpdatingHeading()
            //animateLine()
            
        } else {
            presentEndAlert()
            startButton.backgroundColor = .systemPurple//#colorLiteral(red: 0, green: 0.6711811423, blue: 0.9963676333, alpha: 1)
            startButton.setTitle("Start Run", for: .normal)
            timer?.invalidate()
            locationManager.stopUpdatingLocation()
            
            mode = 0
            
            mapView.userTrackingMode = .none
            mapView.locationManager.stopUpdatingLocation()
            mapView.locationManager.stopUpdatingHeading()
            updateDisplay()
        }
    }
    
    private func animateLine() {
        if currentIndex > coordinateList.count {

            return
        }
        // Create a subarray of locations up to the current index.
        let newCoordinates = Array(coordinateList[0..<currentIndex])
        
        // Update our MGLShapeSource with the current locations.
        updatePolylineWithCoordinates(coordinates: newCoordinates)
        
        currentIndex += 1
    }
    
    func eachSecond() {
        seconds += 1
        updateDisplay()
        if currentIndex > coordinateList.count {
            return
        }
  
        let newCoordinates = Array(coordinateList[0..<currentIndex])
        
        self.updatePolylineWithCoordinates(coordinates: newCoordinates)
        currentIndex += 1
        
    }
    
    private func updateDisplay() {
        let formattedDistance = FormatDisplay.distance(distance)
        let formattedTime = FormatDisplay.time(seconds)
        let userWeight = UserDefaults.standard.integer(forKey: "Weight")
        //let formattedPace = FormatDisplay.pace(distance: distance,
                                         //      seconds: seconds,
                                         //      outputUnit: .kilometersPerHour)
        
        let pace = (distance.value/Double(seconds)) * 2.237
        paces.append(pace)
        //let avgSpeed = paces.sum() / Double(paces.count)
        let caloriesBurned = calculateBurned(avgSpeed: pace, bodyWeight: Double(userWeight))
        calories.append(caloriesBurned)
        
        self.distanceLabel.text = String("\(formattedDistance)".dropLast(3))
        self.timeLabel.text = "\(formattedTime)"
        self.currentSpeedLabel.text = "\(pace.rounded()) mi/h"
        let intCalories = Int(calories.sum().rounded())
        self.caloriesBurnedLabel.text = "\(intCalories) kcal"
        //self.averageSpeedLabel.text = "\(avgSpeed.rounded()) mi/h"
    }
    
    func calculateBurned(avgSpeed: Double, bodyWeight: Double) -> Double {
        var MET: Double
        switch avgSpeed {
        case _ where avgSpeed <= 4.0:
            MET = 5
        case _ where avgSpeed <= 5.0:
            MET = 8.3
        case _ where avgSpeed <= 5.2:
            MET = 9
        case _ where avgSpeed <= 6.0:
            MET = 9.8
        case _ where avgSpeed <= 6.7:
            MET = 10.5
        case _ where avgSpeed <= 7.0:
            MET = 11
        case _ where avgSpeed <= 7.5:
            MET = 11.5
        case _ where avgSpeed <= 8.0:
            MET = 11.8
        case _ where avgSpeed <= 8.6:
            MET = 12.3
        case _ where avgSpeed <= 9.0:
            MET = 12.8
        case _ where avgSpeed <= 9.5:
            MET = 13.7
        case _ where avgSpeed <= 10.0:
            MET = 14.5
        case _ where avgSpeed <= 11.0:
            MET = 16
        case _ where avgSpeed <= 12.0:
            MET = 19
        case _ where avgSpeed <= 13.0:
            MET = 19.8
        case _ where avgSpeed <= 14.0:
            MET = 23
        default:
            MET = 24
        }
        
        //print("MET is \(MET)")
        let final = (MET * (bodyWeight / 2.25) * 3.5) / 200.0
        
        return final/60.0
    }
    
    func presentEndAlert() {
        let alertController = UIAlertController(title: "Run Ended",
                                                message: "Do you want to save your run?",
                                                preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "No", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
            self.saveRun()
        })
        
        present(alertController, animated: true)
    }
    
    func updatePolylineWithCoordinates(coordinates: [CLLocationCoordinate2D]) {
        var mutableCoordinates = coordinates
        
        let polyline = MGLPolylineFeature(coordinates: &mutableCoordinates, count: UInt(mutableCoordinates.count))
        
        // Updating the MGLShapeSource’s shape will have the map redraw our polyline with the current coordinates.
        polylineSource?.shape = polyline
    }
    
    func addPolyline(to style: MGLStyle) {
        // Add an empty MGLShapeSource, we’ll keep a reference to this and add points to this later.
        let source = MGLShapeSource(identifier: "polyline", shape: .none, options: nil)
        style.addSource(source)
        polylineSource = source
        
        // Add a layer to style our polyline.
        let layer = MGLLineStyleLayer(identifier: "polyline", source: source)
        layer.lineJoin = NSExpression(forConstantValue: "round")
        layer.lineCap = NSExpression(forConstantValue: "round")
        layer.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.3647058904, green: 0.06666667014, blue: 0.9686274529, alpha: 1))
        
        
        // The line width should gradually increase based on the zoom level.
        layer.lineWidth = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
                                       [15: 1, 18: 20])
        style.addLayer(layer)
    }
    
}

extension MapViewController: CLLocationManagerDelegate {
    func enableLocationServices() {
        locationManager.delegate = self
        
        switch CLLocationManager.authorizationStatus() {
            
        case .notDetermined:
            print("DEBUG: Not Determined")
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            self.displayAlert(message: "Please enable location under app settings to use this app", action: "OK")
           // locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways:
            print("DEBUG: Auth Always")
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        case .authorizedWhenInUse:
            //locationManager.requestAlwaysAuthorization()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            print("DEBUG: Auth when in use")
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = manager.location
        
        for newLocation in locations {
            // TODO: Filter locations for accuracy
            let timeSince = abs(newLocation.timestamp.timeIntervalSinceNow)
            guard  timeSince < 10 else { continue }
            
            if let lastLoc = locationList.last {
                let nextDistance = newLocation.distance(from: lastLoc)
                distance = distance + Measurement(value: nextDistance, unit: .meters)
                
            }
            
            locationList.append(newLocation)
            coordinateList.append(newLocation.coordinate)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
            setUpLocation()
        }
        
        if status == .denied || status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
}



extension MapViewController: MGLMapViewDelegate {
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        setUpLocation()
        //addPolyline(to: mapView.style!)
    }
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    
    func mapView(_ mapView: MGLMapView, rightCalloutAccessoryViewFor annotation: MGLAnnotation) -> UIView? {
        return UIButton(type: .detailDisclosure)
    }
    
    func mapView(_ mapView: MGLMapView, fillColorForPolygonAnnotation annotation: MGLPolygon) -> UIColor {
        return UIColor.blue
    }
    
    func mapView(_ mapView: MGLMapView, alphaForShapeAnnotation annotation: MGLShape) -> CGFloat {
        // Set the alpha for all shape annotations to 1 (full opacity)
        return 1
    }
    
    func mapView(_ mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        // Set the line width for polyline annotations
        return 2.0
    }
    
    func mapView(_ mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        // Give our polyline a unique color by checking for its `title` property
        if (annotation.title == "Crema to Council Crest" && annotation is MGLPolyline) {
            // Mapbox cyan
            return #colorLiteral(red: 0.3647058904, green: 0.06666667014, blue: 0.9686274529, alpha: 1)
        } else {
            return #colorLiteral(red: 0.3647058904, green: 0.06666667014, blue: 0.9686274529, alpha: 1)
        }
    }
    
    // Optional: tap the user location annotation to toggle heading tracking mode.
    func mapView(_ mapView: MGLMapView, didSelect annotation: MGLAnnotation) {
        if mapView.userTrackingMode != .followWithHeading {
            mapView.userTrackingMode = .followWithHeading
        } else {
            mapView.resetNorth()
        }
        
        // We're borrowing this method as a gesture recognizer, so reset selection state.
        mapView.deselectAnnotation(annotation, animated: false)
    }
    
    
    

    
    
}

