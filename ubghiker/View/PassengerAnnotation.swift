//
//  PassengerAnnotation.swift
//  ubghiker
//
//  Created by sanchez on 04.12.17.
//  Copyright © 2017 KOT. All rights reserved.
//

import Foundation
import MapKit

class PassengerAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var key: String
    
    init(coordinate: CLLocationCoordinate2D, key: String) {
        self.coordinate = coordinate
        self.key = key
        super.init()
    }
    
    
}
