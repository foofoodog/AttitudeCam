import SwiftUI
import UIKit

struct CapturesGalleryView: View {
    @ObservedObject var captureStore: CaptureStore
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isDeleting = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if captureStore.captures.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 56))
                        .foregroundColor(.gray)
                    Text("No Captures Yet")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("Take photos using the shutter button on the camera.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Button("Back to Camera") {
                        dismiss()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                }
            } else {
                VStack(spacing: 0) {
                    // Top Navigation Bar
                    topNavBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(Color.black.opacity(0.75))
                    
                    // Main Paging Carousel
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(captureStore.captures.enumerated()), id: \.element.id) { index, item in
                            GalleryPhotoItemView(item: item, captureStore: captureStore)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    // Bottom Thumbnail Strip
                    bottomThumbnailStrip
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.75))
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
        .onChange(of: captureStore.captures.count) { newCount in
            if newCount == 0 {
                dismiss()
            } else if selectedIndex >= newCount {
                selectedIndex = max(0, newCount - 1)
            }
        }
    }
    
    // MARK: - Top Nav Bar
    private var topNavBar: some View {
        HStack {
            // Close Button
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Camera")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Index & Date Title
            if selectedIndex < captureStore.captures.count {
                let currentItem = captureStore.captures[selectedIndex]
                VStack(spacing: 2) {
                    Text("\(selectedIndex + 1) of \(captureStore.captures.count)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(currentItem.date, formatter: dateFormatter)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Actions: Share & Delete
            HStack(spacing: 12) {
                // Share Button (Shares image and companion JSON sidecar if available)
                Button(action: {
                    if selectedIndex < captureStore.captures.count {
                        let item = captureStore.captures[selectedIndex]
                        var items: [Any] = []
                        if let image = captureStore.loadImage(for: item) {
                            items.append(image)
                        } else {
                            items.append(item.fileURL)
                        }
                        let jsonURL = item.fileURL.deletingPathExtension().appendingPathExtension("json")
                        if FileManager.default.fileExists(atPath: jsonURL.path) {
                            items.append(jsonURL)
                        }
                        shareItems = items
                        showShareSheet = true
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                
                // Delete Button (triggers native iOS deletion confirmation directly)
                Button(action: { deleteCurrentCapture() }) {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                            .background(Color.red.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .disabled(isDeleting)
            }
        }
    }
    
    // MARK: - Bottom Thumbnail Strip
    private var bottomThumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(captureStore.captures.enumerated()), id: \.element.id) { index, item in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedIndex = index
                            }
                        }) {
                            ThumbnailCell(item: item, isSelected: selectedIndex == index, captureStore: captureStore)
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: selectedIndex) { newIndex in
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Deletion Logic
    private func deleteCurrentCapture() {
        guard !isDeleting, selectedIndex < captureStore.captures.count else { return }
        let item = captureStore.captures[selectedIndex]
        
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        isDeleting = true
        captureStore.deleteCapture(item) { @MainActor success in
            isDeleting = false
            if success {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if selectedIndex >= captureStore.captures.count {
                        selectedIndex = max(0, captureStore.captures.count - 1)
                    }
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy HH:mm:ss"
        return formatter
    }
}

// MARK: - Paging Photo Cell
private struct GalleryPhotoItemView: View {
    let item: CapturedItem
    let captureStore: CaptureStore
    
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
            Color.black
            
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .edgesIgnoringSafeArea(.all)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .onAppear {
                        image = captureStore.loadImage(for: item)
                    }
            }
        }
    }
}

// MARK: - Thumbnail Cell
private struct ThumbnailCell: View {
    let item: CapturedItem
    let isSelected: Bool
    let captureStore: CaptureStore
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack {
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 52, height: 52)
                    .onAppear {
                        thumbnail = captureStore.loadImage(for: item)
                    }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color(red: 0.2, green: 1.0, blue: 0.4) : Color.white.opacity(0.3), lineWidth: isSelected ? 2.5 : 1)
        )
        .scaleEffect(isSelected ? 1.08 : 1.0)
    }
}

// MARK: - Activity View Controller (Share Sheet)
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
