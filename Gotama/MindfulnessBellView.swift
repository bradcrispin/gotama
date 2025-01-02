import SwiftUI

/// A view that provides mindfulness bell functionality
struct MindfulnessBellView: View {
    var body: some View {
        Text("Mindfulness Bell View")
            .navigationTitle("Mindfulness Bell")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MindfulnessBellView()
    }
} 