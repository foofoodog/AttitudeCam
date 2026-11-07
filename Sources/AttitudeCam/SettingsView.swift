import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Display Text Size
                Section {
                    HStack(spacing: 8) {
                        ForEach(DisplayFontSize.allCases, id: \.self) { size in
                            Button(action: {
                                settings.fontSize = size
                            }) {
                                Text(size.rawValue)
                                    .font(.system(size: 15, weight: settings.fontSize == size ? .bold : .medium))
                                    .foregroundColor(settings.fontSize == size ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(settings.fontSize == size ? Color.accentColor : Color(UIColor.tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Display Text Size")
                } footer: {
                    Text("Adjusts the font size of telemetry readouts, coordinates, and HUD gauges.")
                }
                
                // MARK: - Unit Presets & Measurement Units
                Section {
                    Picker("Speed Unit", selection: $settings.speedUnit) {
                        ForEach(SpeedUnit.allCases) { unit in
                            Text(unit.rawValue.capitalized).tag(unit)
                        }
                    }
                    
                    Picker("Altitude Unit", selection: $settings.altitudeUnit) {
                        ForEach(AltitudeUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    
                    Picker("Compass Reference", selection: $settings.headingType) {
                        ForEach(HeadingType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                } header: {
                    Text("Units & Navigation")
                } footer: {
                    HStack {
                        Text("Presets:")
                        Spacer()
                        Button("Aviation") { settings.applyPreset(.aviation) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                        Button("Imperial") { settings.applyPreset(.imperial) }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        Button("Metric") { settings.applyPreset(.metric) }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                    }
                    .padding(.top, 4)
                }
                
                // MARK: - Site / Vehicle Identification Note
                Section {
                    TextField("e.g. Tail # N12345 or Site A", text: $settings.customNote)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    
                    Toggle("Burn Note onto Captured Photos", isOn: $settings.burnCustomNote)
                } header: {
                    Text("Site / Vehicle Note (Tail Number)")
                } footer: {
                    Text("When set, this tag appears on the telemetry overlay and is embedded in the photo's EXIF / TIFF metadata.")
                }
                
                // MARK: - Display Instruments
                Section {
                    Toggle("Artificial Horizon (HUD)", isOn: $settings.showHorizonHUD)
                    Toggle("GPS Coordinates (DMS & Dec)", isOn: $settings.showCoordinates)
                    Toggle("GPS Ground Speed", isOn: $settings.showSpeed)
                    Toggle("Altitude", isOn: $settings.showAltitude)
                    Toggle("Compass Heading", isOn: $settings.showHeading)
                    Toggle("Vertical Speed (Climb / VSI)", isOn: $settings.showVSI)
                    Toggle("G-Force Load Meter", isOn: $settings.showGMeter)
                    Toggle("Level Snap Indicator (±0.5°)", isOn: $settings.enableLevelSnap)
                    if settings.enableLevelSnap {
                        Toggle("Haptic Pulse on Level", isOn: $settings.hapticOnLevelSnap)
                    }
                } header: {
                    Text("Live Display Instruments")
                } footer: {
                    Text("Select which telemetry readouts appear on your live viewfinder HUD.")
                }
                
                // MARK: - Photo Capture Composition
                Section {
                    Toggle("Burn Telemetry Header onto Photos", isOn: $settings.burnOverlayOnPhoto)
                    Toggle("Burn Center Horizon Lines onto Photos", isOn: $settings.burnHorizonOnPhoto)
                } header: {
                    Text("Photo Overlay")
                } footer: {
                    Text("Regardless of visual burning, full pitch, roll, heading, altitude, speed, G-force, and GPS data are always embedded into the photo's permanent EXIF metadata.")
                }
                
                // MARK: - App Info
                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Attitude Reference")
                        Spacer()
                        Text("CoreMotion Gravity (Screen-projected)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About AttitudeCam")
                }
            }
            .navigationTitle("AttitudeCam Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .bold))
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
