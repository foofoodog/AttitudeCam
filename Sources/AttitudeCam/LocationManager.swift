import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var altitude: CLLocationDistance = 0
    @Published var horizontalAccuracy: CLLocationAccuracy = 0
    @Published var heading: CLLocationDirection = 0
    @Published var trueHeading: CLLocationDirection = 0
    @Published var magneticHeading: CLLocationDirection = 0
    @Published var speed: CLLocationSpeed = 0
    @Published var verticalSpeed: Double = 0.0 // in m/s
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private var lastAltitude: Double?
    private var lastLocationTime: Date?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 1.0 // update every 1 degree
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
                if CLLocationManager.headingAvailable() {
                    self.manager.startUpdatingHeading()
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = location.coordinate
        let alt = location.altitude
        let acc = location.horizontalAccuracy
        let spd = location.speed
        let time = location.timestamp
        
        Task { @MainActor in
            self.coordinate = coord
            self.altitude = alt
            self.horizontalAccuracy = acc
            if spd >= 0 {
                self.speed = spd
            } else {
                self.speed = 0
            }
            
            // Calculate vertical climb rate / descent rate (m/s)
            if let prevAlt = self.lastAltitude, let prevTime = self.lastLocationTime {
                let dt = time.timeIntervalSince(prevTime)
                if dt >= 0.5 && dt < 10.0 {
                    let instantVSI = (alt - prevAlt) / dt
                    // Exponential smoothing (alpha = 0.3)
                    self.verticalSpeed = (self.verticalSpeed * 0.7) + (instantVSI * 0.3)
                }
            }
            self.lastAltitude = alt
            self.lastLocationTime = time
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let tHdg = newHeading.trueHeading
        let mHdg = newHeading.magneticHeading
        let activeHdg = tHdg >= 0 ? tHdg : mHdg
        
        Task { @MainActor in
            self.heading = activeHdg
            self.trueHeading = max(0, tHdg)
            self.magneticHeading = max(0, mHdg)
        }
    }
    
    // MARK: - Unit-Aware Formatting Helpers
    
    func formattedSpeed(unit: SpeedUnit) -> String {
        guard speed > 0.3 else { return "0.0 " + unit.abbreviation }
        switch unit {
        case .knots:
            let kts = speed * 1.94384
            return String(format: "%.1f kts", kts)
        case .mph:
            let mph = speed * 2.23694
            return String(format: "%.1f mph", mph)
        case .kmh:
            let kmh = speed * 3.6
            return String(format: "%.1f km/h", kmh)
        }
    }
    
    func formattedAltitude(unit: AltitudeUnit) -> String {
        switch unit {
        case .feet:
            let ft = altitude * 3.28084
            return String(format: "%.0f ft", ft)
        case .meters:
            return String(format: "%.0f m", altitude)
        }
    }
    
    func formattedVerticalSpeed(unit: AltitudeUnit) -> String {
        switch unit {
        case .feet:
            let fpm = verticalSpeed * 3.28084 * 60.0
            return String(format: "%+.0f ft/m", fpm)
        case .meters:
            return String(format: "%+.1f m/s", verticalSpeed)
        }
    }
    
    func formattedHeading(type: HeadingType) -> String {
        let value: Double
        switch type {
        case .trueNorth:
            value = trueHeading > 0 ? trueHeading : heading
        case .magnetic:
            value = magneticHeading > 0 ? magneticHeading : heading
        }
        let deg = Int(round(value)) % 360
        let cardinal = cardinalDirection(deg)
        return String(format: "%03d°%@ %@", deg, type.badge, cardinal)
    }
    
    // MARK: - Default / DMS Formatting
    
    var formattedLatitude: String {
        guard let coord = coordinate else { return "--°--'--\"" }
        return formatDMS(coord.latitude, isLatitude: true)
    }
    
    var formattedLongitude: String {
        guard let coord = coordinate else { return "--°--'--\"" }
        return formatDMS(coord.longitude, isLatitude: false)
    }
    
    var decimalLatitude: String {
        guard let coord = coordinate else { return "--.------" }
        let dir = coord.latitude >= 0 ? "N" : "S"
        return String(format: "%.6f° %@", abs(coord.latitude), dir)
    }
    
    var decimalLongitude: String {
        guard let coord = coordinate else { return "--.------" }
        let dir = coord.longitude >= 0 ? "E" : "W"
        return String(format: "%.6f° %@", abs(coord.longitude), dir)
    }
    
    var formattedAltitude: String {
        let meters = altitude
        let feet = meters * 3.28084
        return String(format: "%.0f m (%.0f ft)", meters, feet)
    }
    
    var formattedHeading: String {
        let degrees = Int(round(heading)) % 360
        let cardinal = cardinalDirection(degrees)
        return String(format: "%03d° %@", degrees, cardinal)
    }
    
    var formattedAccuracy: String {
        if horizontalAccuracy <= 0 { return "Acquiring..." }
        return String(format: "±%.1f m", horizontalAccuracy)
    }
    
    private func formatDMS(_ value: Double, isLatitude: Bool) -> String {
        let positive = value >= 0
        let val = abs(value)
        let degrees = Int(val)
        let minutes = Int((val - Double(degrees)) * 60)
        let seconds = (val - Double(degrees) - Double(minutes) / 60) * 3600
        let direction: String
        if isLatitude {
            direction = positive ? "N" : "S"
        } else {
            direction = positive ? "E" : "W"
        }
        return String(format: "%d°%02d'%04.1f\" %@", degrees, minutes, seconds, direction)
    }
    
    private func cardinalDirection(_ degrees: Int) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((Double(degrees) + 11.25) / 22.5) % 16
        return directions[index]
    }
}
