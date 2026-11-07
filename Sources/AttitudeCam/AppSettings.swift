import Foundation
import SwiftUI
import Combine

enum UnitPreset: String, CaseIterable, Identifiable {
    case aviation = "Aviation (kts, ft)"
    case imperial = "Imperial (mph, ft)"
    case metric = "Metric (km/h, m)"
    var id: Self { self }
}

enum DisplayFontSize: String, CaseIterable, Identifiable, Sendable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    var id: Self { self }
    
    var scaleMultiplier: CGFloat {
        switch self {
        case .small: return 1.0  // Current font size is small (default)
        case .medium: return 1.25
        case .large: return 1.50
        }
    }
    
    func size(_ base: CGFloat) -> CGFloat {
        return round(base * scaleMultiplier)
    }
}

enum SpeedUnit: String, CaseIterable, Identifiable {
    case knots = "knots"
    case mph = "mph"
    case kmh = "km/h"
    var id: Self { self }
    
    var abbreviation: String {
        switch self {
        case .knots: return "kts"
        case .mph: return "mph"
        case .kmh: return "km/h"
        }
    }
}

enum AltitudeUnit: String, CaseIterable, Identifiable {
    case feet = "Feet (ft)"
    case meters = "Meters (m)"
    var id: Self { self }
    
    var abbreviation: String {
        switch self {
        case .feet: return "ft"
        case .meters: return "m"
        }
    }
}

enum HeadingType: String, CaseIterable, Identifiable {
    case trueNorth = "True North (T)"
    case magnetic = "Magnetic (M)"
    var id: Self { self }
    
    var badge: String {
        switch self {
        case .trueNorth: return "T"
        case .magnetic: return "M"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - Units & Display
    @Published var fontSize: DisplayFontSize {
        didSet { UserDefaults.standard.set(fontSize.rawValue, forKey: "displayFontSize") }
    }
    @Published var speedUnit: SpeedUnit {
        didSet { UserDefaults.standard.set(speedUnit.rawValue, forKey: "speedUnit") }
    }
    @Published var altitudeUnit: AltitudeUnit {
        didSet { UserDefaults.standard.set(altitudeUnit.rawValue, forKey: "altitudeUnit") }
    }
    @Published var headingType: HeadingType {
        didSet { UserDefaults.standard.set(headingType.rawValue, forKey: "headingType") }
    }
    
    // MARK: - Custom Tag / Note / Tail Number
    @Published var customNote: String {
        didSet { UserDefaults.standard.set(customNote, forKey: "customNote") }
    }
    @Published var burnCustomNote: Bool {
        didSet { UserDefaults.standard.set(burnCustomNote, forKey: "burnCustomNote") }
    }
    
    // MARK: - Display Toggles
    @Published var showHorizonHUD: Bool {
        didSet { UserDefaults.standard.set(showHorizonHUD, forKey: "showHorizonHUD") }
    }
    @Published var showCoordinates: Bool {
        didSet { UserDefaults.standard.set(showCoordinates, forKey: "showCoordinates") }
    }
    @Published var showSpeed: Bool {
        didSet { UserDefaults.standard.set(showSpeed, forKey: "showSpeed") }
    }
    @Published var showAltitude: Bool {
        didSet { UserDefaults.standard.set(showAltitude, forKey: "showAltitude") }
    }
    @Published var showHeading: Bool {
        didSet { UserDefaults.standard.set(showHeading, forKey: "showHeading") }
    }
    @Published var showVSI: Bool {
        didSet { UserDefaults.standard.set(showVSI, forKey: "showVSI") }
    }
    @Published var showGMeter: Bool {
        didSet { UserDefaults.standard.set(showGMeter, forKey: "showGMeter") }
    }
    @Published var enableLevelSnap: Bool {
        didSet { UserDefaults.standard.set(enableLevelSnap, forKey: "enableLevelSnap") }
    }
    @Published var hapticOnLevelSnap: Bool {
        didSet { UserDefaults.standard.set(hapticOnLevelSnap, forKey: "hapticOnLevelSnap") }
    }
    
    // MARK: - Photo Capture Toggles
    @Published var burnOverlayOnPhoto: Bool {
        didSet { UserDefaults.standard.set(burnOverlayOnPhoto, forKey: "burnOverlayOnPhoto") }
    }
    @Published var burnHorizonOnPhoto: Bool {
        didSet { UserDefaults.standard.set(burnHorizonOnPhoto, forKey: "burnHorizonOnPhoto") }
    }
    
    init() {
        let def = UserDefaults.standard
        
        let savedFontSize = def.string(forKey: "displayFontSize") ?? DisplayFontSize.small.rawValue
        self.fontSize = DisplayFontSize(rawValue: savedFontSize) ?? .small
        
        let savedSpeed = def.string(forKey: "speedUnit") ?? SpeedUnit.knots.rawValue
        self.speedUnit = SpeedUnit(rawValue: savedSpeed) ?? .knots
        
        let savedAlt = def.string(forKey: "altitudeUnit") ?? AltitudeUnit.feet.rawValue
        self.altitudeUnit = AltitudeUnit(rawValue: savedAlt) ?? .feet
        
        let savedHdg = def.string(forKey: "headingType") ?? HeadingType.trueNorth.rawValue
        self.headingType = HeadingType(rawValue: savedHdg) ?? .trueNorth
        
        self.customNote = def.string(forKey: "customNote") ?? ""
        self.burnCustomNote = def.object(forKey: "burnCustomNote") != nil ? def.bool(forKey: "burnCustomNote") : true
        
        self.showHorizonHUD = def.object(forKey: "showHorizonHUD") != nil ? def.bool(forKey: "showHorizonHUD") : true
        self.showCoordinates = def.object(forKey: "showCoordinates") != nil ? def.bool(forKey: "showCoordinates") : true
        self.showSpeed = def.object(forKey: "showSpeed") != nil ? def.bool(forKey: "showSpeed") : true
        self.showAltitude = def.object(forKey: "showAltitude") != nil ? def.bool(forKey: "showAltitude") : true
        self.showHeading = def.object(forKey: "showHeading") != nil ? def.bool(forKey: "showHeading") : true
        self.showVSI = def.object(forKey: "showVSI") != nil ? def.bool(forKey: "showVSI") : true
        self.showGMeter = def.object(forKey: "showGMeter") != nil ? def.bool(forKey: "showGMeter") : true
        self.enableLevelSnap = def.object(forKey: "enableLevelSnap") != nil ? def.bool(forKey: "enableLevelSnap") : true
        self.hapticOnLevelSnap = def.object(forKey: "hapticOnLevelSnap") != nil ? def.bool(forKey: "hapticOnLevelSnap") : true
        
        self.burnOverlayOnPhoto = def.object(forKey: "burnOverlayOnPhoto") != nil ? def.bool(forKey: "burnOverlayOnPhoto") : true
        self.burnHorizonOnPhoto = def.object(forKey: "burnHorizonOnPhoto") != nil ? def.bool(forKey: "burnHorizonOnPhoto") : true
    }
    
    func applyPreset(_ preset: UnitPreset) {
        switch preset {
        case .aviation:
            speedUnit = .knots
            altitudeUnit = .feet
            headingType = .magnetic
        case .imperial:
            speedUnit = .mph
            altitudeUnit = .feet
            headingType = .trueNorth
        case .metric:
            speedUnit = .kmh
            altitudeUnit = .meters
            headingType = .trueNorth
        }
    }
}
