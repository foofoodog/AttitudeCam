import SwiftUI

struct GPSOverlayView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var settings: AppSettings
    var isLandscape: Bool = false
    
    private func fs(_ base: CGFloat) -> CGFloat {
        settings.fontSize.size(base)
    }
    
    var body: some View {
        Group {
            if isLandscape {
                landscapeCard
            } else {
                portraitCard
            }
        }
    }
    
    // MARK: - Portrait Layout Card
    private var portraitCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header Row: Status, Custom Note & Timestamp
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(locationManager.coordinate != nil ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text("GPS FIX: \(locationManager.formattedAccuracy)")
                        .font(.system(size: fs(10), weight: .bold, design: .monospaced))
                        .foregroundColor(Color.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                if !settings.customNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(settings.customNote.uppercased())
                        .font(.system(size: fs(9), weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(red: 0.2, green: 1.0, blue: 0.4))
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                Text(Date(), formatter: Self.timeFormatter)
                    .font(.system(size: fs(10), weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            
            // Coordinates Rows (if enabled)
            if settings.showCoordinates {
                Divider()
                    .background(Color.white.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("LAT:")
                            .font(.system(size: fs(10), weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Text(locationManager.formattedLatitude)
                            .font(.system(size: fs(11), weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(locationManager.decimalLatitude)
                            .font(.system(size: fs(10), weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    HStack {
                        Text("LON:")
                            .font(.system(size: fs(10), weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Text(locationManager.formattedLongitude)
                            .font(.system(size: fs(11), weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(locationManager.decimalLongitude)
                            .font(.system(size: fs(10), weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            
            // Instrument Data Rows (Speed, Altitude, VSI, Heading)
            if settings.showSpeed || settings.showAltitude || settings.showVSI || settings.showHeading {
                Divider()
                    .background(Color.white.opacity(0.2))
                
                let instrumentCount = (settings.showAltitude ? 1 : 0) + (settings.showVSI ? 1 : 0) + (settings.showSpeed ? 1 : 0) + (settings.showHeading ? 1 : 0)
                
                if instrumentCount <= 2 {
                    // Single row when 1 or 2 items enabled
                    HStack {
                        if settings.showAltitude {
                            HStack(spacing: 3) {
                                Text("ALT:")
                                    .font(.system(size: fs(10), weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(locationManager.formattedAltitude(unit: settings.altitudeUnit))
                                    .font(.system(size: fs(11), weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.3, green: 0.9, blue: 1.0))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        
                        if settings.showVSI {
                            HStack(spacing: 3) {
                                Text("VSI:")
                                    .font(.system(size: fs(9), weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(locationManager.formattedVerticalSpeed(unit: settings.altitudeUnit))
                                    .font(.system(size: fs(10), weight: .semibold, design: .monospaced))
                                    .foregroundColor(locationManager.verticalSpeed >= 0 ? Color.green : Color.orange)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        
                        Spacer()
                        
                        if settings.showSpeed {
                            HStack(spacing: 3) {
                                Text("SPD:")
                                    .font(.system(size: fs(10), weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(locationManager.formattedSpeed(unit: settings.speedUnit))
                                    .font(.system(size: fs(11), weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.3))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        
                        if settings.showHeading {
                            HStack(spacing: 3) {
                                Text("HDG:")
                                    .font(.system(size: fs(10), weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(locationManager.formattedHeading(type: settings.headingType))
                                    .font(.system(size: fs(11), weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color.yellow)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                } else {
                    // Stable 2-row layout when 3 or 4 instruments enabled (never overflows or wraps vertically)
                    VStack(spacing: 3) {
                        HStack {
                            if settings.showAltitude {
                                HStack(spacing: 3) {
                                    Text("ALT:")
                                        .font(.system(size: fs(10), weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(locationManager.formattedAltitude(unit: settings.altitudeUnit))
                                        .font(.system(size: fs(11), weight: .semibold, design: .monospaced))
                                        .foregroundColor(Color(red: 0.3, green: 0.9, blue: 1.0))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            
                            Spacer()
                            
                            if settings.showVSI {
                                HStack(spacing: 3) {
                                    Text("VSI:")
                                        .font(.system(size: fs(9), weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(locationManager.formattedVerticalSpeed(unit: settings.altitudeUnit))
                                        .font(.system(size: fs(10), weight: .semibold, design: .monospaced))
                                        .foregroundColor(locationManager.verticalSpeed >= 0 ? Color.green : Color.orange)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                        }
                        
                        HStack {
                            if settings.showSpeed {
                                HStack(spacing: 3) {
                                    Text("SPD:")
                                        .font(.system(size: fs(10), weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(locationManager.formattedSpeed(unit: settings.speedUnit))
                                        .font(.system(size: fs(11), weight: .semibold, design: .monospaced))
                                        .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.3))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            
                            Spacer()
                            
                            if settings.showHeading {
                                HStack(spacing: 3) {
                                    Text("HDG:")
                                        .font(.system(size: fs(10), weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(locationManager.formattedHeading(type: settings.headingType))
                                        .font(.system(size: fs(11), weight: .semibold, design: .monospaced))
                                        .foregroundColor(Color.yellow)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Landscape Compact Bar
    private var landscapeCard: some View {
        HStack(spacing: settings.fontSize == .small ? 8 : 6) {
            // Fix Indicator
            HStack(spacing: 3) {
                Circle()
                    .fill(locationManager.coordinate != nil ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(locationManager.formattedAccuracy)
                    .font(.system(size: fs(9), weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .lineLimit(1)
            }
            
            if !settings.customNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(settings.customNote.uppercased())
                    .font(.system(size: fs(8), weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(red: 0.2, green: 1.0, blue: 0.4))
                    .clipShape(Capsule())
            }
            
            // Coordinates
            if settings.showCoordinates {
                Text("\(locationManager.formattedLatitude) \(locationManager.formattedLongitude)")
                    .font(.system(size: fs(9), weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            // Speed
            if settings.showSpeed {
                Text("SPD:\(locationManager.formattedSpeed(unit: settings.speedUnit))")
                    .font(.system(size: fs(9), weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.3))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            // Altitude & VSI
            if settings.showAltitude {
                Text("ALT:\(locationManager.formattedAltitude(unit: settings.altitudeUnit))")
                    .font(.system(size: fs(9), weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(red: 0.3, green: 0.9, blue: 1.0))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            // Heading
            if settings.showHeading {
                Text("HDG:\(locationManager.formattedHeading(type: settings.headingType))")
                    .font(.system(size: fs(9), weight: .semibold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            Spacer(minLength: 2)
            
            // Time
            Text(Date(), formatter: Self.timeFormatter)
                .font(.system(size: fs(9), weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
        .frame(height: 30)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss 'UTC'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}
