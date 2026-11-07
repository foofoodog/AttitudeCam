import Foundation
import UIKit
import Photos
import ImageIO
import UniformTypeIdentifiers
import CoreLocation

struct TelemetrySnapshot: Sendable {
    let coordinate: CLLocationCoordinate2D?
    let altitude: Double
    let heading: Double
    let trueHeading: Double
    let magneticHeading: Double
    let speed: Double
    let verticalSpeed: Double
    let gForce: Double
    let horizontalAccuracy: Double
    let pitch: Double
    let roll: Double
    let barometricPressure: Double // in hPa
    let ambientTemperature: Double // in Celsius
    let declination: Double        // in degrees
    let includeHUD: Bool
    let burnOverlay: Bool
    let burnHorizon: Bool
    let customNote: String
    let speedUnit: SpeedUnit
    let altitudeUnit: AltitudeUnit
    let headingType: HeadingType
    let enableLevelSnap: Bool
    let fontSize: DisplayFontSize
    let timestamp: Date
    
    init(
        coordinate: CLLocationCoordinate2D?,
        altitude: Double,
        heading: Double,
        trueHeading: Double = 0,
        magneticHeading: Double = 0,
        speed: Double,
        verticalSpeed: Double = 0,
        gForce: Double = 1.0,
        horizontalAccuracy: Double,
        pitch: Double,
        roll: Double,
        barometricPressure: Double = 1013.25,
        ambientTemperature: Double = 20.0,
        declination: Double = 0.0,
        includeHUD: Bool = true,
        burnOverlay: Bool = true,
        burnHorizon: Bool = true,
        customNote: String = "",
        speedUnit: SpeedUnit = .knots,
        altitudeUnit: AltitudeUnit = .feet,
        headingType: HeadingType = .trueNorth,
        enableLevelSnap: Bool = true,
        fontSize: DisplayFontSize = .small,
        timestamp: Date
    ) {
        self.coordinate = coordinate
        self.altitude = altitude
        self.heading = heading
        self.trueHeading = trueHeading
        self.magneticHeading = magneticHeading
        self.speed = speed
        self.verticalSpeed = verticalSpeed
        self.gForce = gForce
        self.horizontalAccuracy = horizontalAccuracy
        self.pitch = pitch
        self.roll = roll
        self.barometricPressure = barometricPressure
        self.ambientTemperature = ambientTemperature
        self.declination = declination
        self.includeHUD = includeHUD
        self.burnOverlay = burnOverlay
        self.burnHorizon = burnHorizon
        self.customNote = customNote
        self.speedUnit = speedUnit
        self.altitudeUnit = altitudeUnit
        self.headingType = headingType
        self.enableLevelSnap = enableLevelSnap
        self.fontSize = fontSize
        self.timestamp = timestamp
    }
    
    /// Generates structured JSON payload matching Telemetry Camera / userguide.md spec
    func generateUserGuideJSON() -> String {
        let lat = coordinate?.latitude ?? 0.0
        let lon = coordinate?.longitude ?? 0.0
        let celestial = CelestialCalculator.calculate(date: timestamp, latitude: lat, longitude: lon)
        
        var dict: [String: Any] = [
            "elevation": (pitch * 100).rounded() / 100,
            "heading": (heading * 100).rounded() / 100,
            "roll": (roll * 100).rounded() / 100,
            "lat": lat,
            "lon": lon,
            "alt": (altitude * 100).rounded() / 100,
            "acc": (horizontalAccuracy * 100).rounded() / 100,
            "baro": (barometricPressure * 100).rounded() / 100,
            "temp": (ambientTemperature * 10).rounded() / 10,
            "speed": (speed * 100).rounded() / 100,
            "declination": (declination * 100).rounded() / 100,
            "sunAz": celestial.sunAzimuth,
            "sunEl": celestial.sunElevation,
            "moonAz": celestial.moonAzimuth,
            "moonEl": celestial.moonElevation,
            "timestamp": Int64(timestamp.timeIntervalSince1970 * 1000),
            "isBurned": burnOverlay
        ]
        
        if !customNote.isEmpty {
            dict["note"] = customNote
        }
        dict["gForce"] = (gForce * 100).rounded() / 100
        dict["vsi"] = (verticalSpeed * 100).rounded() / 100
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
    
    var formattedLatitude: String {
        guard let c = coordinate else { return "--°--'--\"" }
        return formatDMS(c.latitude, isLatitude: true)
    }
    
    var formattedLongitude: String {
        guard let c = coordinate else { return "--°--'--\"" }
        return formatDMS(c.longitude, isLatitude: false)
    }
    
    var formattedAltitude: String {
        switch altitudeUnit {
        case .feet:
            let ft = altitude * 3.28084
            return String(format: "%.0f ft", ft)
        case .meters:
            return String(format: "%.0f m", altitude)
        }
    }
    
    var formattedSpeed: String {
        guard speed > 0.3 else { return "0.0 " + speedUnit.abbreviation }
        switch speedUnit {
        case .knots:
            return String(format: "%.1f kts", speed * 1.94384)
        case .mph:
            return String(format: "%.1f mph", speed * 2.23694)
        case .kmh:
            return String(format: "%.1f km/h", speed * 3.6)
        }
    }
    
    var formattedVSI: String {
        switch altitudeUnit {
        case .feet:
            return String(format: "%+.0f ft/m", verticalSpeed * 3.28084 * 60)
        case .meters:
            return String(format: "%+.1f m/s", verticalSpeed)
        }
    }
    
    var formattedHeading: String {
        let val = headingType == .trueNorth ? (trueHeading > 0 ? trueHeading : heading) : (magneticHeading > 0 ? magneticHeading : heading)
        let deg = Int(round(val)) % 360
        return String(format: "%03d°%@", deg, headingType.badge)
    }
    
    var isLevel: Bool {
        return abs(pitch) <= 0.5 && abs(roll) <= 0.5
    }
    
    private func formatDMS(_ value: Double, isLatitude: Bool) -> String {
        let positive = value >= 0
        let val = abs(value)
        let degrees = Int(val)
        let minutes = Int((val - Double(degrees)) * 60)
        let seconds = (val - Double(degrees) - Double(minutes) / 60) * 3600
        let dir = isLatitude ? (positive ? "N" : "S") : (positive ? "E" : "W")
        return String(format: "%d°%02d'%04.1f\" %@", degrees, minutes, seconds, dir)
    }
}

final class PhotoComposer: @unchecked Sendable {
    static let shared = PhotoComposer()
    
    private init() {}
    
    func composeAndSavePhoto(image: UIImage, telemetry: TelemetrySnapshot) async throws -> (image: UIImage, jpegData: Data, assetLocalIdentifier: String?, jsonPayload: String) {
        // 1. Draw the visual overlay onto the image if enabled
        let finalImage: UIImage
        if telemetry.burnOverlay {
            finalImage = drawTelemetryOverlay(on: image, telemetry: telemetry)
        } else {
            finalImage = image
        }
        
        // 2. Generate structured JSON payload matching Telemetry Camera / userguide.md spec
        let jsonPayload = telemetry.generateUserGuideJSON()
        
        // 3. Direct single-pass JPEG encoding with EXIF and GPS metadata
        guard let jpegData = addMetadata(to: finalImage, telemetry: telemetry, jsonPayload: jsonPayload) else {
            throw NSError(domain: "AttitudeCam", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode photo with metadata"])
        }
        
        // 4. Save to Photos Library in background
        let assetId = try await saveToPhotoLibrary(data: jpegData)
        return (finalImage, jpegData, assetId, jsonPayload)
    }
    
    // MARK: - Fast Visual Overlay Rendering
    private func drawTelemetryOverlay(on baseImage: UIImage, telemetry: TelemetrySnapshot) -> UIImage {
        let size = baseImage.size
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        return renderer.image { rendererContext in
            let cgContext = rendererContext.cgContext
            
            // Draw original camera photo
            baseImage.draw(at: .zero)
            
            // Scale font and dimensions proportional to photo resolution and chosen text size
            let scaleFactor = max(1.0, min(size.width, size.height) / 1080.0)
            let fontMultiplier = telemetry.fontSize.scaleMultiplier
            
            // Top Scrim (semi-transparent dark banner for telemetry text)
            let headerHeight = 115.0 * scaleFactor * fontMultiplier
            let bannerRect = CGRect(x: 0, y: 0, width: size.width, height: headerHeight)
            
            cgContext.setFillColor(UIColor(white: 0.0, alpha: 0.65).cgColor)
            cgContext.fill(bannerRect)
            
            // Bottom accent line
            cgContext.setFillColor(UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 0.8).cgColor)
            cgContext.fill(CGRect(x: 0, y: headerHeight - (2.0 * scaleFactor), width: size.width, height: 2.0 * scaleFactor))
            
            // Colors & Fonts
            let hudGreen = UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 1.0)
            let hudYellow = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
            let hudCyan = UIColor(red: 0.3, green: 0.9, blue: 1.0, alpha: 1.0)
            let fontColor = UIColor.white
            
            let fontSizeTitle = 16.0 * scaleFactor * fontMultiplier
            let fontSizeBody = 13.0 * scaleFactor * fontMultiplier
            
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSizeTitle, weight: .bold),
                .foregroundColor: hudGreen
            ]
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSizeBody, weight: .bold),
                .foregroundColor: UIColor.lightGray
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSizeBody, weight: .semibold),
                .foregroundColor: fontColor
            ]
            let yellowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSizeBody, weight: .semibold),
                .foregroundColor: hudYellow
            ]
            let cyanAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSizeBody, weight: .semibold),
                .foregroundColor: hudCyan
            ]
            
            let pad = 24.0 * scaleFactor
            
            // Row 1: App Title & Tail / Note & Date
            let titleText: String
            if !telemetry.customNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                titleText = "ATTITUDECAM • \(telemetry.customNote.uppercased())"
            } else {
                titleText = "ATTITUDECAM"
            }
            titleText.draw(at: CGPoint(x: pad, y: 12.0 * scaleFactor), withAttributes: titleAttrs)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateStr = dateFormatter.string(from: telemetry.timestamp)
            let dateSize = (dateStr as NSString).size(withAttributes: valueAttrs)
            dateStr.draw(at: CGPoint(x: size.width - pad - dateSize.width, y: 14.0 * scaleFactor), withAttributes: valueAttrs)
            
            // Row 2: GPS Coordinates & Speed
            let row2Y = 44.0 * scaleFactor * fontMultiplier
            let latLabel = "LAT: "
            latLabel.draw(at: CGPoint(x: pad, y: row2Y), withAttributes: labelAttrs)
            let latVal = telemetry.formattedLatitude
            latVal.draw(at: CGPoint(x: pad + 55 * scaleFactor, y: row2Y), withAttributes: valueAttrs)
            
            let lonLabel = "LON: "
            let lonX = pad + 320 * scaleFactor
            lonLabel.draw(at: CGPoint(x: lonX, y: row2Y), withAttributes: labelAttrs)
            let lonVal = telemetry.formattedLongitude
            lonVal.draw(at: CGPoint(x: lonX + 55 * scaleFactor, y: row2Y), withAttributes: valueAttrs)
            
            let spdLabel = "SPD: "
            let spdX = lonX + 340 * scaleFactor
            if spdX + 150 * scaleFactor < size.width - pad {
                spdLabel.draw(at: CGPoint(x: spdX, y: row2Y), withAttributes: labelAttrs)
                telemetry.formattedSpeed.draw(at: CGPoint(x: spdX + 50 * scaleFactor, y: row2Y), withAttributes: yellowAttrs)
            }
            
            // Row 3: Altitude, VSI, Heading, G-Load, Pitch & Roll
            let row3Y = 74.0 * scaleFactor * fontMultiplier
            let altLabel = "ALT: "
            altLabel.draw(at: CGPoint(x: pad, y: row3Y), withAttributes: labelAttrs)
            telemetry.formattedAltitude.draw(at: CGPoint(x: pad + 55 * scaleFactor, y: row3Y), withAttributes: cyanAttrs)
            
            let vsiLabel = "VSI: "
            let vsiX = pad + 180 * scaleFactor
            vsiLabel.draw(at: CGPoint(x: vsiX, y: row3Y), withAttributes: labelAttrs)
            telemetry.formattedVSI.draw(at: CGPoint(x: vsiX + 45 * scaleFactor, y: row3Y), withAttributes: valueAttrs)
            
            let hdgLabel = "HDG: "
            let hdgX = pad + 360 * scaleFactor
            hdgLabel.draw(at: CGPoint(x: hdgX, y: row3Y), withAttributes: labelAttrs)
            telemetry.formattedHeading.draw(at: CGPoint(x: hdgX + 55 * scaleFactor, y: row3Y), withAttributes: yellowAttrs)
            
            let gLabel = "G: "
            let gX = pad + 520 * scaleFactor
            gLabel.draw(at: CGPoint(x: gX, y: row3Y), withAttributes: labelAttrs)
            String(format: "%.2fG", telemetry.gForce).draw(at: CGPoint(x: gX + 30 * scaleFactor, y: row3Y), withAttributes: cyanAttrs)
            
            let attStr = String(format: "PITCH: %+05.1f°  ROLL: %+05.1f°", telemetry.pitch, telemetry.roll)
            let attSize = (attStr as NSString).size(withAttributes: titleAttrs)
            attStr.draw(at: CGPoint(x: size.width - pad - attSize.width, y: row3Y - 2.0 * scaleFactor), withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: fontSizeBody, weight: .bold),
                .foregroundColor: hudGreen
            ])
            
            // Draw Center Artificial Horizon HUD
            if telemetry.includeHUD && telemetry.burnHorizon {
                drawCenterHorizonHUD(context: cgContext, size: size, scale: scaleFactor, telemetry: telemetry)
            }
        }
    }
    
    private func drawCenterHorizonHUD(context: CGContext, size: CGSize, scale: CGFloat, telemetry: TelemetrySnapshot) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let isLevel = telemetry.enableLevelSnap && telemetry.isLevel
        let isLandscape = size.width > size.height
        let dynScale: CGFloat = isLandscape
            ? max(0.68, min(1.25, size.height / (420.0 * scale)))
            : max(0.72, min(1.15, size.height / (844.0 * scale)))
        
        // 1. Dynamic Horizon Line & Pitch Ladder (Background layer: rungs scroll behind roll arc & compass)
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(-telemetry.roll * .pi / 180.0))
        
        let pitchPixelsPerDeg: CGFloat = (isLandscape ? 2.5 : 3.6) * dynScale * scale
        let yShift = CGFloat(telemetry.pitch) * pitchPixelsPerDeg
        
        // Horizon Line (0°)
        let pitchDiff0 = abs(telemetry.pitch)
        if pitchDiff0 <= 30.0 {
            let alpha = CGFloat(max(0.0, min(1.0, 1.0 - max(0.0, pitchDiff0 - 22.0) / 8.0)))
            let hudColor = isLevel ? UIColor(red: 0.1, green: 1.0, blue: 0.5, alpha: 0.9 * alpha).cgColor : UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 0.9 * alpha).cgColor
            context.setStrokeColor(hudColor)
            context.setLineWidth(2.5 * dynScale * scale)
            let horizonSpan: CGFloat = (size.width > size.height ? 240 : 200) * dynScale * scale
            context.move(to: CGPoint(x: -horizonSpan, y: yShift))
            context.addLine(to: CGPoint(x: -40 * dynScale * scale, y: yShift))
            context.move(to: CGPoint(x: 40 * dynScale * scale, y: yShift))
            context.addLine(to: CGPoint(x: horizonSpan, y: yShift))
            context.strokePath()
        }
        
        // Pitch steps (scrolling window: displays 3 degree bars above and below)
        for deg in stride(from: -90, through: 90, by: 10) {
            if deg == 0 { continue }
            let diff = abs(Double(deg) - telemetry.pitch)
            guard diff <= 32.0 else { continue }
            let alpha = CGFloat(max(0.0, min(1.0, 1.0 - max(0.0, diff - 26.0) / 6.0)))
            
            let ladderColor = isLevel ? UIColor(red: 0.1, green: 1.0, blue: 0.5, alpha: 0.9 * alpha).cgColor : UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 0.9 * alpha).cgColor
            context.setStrokeColor(ladderColor)
            context.setLineWidth(2.0 * dynScale * scale)
            
            let ladderY = yShift - CGFloat(deg) * pitchPixelsPerDeg
            let w = CGFloat(abs(deg) % 20 == 0 ? 80 : 55) * dynScale * scale
            let tick: CGFloat = (deg > 0 ? 8.0 : -8.0) * dynScale * scale
            
            context.move(to: CGPoint(x: -w, y: ladderY + tick))
            context.addLine(to: CGPoint(x: -w, y: ladderY))
            context.addLine(to: CGPoint(x: -30 * dynScale * scale, y: ladderY))
            
            context.move(to: CGPoint(x: 30 * dynScale * scale, y: ladderY))
            context.addLine(to: CGPoint(x: w, y: ladderY))
            context.addLine(to: CGPoint(x: w, y: ladderY + tick))
            context.strokePath()
        }
        context.restoreGState()
        
        // 2. Circular Rotating Compass (HSI / Directional Rose, occludes pitch ladder rungs)
        let compassRadius: CGFloat = (isLandscape ? 42.0 : 56.0) * dynScale * scale
        let compassOffsetY: CGFloat = (isLandscape ? 88.0 : 148.0) * dynScale * scale
        let compassCenter = CGPoint(x: center.x, y: center.y + compassOffsetY)
        
        // Dark occluding background (blocks pitch ladder rungs as they scroll down behind it)
        context.setFillColor(UIColor(white: 0.0, alpha: 0.88).cgColor)
        context.fillEllipse(in: CGRect(x: compassCenter.x - compassRadius, y: compassCenter.y - compassRadius, width: compassRadius * 2, height: compassRadius * 2))
        
        let hudBorderColor = isLevel ? UIColor(red: 0.1, green: 1.0, blue: 0.5, alpha: 0.7).cgColor : UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 0.7).cgColor
        context.setStrokeColor(hudBorderColor)
        context.setLineWidth(1.5 * dynScale * scale)
        context.strokeEllipse(in: CGRect(x: compassCenter.x - compassRadius, y: compassCenter.y - compassRadius, width: compassRadius * 2, height: compassRadius * 2))
        
        // Rotating compass card
        context.saveGState()
        context.translateBy(x: compassCenter.x, y: compassCenter.y)
        context.rotate(by: CGFloat(-telemetry.heading * .pi / 180.0))
        
        let cr = compassRadius - 2 * dynScale * scale
        for angle in stride(from: 0, to: 360, by: 15) {
            let rad = CGFloat((Double(angle) - 90.0) * .pi / 180.0)
            let isCardinal = angle % 90 == 0
            let isMajor = angle % 30 == 0
            let tickLen: CGFloat = (isCardinal ? 9.0 : (isMajor ? 6.0 : 3.5)) * dynScale * scale
            let startR = cr - tickLen
            
            let x1 = startR * cos(rad)
            let y1 = startR * sin(rad)
            let x2 = cr * cos(rad)
            let y2 = cr * sin(rad)
            
            context.setLineWidth((isCardinal ? 2.0 : (isMajor ? 1.4 : 0.9)) * dynScale * scale)
            let tickColor = isCardinal ? (angle == 0 ? UIColor(red: 1.0, green: 0.35, blue: 0.3, alpha: 1.0).cgColor : UIColor.white.cgColor) : hudBorderColor
            context.setStrokeColor(tickColor)
            context.move(to: CGPoint(x: x1, y: y1))
            context.addLine(to: CGPoint(x: x2, y: y2))
            context.strokePath()
        }
        context.restoreGState()
        
        // Center digital readout
        let deg = Int(round(telemetry.heading)) % 360
        let degStr = String(format: "%03d°", deg)
        let degAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 12.0 * dynScale * scale, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let degSize = (degStr as NSString).size(withAttributes: degAttrs)
        degStr.draw(at: CGPoint(x: compassCenter.x - degSize.width / 2, y: compassCenter.y - degSize.height / 2), withAttributes: degAttrs)
        
        // Fixed Top Lubber Line Pointer (Points downward onto top rim of compass)
        context.setFillColor(UIColor.yellow.cgColor)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.5 * dynScale * scale)
        context.beginPath()
        context.move(to: CGPoint(x: compassCenter.x, y: compassCenter.y - compassRadius + 3.5 * dynScale * scale))
        context.addLine(to: CGPoint(x: compassCenter.x - 5.5 * dynScale * scale, y: compassCenter.y - compassRadius - 6.5 * dynScale * scale))
        context.addLine(to: CGPoint(x: compassCenter.x + 5.5 * dynScale * scale, y: compassCenter.y - compassRadius - 6.5 * dynScale * scale))
        context.closePath()
        context.drawPath(using: .fillStroke)
        
        // 3. Roll Scale Arc & Bank Angle Pointer (Elevated with dark occluding curved bezel to block ladder bars)
        let arcOffsetY: CGFloat = (isLandscape ? 40.0 : 66.0) * dynScale * scale
        let arcCenter = CGPoint(x: center.x, y: center.y - arcOffsetY)
        let rollRadius: CGFloat = (isLandscape ? 54.0 : 86.0) * dynScale * scale
        let arcColor = isLevel ? UIColor(red: 0.1, green: 1.0, blue: 0.5, alpha: 0.85).cgColor : UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 0.85).cgColor
        let pointerColor = isLevel ? UIColor(red: 0.1, green: 1.0, blue: 0.5, alpha: 1.0).cgColor : UIColor.yellow.cgColor
        
        // Dark occluding curved bezel backing (blocks pitch ladder rungs as they scroll behind roll arc)
        let innerBezelR = rollRadius - (18 * dynScale * scale)
        let outerBezelR = rollRadius + (26 * dynScale * scale)
        let bezelSpanRad = CGFloat(75.0 * .pi / 180.0)
        let bStartRad = CGFloat(-90.0 * .pi / 180.0) - bezelSpanRad
        let bEndRad = CGFloat(-90.0 * .pi / 180.0) + bezelSpanRad
        
        context.beginPath()
        context.addArc(center: arcCenter, radius: outerBezelR, startAngle: bStartRad, endAngle: bEndRad, clockwise: false)
        context.addArc(center: arcCenter, radius: innerBezelR, startAngle: bEndRad, endAngle: bStartRad, clockwise: true)
        context.closePath()
        context.setFillColor(UIColor(white: 0.0, alpha: 0.88).cgColor)
        context.setStrokeColor(UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 0.35).cgColor)
        context.setLineWidth(1.2 * dynScale * scale)
        context.drawPath(using: .fillStroke)
        
        // Arc (-60° to +60°)
        context.setStrokeColor(arcColor)
        context.setLineWidth(1.8 * dynScale * scale)
        let startRad = CGFloat((-90.0 - 60.0) * .pi / 180.0)
        let endRad = CGFloat((-90.0 + 60.0) * .pi / 180.0)
        context.addArc(center: arcCenter, radius: rollRadius, startAngle: startRad, endAngle: endRad, clockwise: false)
        context.strokePath()
        
        // Zero-roll top index mark
        context.setFillColor(UIColor.white.cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: arcCenter.x, y: arcCenter.y - rollRadius - 2 * dynScale * scale))
        context.addLine(to: CGPoint(x: arcCenter.x - 5 * dynScale * scale, y: arcCenter.y - rollRadius - 9 * dynScale * scale))
        context.addLine(to: CGPoint(x: arcCenter.x + 5 * dynScale * scale, y: arcCenter.y - rollRadius - 9 * dynScale * scale))
        context.closePath()
        context.fillPath()
        
        // Ticks & Numeric Labels
        let tickAngles = [-60.0, -45.0, -30.0, -20.0, -10.0, 10.0, 20.0, 30.0, 45.0, 60.0]
        let fontSz = 7.5 * dynScale * scale * telemetry.fontSize.scaleMultiplier
        let lblFont = UIFont.monospacedSystemFont(ofSize: fontSz, weight: .bold)
        let lblAttrs: [NSAttributedString.Key: Any] = [
            .font: lblFont,
            .foregroundColor: UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 0.9)
        ]
        for angle in tickAngles {
            let rad = CGFloat((angle - 90.0) * .pi / 180.0)
            let isMajor = abs(angle) == 30 || abs(angle) == 60
            let tickLen: CGFloat = (isMajor ? 10.0 : (abs(angle) == 45 ? 7.0 : 4.5)) * dynScale * scale
            let innerX = arcCenter.x + rollRadius * cos(rad)
            let innerY = arcCenter.y + rollRadius * sin(rad)
            let outerX = arcCenter.x + (rollRadius + tickLen) * cos(rad)
            let outerY = arcCenter.y + (rollRadius + tickLen) * sin(rad)
            context.move(to: CGPoint(x: innerX, y: innerY))
            context.addLine(to: CGPoint(x: outerX, y: outerY))
            context.strokePath()
            
            if isMajor {
                let labelDist = rollRadius + (18 * dynScale * scale)
                let lblX = arcCenter.x + labelDist * cos(rad)
                let lblY = arcCenter.y + labelDist * sin(rad)
                let str = "\(Int(abs(angle)))"
                let sSize = (str as NSString).size(withAttributes: lblAttrs)
                (str as NSString).draw(at: CGPoint(x: lblX - sSize.width / 2, y: lblY - sSize.height / 2), withAttributes: lblAttrs)
            }
        }
        
        // Roll Pointer
        let clampedRoll = max(-75.0, min(75.0, telemetry.roll))
        let pAngle = CGFloat((clampedRoll - 90.0) * .pi / 180.0)
        let tipX = arcCenter.x + (rollRadius - 2 * dynScale * scale) * cos(pAngle)
        let tipY = arcCenter.y + (rollRadius - 2 * dynScale * scale) * sin(pAngle)
        let baseRadius = rollRadius - 14 * dynScale * scale
        let angleOffset: CGFloat = 0.08
        let base1X = arcCenter.x + baseRadius * cos(pAngle - angleOffset)
        let base1Y = arcCenter.y + baseRadius * sin(pAngle - angleOffset)
        let base2X = arcCenter.x + baseRadius * cos(pAngle + angleOffset)
        let base2Y = arcCenter.y + baseRadius * sin(pAngle + angleOffset)
        
        context.beginPath()
        context.move(to: CGPoint(x: tipX, y: tipY))
        context.addLine(to: CGPoint(x: base1X, y: base1Y))
        context.addLine(to: CGPoint(x: base2X, y: base2Y))
        context.closePath()
        context.setFillColor(pointerColor)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(2.0 * dynScale * scale)
        context.drawPath(using: .fillStroke)
        
        // 4. Fixed Boresight Aircraft Reticle (Top Center)
        let reticleColor = isLevel ? UIColor(red: 0.1, green: 1.0, blue: 0.5, alpha: 1.0).cgColor : UIColor.yellow.cgColor
        context.setStrokeColor(reticleColor)
        context.setLineWidth(2.2 * dynScale * scale)
        
        // Center Dot
        context.setFillColor(reticleColor)
        context.fillEllipse(in: CGRect(x: center.x - 3 * dynScale * scale, y: center.y - 3 * dynScale * scale, width: 6 * dynScale * scale, height: 6 * dynScale * scale))
        
        // Ring
        context.strokeEllipse(in: CGRect(x: center.x - 10 * dynScale * scale, y: center.y - 10 * dynScale * scale, width: 20 * dynScale * scale, height: 20 * dynScale * scale))
        
        // Left & Right Wings
        let wingLen = 42.0 * dynScale * scale
        let wingGap = 15.0 * dynScale * scale
        let wingDrop = 6.0 * dynScale * scale
        context.move(to: CGPoint(x: center.x - wingLen, y: center.y))
        context.addLine(to: CGPoint(x: center.x - wingGap, y: center.y))
        context.addLine(to: CGPoint(x: center.x - wingGap, y: center.y + wingDrop))
        
        context.move(to: CGPoint(x: center.x + wingLen, y: center.y))
        context.addLine(to: CGPoint(x: center.x + wingGap, y: center.y))
        context.addLine(to: CGPoint(x: center.x + wingGap, y: center.y + wingDrop))
        context.strokePath()
    }
    
    // MARK: - Direct Single-Pass EXIF & GPS Metadata Embedding
    private func addMetadata(to image: UIImage, telemetry: TelemetrySnapshot, jsonPayload: String) -> Data? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        let uti = UTType.jpeg.identifier as CFString
        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(outputData, uti, 1, nil) else {
            return nil
        }
        
        var metadata: [CFString: Any] = [:]
        metadata[kCGImageDestinationLossyCompressionQuality] = 0.90
        
        // Build GPS Dictionary
        var gpsDict: [CFString: Any] = [:]
        if let coord = telemetry.coordinate {
            gpsDict[kCGImagePropertyGPSLatitude] = abs(coord.latitude)
            gpsDict[kCGImagePropertyGPSLatitudeRef] = coord.latitude >= 0 ? "N" : "S"
            gpsDict[kCGImagePropertyGPSLongitude] = abs(coord.longitude)
            gpsDict[kCGImagePropertyGPSLongitudeRef] = coord.longitude >= 0 ? "E" : "W"
        }
        
        gpsDict[kCGImagePropertyGPSAltitude] = abs(telemetry.altitude)
        gpsDict[kCGImagePropertyGPSAltitudeRef] = telemetry.altitude >= 0 ? 0 : 1
        
        if telemetry.heading >= 0 {
            gpsDict[kCGImagePropertyGPSImgDirection] = telemetry.heading
            gpsDict[kCGImagePropertyGPSImgDirectionRef] = telemetry.headingType == .trueNorth ? "T" : "M"
        }
        
        if telemetry.speed >= 0 {
            gpsDict[kCGImagePropertyGPSSpeed] = telemetry.speed * 3.6 // km/h
            gpsDict[kCGImagePropertyGPSSpeedRef] = "K"
        }
        
        // GPS Track & Reference
        let trackCourse = telemetry.trueHeading > 0 ? telemetry.trueHeading : telemetry.heading
        if trackCourse >= 0 {
            gpsDict[kCGImagePropertyGPSTrack] = trackCourse
            gpsDict[kCGImagePropertyGPSTrackRef] = telemetry.headingType == .trueNorth ? "T" : "M"
        }
        
        // Horizontal Positioning Error (Accuracy in meters)
        if telemetry.horizontalAccuracy >= 0 {
            gpsDict[kCGImagePropertyGPSHPositioningError] = telemetry.horizontalAccuracy
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = TimeZone(abbreviation: "UTC")
        timeFormatter.dateFormat = "HH:mm:ss"
        gpsDict[kCGImagePropertyGPSTimeStamp] = timeFormatter.string(from: telemetry.timestamp)
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "yyyy:MM:dd"
        gpsDict[kCGImagePropertyGPSDateStamp] = dateFormatter.string(from: telemetry.timestamp)
        
        metadata[kCGImagePropertyGPSDictionary] = gpsDict
        
        // Build EXIF Dictionary
        var exifDict: [CFString: Any] = [:]
        exifDict[kCGImagePropertyExifUserComment] = jsonPayload
        
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateTimeFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let dateStr = dateTimeFormatter.string(from: telemetry.timestamp)
        exifDict[kCGImagePropertyExifDateTimeOriginal] = dateStr
        exifDict[kCGImagePropertyExifDateTimeDigitized] = dateStr
        
        metadata[kCGImagePropertyExifDictionary] = exifDict
        
        // Build TIFF Dictionary
        var tiffDict: [CFString: Any] = [:]
        tiffDict[kCGImagePropertyTIFFSoftware] = "TelemetryCamera 1.0 (AttitudeCam)"
        tiffDict[kCGImagePropertyTIFFDateTime] = dateStr
        let noteStr = telemetry.customNote.isEmpty ? "" : "Note=\(telemetry.customNote), "
        let telemetrySummary = String(
            format: "%@Pitch=%.2f deg, Roll=%.2f deg, Heading=%.1f deg, Altitude=%.1f m, Speed=%.1f m/s, Baro=%.1f hPa, Acc=%.1f m",
            noteStr, telemetry.pitch, telemetry.roll, telemetry.heading, telemetry.altitude, telemetry.speed, telemetry.barometricPressure, telemetry.horizontalAccuracy
        )
        tiffDict[kCGImagePropertyTIFFImageDescription] = telemetrySummary
        if !telemetry.customNote.isEmpty {
            tiffDict[kCGImagePropertyTIFFArtist] = telemetry.customNote
        }
        metadata[kCGImagePropertyTIFFDictionary] = tiffDict
        
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return outputData as Data
    }
    
    // MARK: - Save to Photo Library
    private func saveToPhotoLibrary(data: Data) async throws -> String? {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return nil
        }
        
        var localId: String?
        try await PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            creationRequest.addResource(with: .photo, data: data, options: options)
            localId = creationRequest.placeholderForCreatedAsset?.localIdentifier
        }
        return localId
    }
}
