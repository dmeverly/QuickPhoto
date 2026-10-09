import SwiftUI
import PhotosUI

struct SketchSessionView: View {
    @State private var viewModel = SketchSessionViewModel()
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var areControlsVisible = true
    @State private var isCustomTimeSheetPresented = false

    var body: some View {
        ZStack {
            // Artful backdrop between sessions; plain black while drawing so nothing competes with the photo.
            if viewModel.isSessionActive {
                Color.black.ignoresSafeArea()
            } else {
                ArtisticBackdrop()
                    .transition(.opacity)
            }

            mainContent

            if viewModel.isSessionActive {
                sessionStatusOverlay
            }

            if areControlsVisible {
                VStack {
                    Spacer()
                    controlBar
                }
                .transition(.opacity)
            }
        }
        .onChange(of: selectedPickerItems) { _, newlySelectedItems in
            Task {
                await viewModel.importPhotos(from: newlySelectedItems)
                selectedPickerItems = []
            }
        }
        .onLongPressGesture {
            withAnimation { areControlsVisible.toggle() }
        }
        .statusBarHidden(!areControlsVisible)
        .sheet(isPresented: $isCustomTimeSheetPresented) {
            CustomTimePerPhotoSheet(initialSecondsPerPhoto: viewModel.secondsPerPhoto) { chosenSeconds in
                viewModel.selectSecondsPerPhoto(chosenSeconds)
            }
        }
    }

    // MARK: - Main content by session state

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.sessionState {
        case .idle:
            idleScreen
        case .running, .paused:
            referencePhoto
        }
    }

    @ViewBuilder
    private var referencePhoto: some View {
        if let currentPhoto = viewModel.currentPhoto {
            Image(uiImage: currentPhoto)
                .resizable()
                .scaledToFit()
                .grayscale(viewModel.isGrayscaleEnabled ? 1 : 0)
                .id(currentPhoto)                       // gives each photo its own crossfade
                .transition(.opacity)
                .ignoresSafeArea()
                .overlay {
                    if viewModel.sessionState == .paused {
                        pausedBanner
                    }
                }
                .onTapGesture { viewModel.swapCurrentPhoto() }
        }
    }

    private var pausedBanner: some View {
        Text("Paused")
            .font(.title2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.black.opacity(0.6), in: Capsule())
    }

    private var idleScreen: some View {
        VStack(spacing: 32) {
            IdleTitleView()

            if viewModel.isImporting {
                HStack(spacing: 10) {
                    ProgressView().tint(ArtPalette.paper)
                    Text("Importing photos…")
                }
                .font(.artSerif(.headline))
            } else if viewModel.savedPhotoCount == 0 {
                Text("Add reference photos to get started")
                    .font(.artSerif(.headline).italic())
            } else {
                sessionSummaryCard
                Text("Press play to begin")
                    .font(.artSerif(.footnote).italic())
                    .opacity(0.7)
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(ArtPalette.paper.opacity(0.9))
        .padding()
    }

    /// Time per photo and photo count, side by side on a frosted card.
    private var sessionSummaryCard: some View {
        HStack(spacing: 28) {
            summaryStat(
                value: DurationFormatting.shortDescription(of: viewModel.secondsPerPhoto),
                caption: "per photo"
            )

            Rectangle()
                .fill(ArtPalette.ochre.opacity(0.5))
                .frame(width: 1, height: 44)

            summaryStat(value: "\(viewModel.savedPhotoCount)", caption: "photos")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(ArtPalette.ochre.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func summaryStat(value: String, caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.artSerif(.title2, weight: .semibold))
            Text(caption)
                .font(.artSerif(.caption).italic())
                .tracking(1.5)
                .foregroundStyle(ArtPalette.ochre)
        }
    }

    // MARK: - Countdown and pose counter

    private var sessionStatusOverlay: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    CountdownRingView(
                        timeRemainingFraction: viewModel.poseTimeRemainingFraction,
                        remainingSeconds: viewModel.remainingSecondsInPose,
                        isEndingSoon: viewModel.isPoseEndingSoon
                    )
                    Text(viewModel.poseProgressDescription)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.45), in: Capsule())
                }
            }
            Spacer()
        }
        .padding()
        .allowsHitTesting(false)   // taps pass through to the photo
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 24) {
            PhotosPicker(selection: $selectedPickerItems, matching: .images, photoLibrary: .shared()) {
                Label("Add Photos", systemImage: "plus")
            }

            Button {
                viewModel.togglePlayPause()
            } label: {
                Label(
                    viewModel.sessionState == .running ? "Pause" : "Play",
                    systemImage: viewModel.sessionState == .running ? "pause.fill" : "play.fill"
                )
            }
            .disabled(viewModel.savedPhotoCount == 0)

            timePerPhotoMenu

            Button {
                viewModel.isGrayscaleEnabled.toggle()
            } label: {
                Label("Grayscale", systemImage: "circle.lefthalf.filled")
            }
            .tint(viewModel.isGrayscaleEnabled ? ArtPalette.ochre : ArtPalette.paper)

            moreOptionsMenu
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .tint(ArtPalette.paper)
        .padding()
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 24)
    }

    private var timePerPhotoMenu: some View {
        Menu {
            Picker("Time per Photo", selection: secondsPerPhotoSelection) {
                ForEach(viewModel.standardSecondsPerPhotoOptions, id: \.self) { secondsOption in
                    Text(DurationFormatting.shortDescription(of: secondsOption)).tag(secondsOption)
                }
                // Shows the saved custom time as a checked option alongside the standard ones.
                if viewModel.isUsingCustomSecondsPerPhoto {
                    Text(DurationFormatting.shortDescription(of: viewModel.secondsPerPhoto))
                        .tag(viewModel.secondsPerPhoto)
                }
            }

            Button("Custom…", systemImage: "slider.horizontal.3") {
                isCustomTimeSheetPresented = true
            }
        } label: {
            Label("Time per Photo", systemImage: "timer")
        }
        .disabled(viewModel.isSessionActive)   // change the time between sessions, not mid-session
    }

    private var moreOptionsMenu: some View {
        Menu {
            Text("\(viewModel.savedPhotoCount) photos")

            Toggle("Sounds", isOn: $viewModel.isSoundEnabled)

            if viewModel.isSessionActive {
                Button("End Session", role: .destructive) { viewModel.endSession() }
            }

            Button("Remove All Photos", role: .destructive) { viewModel.removeAllPhotos() }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    private var secondsPerPhotoSelection: Binding<Double> {
        Binding(
            get: { viewModel.secondsPerPhoto },
            set: { newSecondsPerPhoto in viewModel.selectSecondsPerPhoto(newSecondsPerPhoto) }
        )
    }
}

// MARK: - Idle title

/// App title with a brush swash that paints itself in each time the screen appears.
private struct IdleTitleView: View {
    @Environment(\.accessibilityReduceMotion) private var isReduceMotionEnabled
    @State private var swashFraction: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            Text("QuickPhoto")
                .font(.artSerif(.largeTitle, weight: .medium))
                .tracking(1)
                .foregroundStyle(ArtPalette.paper)

            BrushSwashShape()
                .trim(from: 0, to: swashFraction)
                .stroke(ArtPalette.brushGradient, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 170, height: 16)
                .accessibilityHidden(true)

            Text("gesture drawing studio")
                .font(.artSerif(.subheadline).italic())
                .tracking(3)
                .foregroundStyle(ArtPalette.ochre)
                .padding(.top, 4)
        }
        .onAppear {
            guard !isReduceMotionEnabled else {
                swashFraction = 1
                return
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) { swashFraction = 1 }
        }
        .onDisappear { swashFraction = 0 }
    }
}

// MARK: - Custom time entry

/// Lets her dial in any time per photo using minute and second wheels.
private struct CustomTimePerPhotoSheet: View {
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int
    @State private var seconds: Int

    init(initialSecondsPerPhoto: Double, onSave: @escaping (Double) -> Void) {
        let wholeSeconds = Int(initialSecondsPerPhoto)
        _minutes = State(initialValue: min(wholeSeconds / 60, 60))
        _seconds = State(initialValue: wholeSeconds % 60)
        self.onSave = onSave
    }

    private var totalSeconds: Int { minutes * 60 + seconds }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Minutes", selection: $minutes) {
                    ForEach(0...60, id: \.self) { minuteValue in
                        Text("\(minuteValue) min").tag(minuteValue)
                    }
                }
                Picker("Seconds", selection: $seconds) {
                    ForEach(0..<60, id: \.self) { secondValue in
                        Text("\(secondValue) sec").tag(secondValue)
                    }
                }
            }
            .pickerStyle(.wheel)
            .padding()
            .navigationTitle("Time per Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(Double(totalSeconds))
                        dismiss()
                    }
                    .disabled(totalSeconds == 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SketchSessionView()
}
