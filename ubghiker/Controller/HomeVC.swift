//
//  HomeVC.swift
//  ubghiker
//
//  Created by sanchez on 02.12.17.
//  Copyright © 2017 KOT. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import RevealingSplashView
import Firebase

enum AnnotationType {
    case pickup
    case destination
    case driver
}

enum ButtonAction {
    case requestRide
    case getDirectionsToPassenger
    case getDirectionsToDestination
    case startTrip
    case endTrip
}

class HomeVC: UIViewController, Alertable {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionBtn: RoundedShadowButton!
    @IBOutlet weak var centerMapBtn: UIButton!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var destinationCircle: CircleView!
    @IBOutlet weak var cancelBtn: UIButton!
    
    var delegate: CenterVCDelegate?
    var locationManager: CLLocationManager?
    var regionRadius: CLLocationDistance = 1000
    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!,
                                                  iconInitialSize: CGSize(width: 80, height: 80),
                                                  backgroundColor: UIColor.white)
    var tableView = UITableView()
    var matchingItems = [MKMapItem]()
    var currentUserId = Auth.auth().currentUser?.uid
    var selectedItemPlacemark: MKPlacemark?
    var route: MKRoute!
    var actionForButton: ButtonAction = .requestRide
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        
        checkLocationAuthStatus()
        
        mapView.delegate = self
        destinationTextField.delegate = self
        
        centerMapOnUserLocation()
        
        DataService.instance.REF_DRIVERS.observe(.value, with: { (snapshot) in
            self.loadDriverAnnotationsFromFirebase()
            DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip! {
                    self.zoomOut(toFitAnnotationsFromMapView: self.mapView,
                                 forActiveTripWithDriver: true,
                                 withKey: driverKey)
                }
            })
        })
        
        cancelBtn.alpha = 0.0
        
        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()
        
        
        UpdateLocationService.instance.observeTrips { (tripDict) in
            if let tripDict = tripDict {
                let pickupCoordinateArray = tripDict[USER_PICKUP_COORDINATE] as! NSArray
                let tripKey = tripDict[USER_PASSENGER_KEY] as! String
                let acceptanceStatus = tripDict[TRIP_IS_ACCEPTED] as! Bool
                
                if !acceptanceStatus {
                    DataService.instance.driverIsAvailable(key: self.currentUserId!, handler: { (available) in
                        if let available = available {
                            if available {
                                let storyboard = UIStoryboard(name: MAIN_STORYBOARD, bundle: Bundle.main)
                                let pickupVC = storyboard.instantiateViewController(withIdentifier: VC_PICKUP) as? PickupVC
                                pickupVC?.initData(coordinate: CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees,
                                                                                      longitude: pickupCoordinateArray[1] as! CLLocationDegrees),
                                                   passengerKey: tripKey)
                                self.present(pickupVC!, animated: true, completion: nil)
                            }
                            
                        }
                    })
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DataService.instance.userIsDriver(userKey: self.currentUserId!, handler: { (status) in
            if status {
                self.setButtonsForDriver(hidden: true)
            }
        })
        
        DataService.instance.REF_TRIPS.observe(.childRemoved, with: { (removedTripSnapshot) in
            let removedTripDict = removedTripSnapshot.value as? [String: AnyObject]
            if removedTripDict?[DRIVER_KEY] != nil {
                DataService.instance.REF_DRIVERS.child(removedTripDict?[DRIVER_KEY] as! String).updateChildValues([DRIVER_IS_ON_TRIP: false])
            }
            DataService.instance.userIsDriver(userKey: self.currentUserId!, handler: { (isDriver) in
                if isDriver {
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                } else {
                    self.cancelBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                    self.actionBtn.animateButton(shouldLoad: false, withMessage: MSG_REQUEST_RIDE)
                    self.destinationTextField.isUserInteractionEnabled = true
                    self.destinationTextField.text = ""
                    
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                    self.centerMapOnUserLocation()
                }
            })
        })
        
        DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
            if isOnTrip! {
                DataService.instance.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripSnapshot) in
                    if let tripSnapshot = tripSnapshot.children.allObjects as? [DataSnapshot] {
                        for trip in tripSnapshot {
                            if trip.childSnapshot(forPath: DRIVER_KEY).value as? String == self.currentUserId! {
                                let pickupCoordinateArray = trip.childSnapshot(forPath: USER_PICKUP_COORDINATE).value as! NSArray
                                let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees,
                                                                              longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                                let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                                self.dropPinFor(placemark: pickupPlacemark)
                                self.setRouteResultsWithPolyline(forOriginMapItem: nil,
                                                                 withDestinationMapItem: MKMapItem(placemark: pickupPlacemark))
                                self.setCustomRegion(forAnnotationType: .pickup,
                                                     withCoordinate: pickupCoordinate)
                                self.actionForButton = .getDirectionsToPassenger
                                self.actionBtn.setTitle(MSG_GET_DIRECTIONS, for: .normal)
                                self.setButtonsForDriver(hidden: false)
                            }
                        }
                    }
                })
            }
        })
        
        connectPassengerAndDriverForTrip()
    }
    
    func checkLocationAuthStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            locationManager?.startUpdatingLocation()
        } else {
            locationManager?.requestAlwaysAuthorization()
        }
    }
    
    func setButtonsForDriver(hidden: Bool) {
        if hidden {
            self.actionBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.cancelBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.actionBtn.isHidden = true
            self.cancelBtn.isHidden = true
            self.centerMapBtn.isHidden = true
        } else {
            self.actionBtn.isHidden = false
            self.cancelBtn.isHidden = false
            self.centerMapBtn.isHidden = false
            self.actionBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.cancelBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.centerMapBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
        }
    }
    
    func centerMapOnUserLocation() {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(mapView.userLocation.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
        centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
    }
    
    func loadDriverAnnotationsFromFirebase() {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let driverSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.hasChild(COORDINATE) {
                        if driver.childSnapshot(forPath: ACCOUNT_PICKUP_MODE_ENABLED).value as? Bool == true {
                            if let driverDict = driver.value as? Dictionary<String, AnyObject> {
                                let coordinateArray = driverDict[COORDINATE] as! NSArray
                                let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateArray[0] as! CLLocationDegrees,
                                                                              longitude: coordinateArray[1] as! CLLocationDegrees)
                                let annotation = DriverAnnotation(coordinate: driverCoordinate, withKey: driver.key)
                                
                                var driverIsVisible: Bool {
                                    return self.mapView.annotations.contains(where: { (annotation) -> Bool in
                                        if let driverAnnotation = annotation as? DriverAnnotation {
                                            if driverAnnotation.key == driver.key {
                                                driverAnnotation.update(annotationPosition: driverAnnotation,
                                                                        withCoordinate: driverCoordinate)
                                                return true
                                            }
                                        }
                                        return false
                                    })
                                }
                                
                                if !driverIsVisible {
                                    self.mapView.addAnnotation(annotation)
                                }
                            }
                        } else {
                            for annotation in self.mapView.annotations {
                                if annotation.isKind(of: DriverAnnotation.self) {
                                    if let annotation = annotation as? DriverAnnotation {
                                        if annotation.key == driver.key {
                                            self.mapView.removeAnnotation(annotation)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        })
        revealingSplashView.heartAttack = true
    }
    
    func connectPassengerAndDriverForTrip() {
        DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
            if isOnTrip! {
                self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                DataService.instance.REF_TRIPS.child(self.currentUserId!).observeSingleEvent(of: .value, with: { (tripSnapshot) in
                    let tripDict = tripSnapshot.value as? Dictionary<String, AnyObject>
                    let driverId = tripDict?[DRIVER_KEY] as! String
                    let pickupCoordinateArray = tripDict?[USER_PICKUP_COORDINATE] as! NSArray
                    let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees,
                                                                  longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                    let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                    let pickupMapItem = MKMapItem(placemark: pickupPlacemark)
                    
                    DataService.instance.REF_DRIVERS.child(driverId).child(COORDINATE).observeSingleEvent(of: .value, with: { (coordinateSnapshot) in
                        let coordinateArray = coordinateSnapshot.value as! NSArray
                        let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateArray[0] as! CLLocationDegrees,
                                                                      longitude: coordinateArray[0] as! CLLocationDegrees)
                        let driverPlacemark = MKPlacemark(coordinate: driverCoordinate)
                        let driverMapItem = MKMapItem(placemark: driverPlacemark)
                        
                        let passengerAnnotation = PassengerAnnotation(coordinate: pickupCoordinate, key: self.currentUserId!)
                        self.mapView.addAnnotation(passengerAnnotation)
                        
                        self.setRouteResultsWithPolyline(forOriginMapItem: driverMapItem,
                                                         withDestinationMapItem: pickupMapItem)
                        self.actionBtn.animateButton(shouldLoad: false, withMessage: MSG_DRIVER_COMING)
                        self.actionBtn.isUserInteractionEnabled = false
                    })
                    
                    DataService.instance.REF_TRIPS.child(tripKey!).observeSingleEvent(of: .value, with: { (tripSnapshot) in
                        if tripDict?[TRIP_IN_PROGRESS] as? Bool == true {
                            self.removeOverlaysAndAnnotations(forDrivers: true, forPassengers: true)
                            let destinationCoordinateArray = tripDict?[USER_DESTINATION_COORDINATE] as! NSArray
                            let destinationaCoordinate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees,
                                                                                longitude: destinationCoordinateArray[0] as! CLLocationDegrees)
                            let destinationPlacemark = MKPlacemark(coordinate: destinationaCoordinate)
                            self.dropPinFor(placemark: destinationPlacemark)
                            self.setRouteResultsWithPolyline(forOriginMapItem: pickupMapItem,
                                                             withDestinationMapItem: MKMapItem(placemark: destinationPlacemark))
                            self.actionBtn.setTitle(MSG_ON_TRIP, for: .normal)
                        }
                    })
                })
            }
        })
    }
    
    @IBAction func centerMapBtnWasPressed(_ sender: UIButton) {
        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let userSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for user in userSnapshot {
                    if user.key == self.currentUserId! {
                        if user.hasChild(TRIP_COORDINATE) {
                            self.zoomOut(toFitAnnotationsFromMapView: self.mapView,
                                         forActiveTripWithDriver: false,
                                         withKey: nil)
                        } else {
                            self.centerMapOnUserLocation()
                        }
                    }
                }
            }
        })
    }
    
    @IBAction func actionBtnWasPressed(_ sender: UIButton) {
        buttonSelector(forAction: actionForButton)
    }
    
    @IBAction func cancelBtnWasPressed(_ sender: UIButton) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip! {
                UpdateLocationService.instance.cancelTrip(withPassengerKey: tripKey!,
                                                          forDriverKey: driverKey!)
            }
        }
        
        DataService.instance.passengerIsOnTrip(passengerKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip! {
                UpdateLocationService.instance.cancelTrip(withPassengerKey: self.currentUserId!,
                                                          forDriverKey: driverKey!)
            } else {
                UpdateLocationService.instance.cancelTrip(withPassengerKey: self.currentUserId!,
                                                          forDriverKey: nil)
            }
        }
        self.actionBtn.isUserInteractionEnabled = true
    }
    
    @IBAction func menuBtnWasPressed(_ sender: UIButton) {
        delegate?.toggleLeftPanel()
    }
    
    func buttonSelector(forAction action: ButtonAction) {
        switch action {
        case .requestRide:
            if destinationTextField.text != "" {
                UpdateLocationService.instance.updateTripsWithCoordinatesUponRequest()
                actionBtn.animateButton(shouldLoad: true, withMessage: nil)
                cancelBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
                self.view.endEditing(true)
                destinationTextField.isUserInteractionEnabled = false
            }
        case .getDirectionsToPassenger:
            DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip! {
                    DataService.instance.REF_TRIPS.child(tripKey!).observe(.value, with: { (tripSnapshot) in
                        let tripDict = tripSnapshot.value as? Dictionary<String, AnyObject>
                        let pickupCoordinateArray = tripDict?[USER_PICKUP_COORDINATE] as! NSArray
                        let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees,
                                                                      longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                        let pickupMapItem = MKMapItem(placemark: MKPlacemark(coordinate: pickupCoordinate))
                        pickupMapItem.name = MSG_PASSENGER_PICKUP
                        pickupMapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    })
                }
            })
        case .startTrip:
            DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip! {
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: false)
                    DataService.instance.REF_TRIPS.child(tripKey!).updateChildValues([TRIP_IN_PROGRESS: true])
                    DataService.instance.REF_TRIPS.child(tripKey!).child(USER_DESTINATION_COORDINATE).observeSingleEvent(of: .value, with: { (coordinateSnapshot) in
                        let destinationCoordinateArray = coordinateSnapshot.value as! NSArray
                        let destinationCoordinate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees,
                                                                      longitude: destinationCoordinateArray[1] as! CLLocationDegrees)
                        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
                        
                        self.dropPinFor(placemark: destinationPlacemark)
                        self.setRouteResultsWithPolyline(forOriginMapItem: nil,
                                                         withDestinationMapItem: MKMapItem(placemark: destinationPlacemark))
                        self.setCustomRegion(forAnnotationType: .destination,
                                             withCoordinate: destinationCoordinate)
                        self.actionForButton = .getDirectionsToDestination
                        self.actionBtn.setTitle(MSG_GET_DIRECTIONS, for: .normal)
                    })
                }
            })
        case .getDirectionsToDestination:
            DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip! {
                    DataService.instance.REF_TRIPS.child(tripKey!).child(USER_DESTINATION_COORDINATE).observe(.value, with: { (snapshot) in
                        let destinationCoordinateArray = snapshot.value as! NSArray
                        let destinationCoordinate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees,
                                                                           longitude: destinationCoordinateArray[1] as! CLLocationDegrees)
                        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
                        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
                        destinationMapItem.name = MSG_PASSENGER_DESTINATION
                        destinationMapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    })
                }
            })
        case .endTrip:
            DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip! {
                    UpdateLocationService.instance.cancelTrip(withPassengerKey: tripKey!, forDriverKey: driverKey!)
                    self.setButtonsForDriver(hidden: true)
                }
            })
        }
    }
}

extension HomeVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            checkLocationAuthStatus()
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler: { (isOnTrip, driverKey, passengerKey) in
            if isOnTrip! {
                if region.identifier == REGION_PICKUP {
                    self.actionForButton = .startTrip
                    self.actionBtn.setTitle(MSG_START_TRIP, for: .normal)
                } else if region.identifier == REGION_DESTINATION {
                    self.cancelBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                    self.cancelBtn.isHidden = true
                    self.actionForButton = .endTrip
                    self.actionBtn.setTitle(MSG_END_TRIP, for: .normal)
                }
            }
        })
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler: { (isOnTrip, driverKey, passengerKey) in
            if isOnTrip! {
                if region.identifier == REGION_PICKUP {
                    self.actionForButton = .getDirectionsToPassenger
                    self.actionBtn.setTitle(MSG_GET_DIRECTIONS, for: .normal)
                } else if region.identifier == REGION_DESTINATION {
                    self.actionForButton = .getDirectionsToDestination
                    self.actionBtn.setTitle(MSG_GET_DIRECTIONS, for: .normal)
                }
            }
        })
    }
}

extension HomeVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        UpdateLocationService.instance.updateUserLocation(withCoordinate: userLocation.coordinate)
        UpdateLocationService.instance.updateDriverLocation(withCoordinate: userLocation.coordinate)
        
        DataService.instance.userIsDriver(userKey: currentUserId!) { (isDriver) in
            if isDriver {
                DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                    if isOnTrip! {
                        self.zoomOut(toFitAnnotationsFromMapView: self.mapView,
                                     forActiveTripWithDriver: true,
                                     withKey: driverKey)
                    } else {
                        self.centerMapOnUserLocation()
                    }
                })
            } else {
                DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                    if isOnTrip! {
                        self.zoomOut(toFitAnnotationsFromMapView: self.mapView,
                                     forActiveTripWithDriver: true,
                                     withKey: driverKey)
                    } else {
                        self.centerMapOnUserLocation()
                    }
                })
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let driverAnnotation = annotation as? DriverAnnotation {
            let view = MKAnnotationView(annotation: driverAnnotation, reuseIdentifier: "driver")
            view.image = UIImage(named: ANNOT_DRIVER)
            return view
        } else if let passengerAnnotation = annotation as? PassengerAnnotation {
            let view = MKAnnotationView(annotation: passengerAnnotation, reuseIdentifier: "passenger")
            view.image = UIImage(named: ANNOT_PICKUP)
            return view
        } else if let annotation = annotation as? MKPointAnnotation {
            let identifier = "destination"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.image = UIImage(named: ANNOT_DESTINATION)
            return annotationView
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        centerMapBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let lineRenderer = MKPolylineRenderer(overlay: self.route.polyline)
        lineRenderer.strokeColor = UIColor(red: 216/255, green: 71/255, blue: 30/255, alpha: 0.75)
        lineRenderer.lineWidth = 3
        shouldPresentLoadingView(false)
        return lineRenderer
    }
    
    func performSearch(searchTerm: String?) {
        matchingItems.removeAll()
        let request = MKLocalSearchRequest()
        request.naturalLanguageQuery = searchTerm
        request.region = mapView.region
        
        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            if error != nil {
                self.showAlert(ERROR_MSG_UNEXPECTED_ERROR)
            } else if response!.mapItems.count == 0 {
                self.showAlert(ERROR_MSG_NO_MATCHES_FOUND)
            } else {
                for mapItem in response!.mapItems {
                    self.matchingItems.append(mapItem as MKMapItem)
                }
                self.tableView.reloadData()
                self.shouldPresentLoadingView(false)
            }
        }
    }
    
    func dropPinFor(placemark: MKPlacemark) {
        selectedItemPlacemark = placemark
        for annotation in mapView.annotations {
            if annotation.isKind(of: MKPointAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        mapView.addAnnotation(annotation)
    }
    
    func setRouteResultsWithPolyline(forOriginMapItem originMapItem: MKMapItem?, withDestinationMapItem destinationMapItem: MKMapItem) {
        let request = MKDirectionsRequest()
        if originMapItem == nil {
           request.source = MKMapItem.forCurrentLocation()
        } else {
            request.source = originMapItem
        }
        
        request.destination = destinationMapItem
        request.transportType = MKDirectionsTransportType.automobile
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        directions.calculate { (response, error) in
            guard let response = response else {
                self.showAlert(ERROR_MSG_UNEXPECTED_ERROR)
                return
            }
            self.route = response.routes[0]
            self.mapView.add(self.route.polyline)
            self.zoomOut(toFitAnnotationsFromMapView: self.mapView,
                         forActiveTripWithDriver: false,
                         withKey: nil)
            
            let delegate = AppDelegate.getAppDelegate()
            delegate.window?.rootViewController?.shouldPresentLoadingView(false)
        }
    }
    
    func zoomOut(toFitAnnotationsFromMapView mapView: MKMapView, forActiveTripWithDriver: Bool, withKey key: String?) {
        guard mapView.annotations.count > 0 else { return }
        
        var topLeftCorner = CLLocationCoordinate2D(latitude: -90, longitude: 180)
        var bottomRightCorner = CLLocationCoordinate2D(latitude: 90, longitude: -180)
        
        if forActiveTripWithDriver {
            for annotation in mapView.annotations {
                if let annotation = annotation as? DriverAnnotation {
                    if annotation.key == key {
                        topLeftCorner.longitude = fmin(topLeftCorner.longitude, annotation.coordinate.longitude)
                        topLeftCorner.latitude = fmax(topLeftCorner.latitude, annotation.coordinate.latitude)
                        bottomRightCorner.longitude = fmax(bottomRightCorner.longitude, annotation.coordinate.longitude)
                        bottomRightCorner.latitude = fmin(bottomRightCorner.latitude, annotation.coordinate.latitude)
                    }
                } else {
                    topLeftCorner.longitude = fmin(topLeftCorner.longitude, annotation.coordinate.longitude)
                    topLeftCorner.latitude = fmax(topLeftCorner.latitude, annotation.coordinate.latitude)
                    bottomRightCorner.longitude = fmax(bottomRightCorner.longitude, annotation.coordinate.longitude)
                    bottomRightCorner.latitude = fmin(bottomRightCorner.latitude, annotation.coordinate.latitude)
                }
            }
        }
        
        for annotation in mapView.annotations where !annotation.isKind(of: DriverAnnotation.self) {
            topLeftCorner.longitude = fmin(topLeftCorner.longitude, annotation.coordinate.longitude)
            topLeftCorner.latitude = fmax(topLeftCorner.latitude, annotation.coordinate.latitude)
            bottomRightCorner.longitude = fmax(bottomRightCorner.longitude, annotation.coordinate.longitude)
            bottomRightCorner.latitude = fmin(bottomRightCorner.latitude, annotation.coordinate.latitude)
        }
        
        var region = MKCoordinateRegion(center: CLLocationCoordinate2DMake(topLeftCorner.latitude - (topLeftCorner.latitude - bottomRightCorner.latitude) * 0.5,
                                                                           topLeftCorner.longitude + (bottomRightCorner.longitude - topLeftCorner.longitude) * 0.5),
                                        span: MKCoordinateSpan(latitudeDelta: fabs(topLeftCorner.latitude - bottomRightCorner.latitude) * 2.0,
                                                               longitudeDelta: fabs(bottomRightCorner.longitude - topLeftCorner.longitude) * 2.0))
        
        region = mapView.regionThatFits(region)
        mapView.setRegion(region, animated: true)
        centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
    }
    
    func removeOverlaysAndAnnotations(forDrivers: Bool?, forPassengers: Bool?) {
        for annotation in mapView.annotations {
            if let annotation = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            }
            if forPassengers! {
                if let annotation = annotation as? PassengerAnnotation {
                    mapView.removeAnnotation(annotation)
                }
            }
            if forDrivers! {
                if let annotation = annotation as? DriverAnnotation {
                    mapView.removeAnnotation(annotation)
                }
            }
        }
        
        for overlay in mapView.overlays {
            if overlay is MKPolyline {
                mapView.remove(overlay)
            }
        }
    }
    
    func setCustomRegion(forAnnotationType type: AnnotationType, withCoordinate coordinate: CLLocationCoordinate2D) {
        switch type {
        case .pickup:
            let pickupRegion = CLCircularRegion(center: coordinate, radius: 100, identifier: "pickup")
            locationManager?.startMonitoring(for: pickupRegion)
        case .destination:
            let destinationRegion = CLCircularRegion(center: coordinate, radius: 100, identifier: "destination")
            locationManager?.startMonitoring(for: destinationRegion)
        case .driver:
            let driverRegion = CLCircularRegion(center: coordinate, radius: 100, identifier: "driver")
            locationManager?.startMonitoring(for: driverRegion)
        }
    }
}

extension HomeVC: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        tableView.frame = CGRect(x: 20, y: view.frame.height, width: view.frame.width - 40, height: view.frame.height - 170)
        tableView.layer.cornerRadius = 5.0
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "locationCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tag = 18
        tableView.rowHeight = 60
        
        view.addSubview(tableView)
        animateTableViewAppear(true)
        
        UIView.animate(withDuration: 0.2) {
            self.destinationCircle.backgroundColor = UIColor.red
            self.destinationCircle.borderColor = UIColor.init(red: 199/255, green: 0/255, blue: 0/255, alpha: 1.0)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == destinationTextField && destinationTextField.text != "" {
            performSearch(searchTerm: destinationTextField.text)
            shouldPresentLoadingView(true)
            view.endEditing(true)
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            if destinationTextField.text == "" {
                UIView.animate(withDuration: 0.2) {
                    self.destinationCircle.backgroundColor = UIColor.lightGray
                    self.destinationCircle.borderColor = UIColor.darkGray
                }
            }
        }
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        matchingItems.removeAll()
        tableView.reloadData()
        
        DataService.instance.REF_USERS.child(currentUserId!).child(TRIP_COORDINATE).removeValue()
        
        mapView.removeOverlays(mapView.overlays)
        for annotation in mapView.annotations {
            if let annotation = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            } else if annotation.isKind(of: PassengerAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        centerMapOnUserLocation()
        return true
    }
    
    func animateTableViewAppear(_ shouldShow: Bool) {
        if shouldShow {
            UIView.animate(withDuration: 0.2, animations: {
                self.tableView.frame = CGRect(x: 20, y: 170, width: self.view.frame.width - 40, height: self.view.frame.height - 170)
            })
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.tableView.frame = CGRect(x: 20, y: self.view.frame.height, width: self.view.frame.width - 40, height: self.view.frame.height - 170)
            }, completion: { (finished) in
                if finished {
                    for subview in self.view.subviews {
                        if subview.tag == 18 {
                            subview.removeFromSuperview()
                        }
                    }
                }
            })
        }
    }
}

extension HomeVC: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "locationCell")
        let mapItem = matchingItems[indexPath.row]
        cell.textLabel?.text = mapItem.name
        cell.detailTextLabel?.text = mapItem.placemark.title
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        shouldPresentLoadingView(true)
        
        let passengerCoordinate = locationManager?.location?.coordinate
        let passengerAnnotation = PassengerAnnotation(coordinate: passengerCoordinate!, key: currentUserId!)
        mapView.addAnnotation(passengerAnnotation)
        
        destinationTextField.text = tableView.cellForRow(at: indexPath)?.textLabel?.text
        
        let selectedMapItem = matchingItems[indexPath.row]
        DataService.instance.REF_USERS.child(currentUserId!).updateChildValues([TRIP_COORDINATE: [selectedMapItem.placemark.coordinate.latitude,
                                                                                                   selectedMapItem.placemark.coordinate.longitude]])
        dropPinFor(placemark: selectedMapItem.placemark)
        setRouteResultsWithPolyline(forOriginMapItem: nil,
                                    withDestinationMapItem: selectedMapItem)
        animateTableViewAppear(false)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if destinationTextField.text == "" {
            animateTableViewAppear(false)
        }
    }
}

