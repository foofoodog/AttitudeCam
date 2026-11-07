import SwiftUI

struct ArtificialHorizonView: View {
    let pitch: Double // in degrees
    let roll: Double  // in degrees
    var heading: Double = 0.0 // in degrees
    var headingType: HeadingType = .trueNorth
    var showHeading: Bool = true
    var gForce: Double = 1.0
    var isLevel: Bool = false
    var showGMeter: Bool = true
    var enableLevelSnap: Bool = true
    var fontSize: DisplayFontSize = .small
    
    // Scaling factor: points per degree of pitch (dynamically computed in body)
    private let basePitchScale: CGFloat = 3.6
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let isLandscape = size.width > size.height
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            
            // Dynamic scale factor based on screen height and orientation:
            // Ensures UI fits cleanly without overlaps on iPhone SE (375x667), modern iPhones (393x852), and iPads (768x1024+)
            let scale: CGFloat = isLandscape
                ? max(0.68, min(1.25, size.height / 420.0))
                : max(0.72, min(1.15, size.height / 844.0))
            
            // Dynamic pitch scale: keeps degree rungs visible without crowding
            let dynamicPitchScale: CGFloat = (isLandscape ? 2.5 : 3.6) * scale
            
            // Raised roll arc so its bottom ends sit clearly above 3 ladder bars (+30°)
            // Sized dynamically with guaranteed clearance below the top HUD card
            let rollRadius: CGFloat = (isLandscape ? 52.0 : 80.0) * scale
            let arcOffsetY: CGFloat = (isLandscape ? 38.0 : 64.0) * scale
            let arcCenter = CGPoint(x: center.x, y: center.y - arcOffsetY)
            
            // Circular compass lowered below 3 ladder bars (-30°)
            // Sized dynamically with guaranteed clearance above the bottom text bubble
            let compassRadius: CGFloat = (isLandscape ? 40.0 : 52.0) * scale
            let compassOffsetY: CGFloat = (isLandscape ? 84.0 : 138.0) * scale
            let compassCenter = CGPoint(x: center.x, y: center.y + compassOffsetY)
            
            // Bottom text bubble padding:
            // In portrait: sits cleanly above the shutter button (taking into account safe area insets and shutter height)
            // In landscape: sits cleanly above the bottom edge safe area
            let bottomSafeArea = geometry.safeAreaInsets.bottom
            let shutterTopOffset = bottomSafeArea + 24.0 + 72.0 // safe area + padding (24) + shutter diameter (72)
            let bottomPadding: CGFloat = isLandscape
                ? max(8.0, bottomSafeArea + 6.0)
                : shutterTopOffset + (14.0 * scale)
            let levelActive = enableLevelSnap && isLevel
            
            ZStack {
                // 1. Rotating and Pitch-moving Horizon System
                HorizonLadder(pitch: pitch, pitchScale: dynamicPitchScale, scale: scale, center: center, size: size, isLevel: levelActive, fontSize: fontSize)
                    .rotationEffect(.degrees(-roll), anchor: .center)
                
                // 2. Circular Rotating Compass (Under the scroll ladder, occluding it when ladder scrolls down)
                if showHeading {
                    RotatingCompassView(
                        heading: heading,
                        headingType: headingType,
                        radius: compassRadius,
                        isLevel: levelActive,
                        fontSize: fontSize
                    )
                    .position(compassCenter)
                }
                
                // 3. Roll Scale Arc & Dynamic Bank Pointer (Elevated cleanly above pitch ladder)
                RollScaleConcentricView(center: arcCenter, radius: rollRadius, roll: roll, scale: scale, isLevel: levelActive, fontSize: fontSize)
                
                // 4. Fixed Boresight Aircraft Reticle (Center)
                AircraftReticleView(isLevel: levelActive, scale: scale)
                    .position(center)
                
                // 5. Pitch and Roll Digital Badges
                VStack {
                    Spacer()
                    HStack(spacing: isLandscape ? 8 : 12) {
                        Text(String(format: "PITCH: %+05.1f°", pitch))
                            .lineLimit(1)
                        Text(String(format: "ROLL: %+05.1f°", roll))
                            .lineLimit(1)
                        
                        if showGMeter {
                            Text(String(format: "%.2fG", gForce))
                                .foregroundColor(Color(red: 0.3, green: 0.9, blue: 1.0))
                                .lineLimit(1)
                        }
                        
                        if levelActive {
                            HStack(spacing: 4) {
                                Circle().fill(Color(red: 0.2, green: 1.0, blue: 0.4)).frame(width: 6, height: 6)
                                Text("LEVEL")
                            }
                            .foregroundColor(Color(red: 0.2, green: 1.0, blue: 0.4))
                            .lineLimit(1)
                        }
                    }
                    .font(.system(size: isLandscape ? fontSize.size(10) : fontSize.size(11), weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.2, green: 1.0, blue: 0.4))
                    .padding(.horizontal, isLandscape ? 8 : 12)
                    .padding(.vertical, isLandscape ? 3 : 5)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(levelActive ? Color(red: 0.2, green: 1.0, blue: 0.4) : Color.white.opacity(0.3), lineWidth: levelActive ? 1.5 : 1)
                    )
                    .padding(.bottom, bottomPadding)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Pitch Ladder & Horizon Line
private struct HorizonLadder: View {
    let pitch: Double
    let pitchScale: CGFloat
    var scale: CGFloat = 1.0
    let center: CGPoint
    let size: CGSize
    var isLevel: Bool = false
    var fontSize: DisplayFontSize = .small
    
    var body: some View {
        Canvas { context, canvasSize in
            let cX = canvasSize.width / 2
            let cY = canvasSize.height / 2 + CGFloat(pitch) * pitchScale
            
            let hudColor = isLevel ? Color(red: 0.1, green: 1.0, blue: 0.5) : Color(red: 0.2, green: 1.0, blue: 0.4)
            let hudStroke = StrokeStyle(lineWidth: (isLevel ? 2.5 : 2.0) * scale, lineCap: .round)
            let dashedStroke = StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round, dash: [6 * scale, 4 * scale])
            let gap: CGFloat = 40 * scale
            
            // 1. Horizon Line (0°)
            let pitchDiff0 = abs(pitch)
            if pitchDiff0 <= 30.0 {
                let alpha = max(0.0, min(1.0, 1.0 - max(0.0, pitchDiff0 - 22.0) / 8.0))
                let lineLength: CGFloat = 135 * scale
                
                // Left horizon bar
                var leftHorizon = Path()
                leftHorizon.move(to: CGPoint(x: cX - gap - lineLength, y: cY))
                leftHorizon.addLine(to: CGPoint(x: cX - gap, y: cY))
                context.stroke(leftHorizon, with: .color(hudColor.opacity(alpha)), style: hudStroke)
                
                // Right horizon bar
                var rightHorizon = Path()
                rightHorizon.move(to: CGPoint(x: cX + gap, y: cY))
                rightHorizon.addLine(to: CGPoint(x: cX + gap + lineLength, y: cY))
                context.stroke(rightHorizon, with: .color(hudColor.opacity(alpha)), style: hudStroke)
            }
            
            // 2. Pitch Ladder Steps (scrolling window: displays 3 degree bars above and below horizon)
            for deg in stride(from: -90, through: 90, by: 10) {
                if deg == 0 { continue }
                
                let diff = abs(Double(deg) - pitch)
                guard diff <= 32.0 else { continue }
                let alpha = max(0.0, min(1.0, 1.0 - max(0.0, diff - 26.0) / 6.0))
                
                let yPos = cY - CGFloat(deg) * pitchScale
                let rungWidth: CGFloat = 44 * scale
                let tickHeight: CGFloat = (deg > 0 ? 7.0 : -7.0) * scale
                let isDashed = deg < 0
                
                // Left rung
                var leftRung = Path()
                leftRung.move(to: CGPoint(x: cX - gap - rungWidth, y: yPos))
                leftRung.addLine(to: CGPoint(x: cX - gap, y: yPos))
                leftRung.addLine(to: CGPoint(x: cX - gap, y: yPos + tickHeight))
                
                // Downward/upward tick at the outer end
                leftRung.move(to: CGPoint(x: cX - gap - rungWidth, y: yPos))
                leftRung.addLine(to: CGPoint(x: cX - gap - rungWidth, y: yPos + tickHeight))
                
                context.stroke(leftRung, with: .color(hudColor.opacity(alpha)), style: isDashed ? dashedStroke : hudStroke)
                
                // Right rung
                var rightRung = Path()
                rightRung.move(to: CGPoint(x: cX + gap, y: yPos))
                rightRung.addLine(to: CGPoint(x: cX + gap + rungWidth, y: yPos))
                rightRung.addLine(to: CGPoint(x: cX + gap, y: yPos + tickHeight))
                
                rightRung.move(to: CGPoint(x: cX + gap + rungWidth, y: yPos))
                rightRung.addLine(to: CGPoint(x: cX + gap + rungWidth, y: yPos + tickHeight))
                
                context.stroke(rightRung, with: .color(hudColor.opacity(alpha)), style: isDashed ? dashedStroke : hudStroke)
                
                // Degree Text Label
                let text = Text("\(abs(deg))")
                    .font(.system(size: fontSize.size(max(7, 8.5 * scale)), weight: .bold, design: .monospaced))
                    .foregroundColor(hudColor.opacity(alpha))
                
                context.draw(text, at: CGPoint(x: cX - gap - rungWidth - (12 * scale), y: yPos), anchor: .trailing)
                context.draw(text, at: CGPoint(x: cX + gap + rungWidth + (12 * scale), y: yPos), anchor: .leading)
            }
        }
    }
}

// MARK: - Concentric Roll Scale Arc & Bank Angle Pointer
private struct RollScaleConcentricView: View {
    let center: CGPoint
    let radius: CGFloat
    let roll: Double
    var scale: CGFloat = 1.0
    var isLevel: Bool = false
    var fontSize: DisplayFontSize = .small
    
    var body: some View {
        Canvas { context, size in
            let arcColor = isLevel ? Color(red: 0.1, green: 1.0, blue: 0.5) : Color(red: 0.2, green: 1.0, blue: 0.4)
            let pointerColor = isLevel ? Color(red: 0.1, green: 1.0, blue: 0.5) : Color.yellow
            let stroke = StrokeStyle(lineWidth: 1.8 * scale, lineCap: .round)
            
            // 0. Dark Occluding Curved Bezel (Completely blocks pitch ladder as it scrolls into roll arc space)
            let innerBezelR = radius - (18 * scale)
            let outerBezelR = radius + (26 * scale)
            let bezelSpanDeg: Double = 75.0 // Spans -75° to +75° to cover full pointer range, ticks, and labels
            
            var bezelPath = Path()
            bezelPath.addArc(
                center: center,
                radius: outerBezelR,
                startAngle: .degrees(-90 - bezelSpanDeg),
                endAngle: .degrees(-90 + bezelSpanDeg),
                clockwise: false
            )
            bezelPath.addArc(
                center: center,
                radius: innerBezelR,
                startAngle: .degrees(-90 + bezelSpanDeg),
                endAngle: .degrees(-90 - bezelSpanDeg),
                clockwise: true
            )
            bezelPath.closeSubpath()
            
            // Fill with dark opaque backing to block underlying pitch ladder rungs
            context.fill(bezelPath, with: .color(Color.black.opacity(0.88)))
            context.stroke(bezelPath, with: .color(arcColor.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2 * scale, lineJoin: .round))
            
            // 1. Draw Fixed Roll Scale Arc (-60° to +60°)
            var arcPath = Path()
            arcPath.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90 - 60),
                endAngle: .degrees(-90 + 60),
                clockwise: false
            )
            context.stroke(arcPath, with: .color(arcColor.opacity(0.85)), style: stroke)
            
            // 2. Fixed Zero-Roll Index Mark at Top Center (0° bank angle)
            var zeroIndex = Path()
            zeroIndex.move(to: CGPoint(x: center.x, y: center.y - radius - (2 * scale)))
            zeroIndex.addLine(to: CGPoint(x: center.x - (5 * scale), y: center.y - radius - (9 * scale)))
            zeroIndex.addLine(to: CGPoint(x: center.x + (5 * scale), y: center.y - radius - (9 * scale)))
            zeroIndex.closeSubpath()
            context.fill(zeroIndex, with: .color(Color.white.opacity(0.9)))
            
            // 3. Tick Marks & Angle Labels (Drawn Outward)
            let tickAngles = [-60.0, -45.0, -30.0, -20.0, -10.0, 10.0, 20.0, 30.0, 45.0, 60.0]
            for angle in tickAngles {
                let rad = (angle - 90.0) * .pi / 180.0
                let isMajor = abs(angle) == 30 || abs(angle) == 60
                let is45 = abs(angle) == 45
                let tickLen: CGFloat = (isMajor ? 10.0 : (is45 ? 7.0 : 4.5)) * scale
                
                let innerX = center.x + radius * cos(rad)
                let innerY = center.y + radius * sin(rad)
                let outerX = center.x + (radius + tickLen) * cos(rad)
                let outerY = center.y + (radius + tickLen) * sin(rad)
                
                var tick = Path()
                tick.move(to: CGPoint(x: innerX, y: innerY))
                tick.addLine(to: CGPoint(x: outerX, y: outerY))
                context.stroke(tick, with: .color(arcColor.opacity(0.85)), style: stroke)
                
                // Numeric Labels at 30° and 60°
                if isMajor {
                    let labelDist = radius + (18 * scale)
                    let lblX = center.x + labelDist * cos(rad)
                    let lblY = center.y + labelDist * sin(rad)
                    let labelText = Text("\(Int(abs(angle)))")
                        .font(.system(size: fontSize.size(max(7, 8 * scale)), weight: .bold, design: .monospaced))
                        .foregroundColor(arcColor.opacity(0.9))
                    context.draw(labelText, at: CGPoint(x: lblX, y: lblY), anchor: .center)
                }
            }
            
            // 4. Dynamic Roll Pointer (Bank Angle Indicator)
            let clampedRoll = max(-75.0, min(75.0, roll))
            let pAngle = (clampedRoll - 90.0) * .pi / 180.0
            
            let tipX = center.x + (radius - (2 * scale)) * cos(pAngle)
            let tipY = center.y + (radius - (2 * scale)) * sin(pAngle)
            
            let baseRadius = radius - (14 * scale)
            let angleOffset = 0.08
            let base1X = center.x + baseRadius * cos(pAngle - angleOffset)
            let base1Y = center.y + baseRadius * sin(pAngle - angleOffset)
            let base2X = center.x + baseRadius * cos(pAngle + angleOffset)
            let base2Y = center.y + baseRadius * sin(pAngle + angleOffset)
            
            var pointerPath = Path()
            pointerPath.move(to: CGPoint(x: tipX, y: tipY))
            pointerPath.addLine(to: CGPoint(x: base1X, y: base1Y))
            pointerPath.addLine(to: CGPoint(x: base2X, y: base2Y))
            pointerPath.closeSubpath()
            
            context.stroke(pointerPath, with: .color(Color.black.opacity(0.8)), style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round, lineJoin: .round))
            context.fill(pointerPath, with: .color(pointerColor))
        }
    }
}

// MARK: - Fixed Aircraft Reticle
private struct AircraftReticleView: View {
    var isLevel: Bool = false
    var scale: CGFloat = 1.0
    
    var body: some View {
        let reticleColor = isLevel ? Color(red: 0.1, green: 1.0, blue: 0.5) : Color.yellow
        let wingLen: CGFloat = 42.0 * scale
        let wingGap: CGFloat = 15.0 * scale
        let wingDrop: CGFloat = 6.0 * scale
        let ringR: CGFloat = 20.0 * scale
        let dotR: CGFloat = 5.5 * scale
        
        ZStack {
            if isLevel {
                Circle()
                    .stroke(reticleColor.opacity(0.4), lineWidth: 3.5 * scale)
                    .frame(width: 28 * scale, height: 28 * scale)
            }
            
            // Center Dot
            Circle()
                .fill(reticleColor)
                .frame(width: dotR, height: dotR)
            
            // Center Ring
            Circle()
                .stroke(reticleColor, lineWidth: (isLevel ? 2.0 : 1.5) * scale)
                .frame(width: ringR, height: ringR)
            
            // Left Wing
            Path { path in
                path.move(to: CGPoint(x: -wingLen, y: 0))
                path.addLine(to: CGPoint(x: -wingGap, y: 0))
                path.addLine(to: CGPoint(x: -wingGap, y: wingDrop))
            }
            .stroke(reticleColor, style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round, lineJoin: .round))
            
            // Right Wing
            Path { path in
                path.move(to: CGPoint(x: wingLen, y: 0))
                path.addLine(to: CGPoint(x: wingGap, y: 0))
                path.addLine(to: CGPoint(x: wingGap, y: wingDrop))
            }
            .stroke(reticleColor, style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Circular Rotating Compass (HSI / Directional Rose)
private struct RotatingCompassView: View {
    let heading: Double // in degrees (0 - 359.9)
    let headingType: HeadingType
    let radius: CGFloat
    var isLevel: Bool = false
    var fontSize: DisplayFontSize = .small
    
    var body: some View {
        let hudGreen = isLevel ? Color(red: 0.1, green: 1.0, blue: 0.5) : Color(red: 0.2, green: 1.0, blue: 0.4)
        let strokeColor = hudGreen.opacity(0.85)
        let cardinalColor = Color.white
        let northColor = Color(red: 1.0, green: 0.35, blue: 0.3)
        let deg = Int(round(heading)) % 360
        
        ZStack {
            // 1. Solid Dark Occluding Base (Completely blocks pitch ladder as it scrolls down)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.85), Color.black.opacity(0.95)]),
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .overlay(
                    Circle()
                        .stroke(strokeColor.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)
            
            // 2. Rotating Compass Rose Card
            Canvas { context, size in
                let cX = size.width / 2
                let cY = size.height / 2
                let r = radius - 2
                
                // Outer dial ring
                var ring = Path()
                ring.addEllipse(in: CGRect(x: cX - r, y: cY - r, width: r * 2, height: r * 2))
                context.stroke(ring, with: .color(strokeColor.opacity(0.7)), lineWidth: 1.2)
                
                // Inner concentric ring
                let innerR = r - (radius >= 60 ? 14 : 10)
                if innerR > 15 {
                    var innerRing = Path()
                    innerRing.addEllipse(in: CGRect(x: cX - innerR, y: cY - innerR, width: innerR * 2, height: innerR * 2))
                    context.stroke(innerRing, with: .color(strokeColor.opacity(0.3)), lineWidth: 0.8)
                }
                
                // Tick Marks (Every 15° minor, every 30° major, every 90° cardinal)
                for angle in stride(from: 0, to: 360, by: 15) {
                    let rad = CGFloat((Double(angle) - 90.0) * .pi / 180.0)
                    let isCardinal = angle % 90 == 0
                    let isMajor = angle % 30 == 0
                    let tickLen: CGFloat = isCardinal ? (radius >= 60 ? 10.0 : 8.0) : (isMajor ? (radius >= 60 ? 7.0 : 5.5) : 3.5)
                    let startR = r - tickLen
                    
                    let x1 = cX + startR * cos(rad)
                    let y1 = cY + startR * sin(rad)
                    let x2 = cX + r * cos(rad)
                    let y2 = cY + r * sin(rad)
                    
                    var tick = Path()
                    tick.move(to: CGPoint(x: x1, y: y1))
                    tick.addLine(to: CGPoint(x: x2, y: y2))
                    context.stroke(
                        tick,
                        with: .color(isCardinal ? (angle == 0 ? northColor : Color.white) : strokeColor.opacity(0.75)),
                        lineWidth: isCardinal ? 2.2 : (isMajor ? 1.5 : 1.0)
                    )
                    
                    // Cardinal & Degree Number Labels
                    if isCardinal || (isMajor && radius >= 45) {
                        let labelDist = r - (radius >= 60 ? 22 : 18)
                        let lx = cX + labelDist * cos(rad)
                        let ly = cY + labelDist * sin(rad)
                        
                        let textStr: String
                        let textColor: Color
                        switch angle {
                        case 0:
                            textStr = "N"
                            textColor = northColor
                        case 90:
                            textStr = "E"
                            textColor = cardinalColor
                        case 180:
                            textStr = "S"
                            textColor = cardinalColor
                        case 270:
                            textStr = "W"
                            textColor = cardinalColor
                        default:
                            textStr = "\(angle / 10)"
                            textColor = hudGreen.opacity(0.8)
                        }
                        
                        let fontSz = isCardinal ? (radius >= 60 ? fontSize.size(12) : fontSize.size(9)) : (radius >= 60 ? fontSize.size(9) : fontSize.size(7))
                        let text = Text(textStr)
                            .font(.system(size: fontSz, weight: .bold, design: .monospaced))
                            .foregroundColor(textColor)
                        
                        context.draw(text, at: CGPoint(x: lx, y: ly), anchor: .center)
                    }
                }
            }
            .frame(width: radius * 2, height: radius * 2)
            .rotationEffect(.degrees(-heading), anchor: .center)
            
            // 3. Center Digital Readout
            VStack(spacing: 1) {
                Text(String(format: "%03d°", deg))
                    .font(.system(size: radius >= 60 ? fontSize.size(14) : fontSize.size(11), weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(headingType.badge)
                    .font(.system(size: radius >= 60 ? fontSize.size(9) : fontSize.size(8), weight: .bold, design: .monospaced))
                    .foregroundColor(hudGreen)
            }
            
            // 4. Fixed Top Lubber Line Index Pointer (Points downward onto the top rim of the compass)
            Canvas { context, size in
                let cX = size.width / 2
                let tipY = (size.height / 2) - radius + 4
                let baseY = (size.height / 2) - radius - 7
                
                var arrow = Path()
                arrow.move(to: CGPoint(x: cX, y: tipY))
                arrow.addLine(to: CGPoint(x: cX - 6, y: baseY))
                arrow.addLine(to: CGPoint(x: cX + 6, y: baseY))
                arrow.closeSubpath()
                
                context.fill(arrow, with: .color(Color.yellow))
                context.stroke(arrow, with: .color(Color.black.opacity(0.8)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
            .frame(width: radius * 2, height: radius * 2)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}
