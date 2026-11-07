import Foundation
import CoreMotion
import Combine
import UIKit

enum DeviceScreenOrientation: Sendable {
    case portrait
    case landscapeLeft
    case landscapeRight
    case portraitUpsideDown
}

@MainActor
final class MotionManager: ObservableObject {
    private let motion = CMMotionManager()
    private let altimeter = CMAltimeter()
    
    @Published var pitch: Double = 0.0 // in degrees: 0 when vertical facing horizon
    @Published var roll: Double = 0.0  // in degrees: positive banking right, negative banking left
    @Published var gForce: Double = 1.0 // Total instantaneous G-load (1.0 = standard gravity)
    @Published var peakG: Double = 1.0  // Highest G observed
    @Published var barometricPressure: Double = 1013.25 // in hPa
    @Published var isLevel: Bool = false
    @Published var isAvailable: Bool = false
    @Published var currentOrientation: DeviceScreenOrientation = .portrait
    
    var hapticFeedbackEnabled: Bool = true
    private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var wasLevel: Bool = false
    
    init() {
        startMotionUpdates()
    }
    
    func updateOrientation(_ orientation: DeviceScreenOrientation) {
        self.currentOrientation = orientation
    }
    
    func resetPeakG() {
        self.peakG = 1.0
    }
    
    func startMotionUpdates() {
        guard motion.isDeviceMotionAvailable else {
            isAvailable = false
            return
        }
        isAvailable = true
        motion.deviceMotionUpdateInterval = 1.0 / 30.0 // 30Hz update rate
        
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let data = data else { return }
                self?.barometricPressure = data.pressure.doubleValue * 10.0
            }
        }
        
        let opQueue = OperationQueue()
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: opQueue) { [weak self] data, _ in
            guard let data = data else { return }
            
            let gX = data.gravity.x
            let gY = data.gravity.y
            let gZ = data.gravity.z
            
            // Total Acceleration (gravity vector + user motion vector)
            let totalAx = gX + data.userAcceleration.x
            let totalAy = gY + data.userAcceleration.y
            let totalAz = gZ + data.userAcceleration.z
            let instantG = sqrt(totalAx * totalAx + totalAy * totalAy + totalAz * totalAz)
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Project gravity onto screen axes based on active screen orientation
                let gRight: Double
                let gUp: Double
                
                switch self.currentOrientation {
                case .portrait:
                    gRight = gX
                    gUp = gY
                case .landscapeLeft:
                    // Rotated 90° CCW (Home button / charge port on right)
                    gRight = -gY
                    gUp = gX
                case .landscapeRight:
                    // Rotated 90° CW (Home button / charge port on left)
                    gRight = gY
                    gUp = -gX
                case .portraitUpsideDown:
                    gRight = -gX
                    gUp = -gY
                }
                
                let calculatedRoll = atan2(gRight, -gUp) * 180.0 / .pi
                let horizontalMagnitude = max(0.001, sqrt(gRight * gRight + gUp * gUp))
                let calculatedPitch = atan2(-gZ, horizontalMagnitude) * 180.0 / .pi
                
                self.roll = calculatedRoll
                self.pitch = calculatedPitch
                
                // Smooth G-force readout
                self.gForce = (self.gForce * 0.7) + (instantG * 0.3)
                if self.gForce > self.peakG {
                    self.peakG = self.gForce
                }
                
                // Check level status (within ±0.5° of both pitch and roll)
                let currentlyLevel = abs(calculatedPitch) <= 0.5 && abs(calculatedRoll) <= 0.5
                self.isLevel = currentlyLevel
                
                if currentlyLevel && !self.wasLevel && self.hapticFeedbackEnabled {
                    self.feedbackGenerator.impactOccurred()
                }
                self.wasLevel = currentlyLevel
            }
        }
    }
    
    func stopMotionUpdates() {
        motion.stopDeviceMotionUpdates()
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.stopRelativeAltitudeUpdates()
        }
    }
    
    var formattedPitch: String {
        let sign = pitch >= 0 ? "+" : ""
        return String(format: "PITCH: %@%.1f°", sign, pitch)
    }
    
    var formattedRoll: String {
        let sign = roll >= 0 ? "+" : ""
        return String(format: "ROLL: %@%.1f°", sign, roll)
    }
    
    var formattedG: String {
        return String(format: "%.2f G", gForce)
    }
}
