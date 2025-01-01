import SwiftUI

struct MeditationBellView: View {
    var body: some View {
        Text("Meditation Bell")
            .navigationTitle("Timer + Bell")
    }
}

#Preview {
    NavigationStack {
        MeditationBellView()
    }
} 