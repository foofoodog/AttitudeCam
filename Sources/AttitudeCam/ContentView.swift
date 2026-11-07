import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var motionManager = MotionManager()
    @StateObject private var captureStore = CaptureStore()
    @StateObject private var settings = AppSettings.shared
    
    @State private var currentOrientation: DeviceScreenOrientation = .portrait
    @State private var showHUD = true
    @State private var isCapturing = false
    @State private var showFlash = false
    @State private var showSavedToast = false
    @State private var showGallery = false
    @State private var showSettings = false
    @State private var galleryIndex = 0
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // 1. Live Camera Preview
                if cameraManager.isAuthorized {
                    CameraPreviewView(session: cameraManager.session, orientation: currentOrientation)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    cameraAccessRequiredView
                }
                
                // 2. Artificial Horizon Overlay
                if showHUD && settings.showHorizonHUD {
                    let currentHeading = settings.headingType == .trueNorth ? (locationManager.trueHeading > 0 ? locationManager.trueHeading : locationManager.heading) : (locationManager.magneticHeading > 0 ? locationManager.magneticHeading : locationManager.heading)
                    ArtificialHorizonView(
                        pitch: motionManager.pitch,
                        roll: motionManager.roll,
                        heading: currentHeading,
                        headingType: settings.headingType,
                        showHeading: settings.showHeading,
                        gForce: motionManager.gForce,
                        isLevel: motionManager.isLevel,
                        showGMeter: settings.showGMeter,
                        enableLevelSnap: settings.enableLevelSnap,
                        fontSize: settings.fontSize
                    )
                    .edgesIgnoringSafeArea(.all)
                }
                
                // 3. Screen Flash Feedback on Photo Snap
                if showFlash {
                    Color.white
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                }
                
                // 4. Dynamic Adaptive Controls
                if isLandscape {
                    landscapeLayout
                } else {
                    portraitLayout
                }
                
                // 5. Toast Notification (Saved to Photos)
                if showSavedToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.2, green: 1.0, blue: 0.4))
                            Text("Photo Saved to Captures & Photos")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.8), lineWidth: 1.5))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, isLandscape ? 12 : 96)
                    }
                    .edgesIgnoringSafeArea(.bottom)
                }
            }
            .onAppear {
                motionManager.hapticFeedbackEnabled = settings.hapticOnLevelSnap
                syncOrientation(geometry: geometry)
            }
            .onChange(of: geometry.size) { _ in
                syncOrientation(geometry: geometry)
            }
            .onChange(of: settings.hapticOnLevelSnap) { newValue in
                motionManager.hapticFeedbackEnabled = newValue
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                handleDeviceOrientationChange()
            }
        }
        .fullScreenCover(isPresented: $showGallery) {
            CapturesGalleryView(captureStore: captureStore, selectedIndex: $galleryIndex)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Photo Capture Error"),
                  message: Text(errorMessage ?? "An error occurred."),
                  dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Portrait UI Layout
    private var portraitLayout: some View {
        VStack {
            // Top Bar: HUD Toggle, Flash Toggle, Settings Gear, GPS Overlay Card
            VStack(spacing: 12) {
                HStack {
                    // HUD Visibility Toggle
                    Button(action: { withAnimation { showHUD.toggle() } }) {
                        HStack(spacing: 6) {
                            Image(systemName: (showHUD && settings.showHorizonHUD) ? "eye.fill" : "eye.slash.fill")
                            Text((showHUD && settings.showHorizonHUD) ? "HUD ON" : "HUD OFF")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor((showHUD && settings.showHorizonHUD) ? Color(red: 0.2, green: 1.0, blue: 0.4) : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        // Torch / Flash Toggle
                        Button(action: { cameraManager.toggleTorch() }) {
                            Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(cameraManager.isFlashOn ? .yellow : .white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        // Settings Gear Button
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // GPS Overlay Card
                GPSOverlayView(locationManager: locationManager, settings: settings, isLandscape: false)
                    .padding(.horizontal, 16)
            }
            
            Spacer()
            
            // Bottom Shutter Controls Bar
            HStack(alignment: .center) {
                // Left: Gallery Thumbnail
                if let firstItem = captureStore.captures.first {
                    Button(action: {
                        galleryIndex = 0
                        showGallery = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            ThumbnailPreview(item: firstItem, captureStore: captureStore)
                            
                            if captureStore.captures.count > 1 {
                                Text("\(captureStore.captures.count)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 0.2, green: 1.0, blue: 0.4))
                                    .clipShape(Capsule())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .frame(width: 60)
                } else {
                    Spacer().frame(width: 60)
                }
                
                Spacer()
                
                // Center: Shutter Button
                shutterButton
                
                Spacer()
                
                // Right: Spacer to balance thumbnail width and keep shutter centered
                Spacer().frame(width: 60)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.bottom)
            )
        }
    }
    
    // MARK: - Landscape UI Layout
    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            // Main View Area (Top bar + Viewfinder)
            VStack {
                // Top Bar: HUD/Torch/Settings Buttons + Compact GPS Bar
                HStack(spacing: 8) {
                    Button(action: { withAnimation { showHUD.toggle() } }) {
                        Image(systemName: (showHUD && settings.showHorizonHUD) ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor((showHUD && settings.showHorizonHUD) ? Color(red: 0.2, green: 1.0, blue: 0.4) : .white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { cameraManager.toggleTorch() }) {
                        Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(cameraManager.isFlashOn ? .yellow : .white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }
                    
                    GPSOverlayView(locationManager: locationManager, settings: settings, isLandscape: true)
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.top, 6)
                
                Spacer()
            }
            
            // Trailing Controls Column (Camera shutter on right side for thumb)
            VStack(spacing: 18) {
                Spacer()
                
                // Center Shutter Button
                shutterButton
                
                // Gallery Thumbnail below Shutter
                if let firstItem = captureStore.captures.first {
                    Button(action: {
                        galleryIndex = 0
                        showGallery = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            ThumbnailPreview(item: firstItem, captureStore: captureStore)
                            
                            if captureStore.captures.count > 1 {
                                Text("\(captureStore.captures.count)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color(red: 0.2, green: 1.0, blue: 0.4))
                                    .clipShape(Capsule())
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .frame(width: 50, height: 50)
                } else {
                    Color.clear.frame(width: 50, height: 50)
                }
                
                Spacer()
            }
            .frame(width: 90)
            .background(Color.black.opacity(0.35))
        }
    }
    
    // MARK: - Reusable Shutter Button
    private var shutterButton: some View {
        Button(action: { takePhoto() }) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                
                if isCapturing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.3)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 58, height: 58)
                }
            }
        }
        .disabled(isCapturing)
    }
    
    private var cameraAccessRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("Camera Access Required")
                .font(.headline)
                .foregroundColor(.white)
            Text("Please grant camera permission in iOS Settings to use the live viewfinder.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    // MARK: - Orientation Sync
    private func syncOrientation(geometry: GeometryProxy) {
        if geometry.size.width > geometry.size.height {
            let orientation = UIDevice.current.orientation
            if orientation == .landscapeRight {
                setOrientation(.landscapeRight)
            } else {
                setOrientation(.landscapeLeft)
            }
        } else {
            setOrientation(.portrait)
        }
    }
    
    private func handleDeviceOrientationChange() {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait:
            setOrientation(.portrait)
        case .landscapeLeft:
            setOrientation(.landscapeLeft)
        case .landscapeRight:
            setOrientation(.landscapeRight)
        case .portraitUpsideDown:
            setOrientation(.portraitUpsideDown)
        default:
            break
        }
    }
    
    private func setOrientation(_ orientation: DeviceScreenOrientation) {
        guard currentOrientation != orientation else { return }
        currentOrientation = orientation
        motionManager.updateOrientation(orientation)
    }
    
    // MARK: - Take Photo
    private func takePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let capturedOrientation = currentOrientation
        let declination: Double
        if locationManager.trueHeading > 0 && locationManager.magneticHeading > 0 {
            declination = locationManager.trueHeading - locationManager.magneticHeading
        } else {
            declination = 0.0
        }
        
        let snapshot = TelemetrySnapshot(
            coordinate: locationManager.coordinate,
            altitude: locationManager.altitude,
            heading: locationManager.heading,
            trueHeading: locationManager.trueHeading,
            magneticHeading: locationManager.magneticHeading,
            speed: locationManager.speed,
            verticalSpeed: locationManager.verticalSpeed,
            gForce: motionManager.gForce,
            horizontalAccuracy: locationManager.horizontalAccuracy,
            pitch: motionManager.pitch,
            roll: motionManager.roll,
            barometricPressure: motionManager.barometricPressure,
            ambientTemperature: 20.0,
            declination: declination,
            includeHUD: showHUD && settings.showHorizonHUD,
            burnOverlay: settings.burnOverlayOnPhoto,
            burnHorizon: settings.burnHorizonOnPhoto,
            customNote: settings.burnCustomNote ? settings.customNote : "",
            speedUnit: settings.speedUnit,
            altitudeUnit: settings.altitudeUnit,
            headingType: settings.headingType,
            enableLevelSnap: settings.enableLevelSnap,
            fontSize: settings.fontSize,
            timestamp: Date()
        )
        
        Task {
            do {
                let rawImage = try await cameraManager.capturePhoto(orientation: capturedOrientation)
                
                // Flash animation
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.12)) {
                        showFlash = true
                    }
                }
                try? await Task.sleep(nanoseconds: 120_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.20)) {
                        showFlash = false
                    }
                    // Release the shutter button immediately so the user can snap again!
                    self.isCapturing = false
                }
                
                // Process, encode, and save in background asynchronously
                Task.detached(priority: .userInitiated) {
                    do {
                        let (_, jpegData, assetId, jsonPayload) = try await PhotoComposer.shared.composeAndSavePhoto(image: rawImage, telemetry: snapshot)
                        
                        await MainActor.run {
                            _ = try? self.captureStore.saveCapture(jpegData: jpegData, assetLocalIdentifier: assetId, jsonPayload: jsonPayload)
                            withAnimation {
                                self.showSavedToast = true
                            }
                        }
                        
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        await MainActor.run {
                            withAnimation {
                                self.showSavedToast = false
                            }
                        }
                    } catch {
                        print("Background photo save error: \(error.localizedDescription)")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isCapturing = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}

// MARK: - Thumbnail Preview
struct ThumbnailPreview: View {
    let item: CapturedItem
    @ObservedObject var captureStore: CaptureStore
    
    var body: some View {
        Group {
            if let image = captureStore.loadImage(for: item) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white, lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.8))
                    )
            }
        }
    }
}
