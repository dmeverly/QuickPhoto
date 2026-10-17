import SwiftUI

@main
struct QuickPhoto_MasterControl: App {
    @State private var isIntroShowing = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                SketchSessionView()

                if isIntroShowing {
                    IntroView {
                        withAnimation(.easeInOut(duration: 0.8)) { isIntroShowing = false }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 1.08)))
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)   
        }
    }
}
