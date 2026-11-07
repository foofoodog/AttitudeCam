import Foundation
import AVFoundation
import UIKit

@MainActor
final class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isSessionRunning = false
    @Published var isFlashOn = false
    @Published var isAuthorized = false
    
    let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // Thread-safe photo capture coordinator
    private let captureDelegate = PhotoCaptureDelegate()
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        default:
            self.isAuthorized = false
        }
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                
                guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    print("Unable to find back camera.")
                    self.session.commitConfiguration()
                    return
                }
                
                do {
                    let input = try AVCaptureDeviceInput(device: backCamera)
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                        self.videoDeviceInput = input
                    }
                    
                    if self.session.canAddOutput(self.photoOutput) {
                        self.session.addOutput(self.photoOutput)
                        self.photoOutput.maxPhotoQualityPrioritization = .balanced
                    }
                    
                    self.session.commitConfiguration()
                    self.startSession()
                } catch {
                    print("Error setting up camera input: \(error.localizedDescription)")
                    self.session.commitConfiguration()
                }
            }
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                guard !self.session.isRunning else { return }
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                guard self.session.isRunning else { return }
                self.session.stopRunning()
                self.isSessionRunning = false
            }
        }
    }
    
    func toggleTorch() {
        guard let device = videoDeviceInput?.device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
                isFlashOn = false
            } else {
                try device.setTorchModeOn(level: 1.0)
                isFlashOn = true
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }
    
    func capturePhoto(orientation: DeviceScreenOrientation = .portrait) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            if self.videoDeviceInput?.device.hasFlash == true && self.isFlashOn {
                settings.flashMode = .on
            } else {
                settings.flashMode = .off
            }
            
            if let connection = self.photoOutput.connection(with: .video), connection.isVideoOrientationSupported {
                let videoOrientation: AVCaptureVideoOrientation
                switch orientation {
                case .portrait:
                    videoOrientation = .portrait
                case .landscapeLeft:
                    videoOrientation = .landscapeRight
                case .landscapeRight:
                    videoOrientation = .landscapeLeft
                case .portraitUpsideDown:
                    videoOrientation = .portraitUpsideDown
                }
                connection.videoOrientation = videoOrientation
            }
            
            self.captureDelegate.completionHandler = { result in
                continuation.resume(with: result)
            }
            
            self.photoOutput.capturePhoto(with: settings, delegate: self.captureDelegate)
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    var completionHandler: (@Sendable (Result<UIImage, Error>) -> Void)?
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completionHandler?(.failure(error))
            completionHandler = nil
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            let err = NSError(domain: "CameraManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode photo data."])
            completionHandler?(.failure(err))
            completionHandler = nil
            return
        }
        
        completionHandler?(.success(image))
        completionHandler = nil
    }
}
