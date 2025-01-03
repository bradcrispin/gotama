import SwiftUI
import SwiftData
import UserNotifications

/// A view that provides mindfulness bell scheduling functionality
struct MindfulnessBellView: View {
    // MARK: - Environment & State
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [Settings]
    @StateObject private var bellPlayer = BellPlayer()
    
    // Bell schedule state
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var intervalHours: Double
    @State private var isScheduled: Bool
    @State private var bellScale: CGFloat = 1.0
    @State private var validationMessage: String?
    @State private var showValidationMessage = false
    @State private var showNotificationAlert = false
    @State private var notificationAlertType: NotificationAlertType = .needsPermission
    @State private var currentInstructionIndex: Int = 0  // Track which instruction we're on
    
    // MARK: - Types
    
    enum NotificationAlertType {
        case needsPermission
        case denied
        
        var title: String {
            switch self {
            case .needsPermission:
                return "Allow Notifications"
            case .denied:
                return "Notifications Disabled"
            }
        }
        
        var message: String {
            switch self {
            case .needsPermission:
                return "To schedule mindfulness bells, please allow notifications."
            case .denied:
                return "Please enable notifications in Settings to use mindfulness bells."
            }
        }
        
        var primaryButton: String {
            switch self {
            case .needsPermission:
                return "Allow"
            case .denied:
                return "Open Settings"
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Set default values
        let defaultStart = Calendar.current.date(from: DateComponents(hour: 9)) ?? Date()
        let defaultEnd = Calendar.current.date(from: DateComponents(hour: 17)) ?? Date()
        
        // Initialize with defaults - actual values will be loaded in .task
        _startTime = State(initialValue: defaultStart)
        _endTime = State(initialValue: defaultEnd)
        _intervalHours = State(initialValue: 0)
        _isScheduled = State(initialValue: false)
        
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    // MARK: - Computed Properties
    
    /// Get the current settings object or create if needed
    private var currentSettings: Settings? {
        if let existing = settings.first {
            return existing
        }
        
        do {
            return try Settings.getOrCreate(modelContext: modelContext)
        } catch {
            print("❌ Error creating settings: \(error)")
            return nil
        }
    }
    
    /// Calculate the times when the bell will ring
    private var bellTimes: [Date] {
        guard intervalHours > 0 else { return [] }
        guard isValidSchedule else { return [] }
        
        let calendar = Calendar.current
        var times: [Date] = []
        var currentTime = startTime
        
        while currentTime <= endTime {
            times.append(currentTime)
            guard let nextTime = calendar.date(byAdding: .hour, value: Int(intervalHours), to: currentTime) else { break }
            currentTime = nextTime
        }
        
        return times
    }
    
    /// Check if the schedule is valid
    private var isValidSchedule: Bool {
        // End time must be after start time
        guard endTime > startTime else { return false }
        
        // If interval is set, it must be less than the time period
        if intervalHours > 0 {
            let hours = Calendar.current.dateComponents([.hour], from: startTime, to: endTime).hour ?? 0
            if Double(hours) < intervalHours {
                return false
            }
        }
        
        return true
    }
    
    /// Get validation message if schedule is invalid
    private var scheduleValidationMessage: String? {
        if endTime <= startTime {
            return "End time must be after start time"
        }
        
        if intervalHours > 0 {
            let hours = Calendar.current.dateComponents([.hour], from: startTime, to: endTime).hour ?? 0
            if Double(hours) < intervalHours {
                return "Interval must be shorter than the time period"
            }
        }
        
        return nil
    }
    
    /// Check if schedule can be activated or is already active
    private var canSchedule: Bool {
        isScheduled || (isValidSchedule && intervalHours > 0 && !bellTimes.isEmpty)
    }
    
    /// Check if current settings are valid for scheduling
    private var hasValidSettings: Bool {
        isValidSchedule && intervalHours > 0 && !bellTimes.isEmpty
    }
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Interactive bell icon
                Button {
                    bellPlayer.playBell()
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    bellIcon
                        .frame(height: 120)
                        .padding(.top, 20)
                }
                
                // Main settings
                VStack(spacing: 24) {
                    // Start Time
                    timeSetting(
                        title: "Begin",
                        icon: "sunrise.fill",
                        selection: $startTime
                    )
                    
                    // End Time
                    timeSetting(
                        title: "End",
                        icon: "sunset",
                        selection: $endTime
                    )
                    
                    // Interval
                    intervalSetting
                    
                    // Schedule toggle
                    if hasValidSettings || isScheduled {
                        Divider()
                        scheduleToggle
                    }
                    
                    // Validation message
                    if let message = scheduleValidationMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }
                    
                    // Bell times summary
                    if !bellTimes.isEmpty {
                        Divider()
                        bellTimesSummary
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal)
                .animation(.easeInOut(duration: 0.2), value: scheduleValidationMessage)
                
                Spacer()
            }
        }
            .navigationTitle("Mindfulness Bell")
            .navigationBarTitleDisplayMode(.inline)
        .onChange(of: startTime) { validateAndUpdate() }
        .onChange(of: endTime) { validateAndUpdate() }
        .onChange(of: intervalHours) { validateAndUpdate() }
        .task {
            loadSavedSettings()
        }
        .alert(notificationAlertType.title, isPresented: $showNotificationAlert) {
            Button(notificationAlertType.primaryButton) {
                switch notificationAlertType {
                case .needsPermission:
                    requestNotificationPermission()
                case .denied:
                    openSettings()
                }
            }
            Button("Cancel") {
                // If they cancel, turn off the schedule
                isScheduled = false
                saveSettings()
            }
        } message: {
            Text(notificationAlertType.message)
        }
    }
    
    // MARK: - Views
    
    /// Animated bell icon
    private var bellIcon: some View {
        Image(systemName: bellPlayer.volumeState == .muted ? "bell.slash" : (isScheduled ? "bell.badge" : "bell"))
            .font(.system(size: 48))
            .foregroundStyle(isScheduled ? Color.accent : .secondary)
            .symbolEffect(.bounce, options: .repeat(2), value: bellPlayer.volumeState)
            .frame(width: 60, height: 60, alignment: .center)
            .scaleEffect(bellScale)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: bellScale)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isScheduled)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: bellPlayer.volumeState)
            .contentTransition(.symbolEffect(.replace))
            .onChange(of: bellPlayer.volumeState) { oldState, newState in
                if oldState != newState {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        bellScale = 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            bellScale = 1.0
                        }
                    }
                }
            }
    }
    
    /// Time setting row with icon and picker
    private func timeSetting(title: String, icon: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            DatePicker(
                title,
                selection: selection,
                displayedComponents: [.hourAndMinute]
            )
            .labelsHidden()
        }
    }
    
    /// Interval setting with stepper
    private var intervalSetting: some View {
        HStack(spacing: 16) {
            Label("Interval", systemImage: "clock.arrow.2.circlepath")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Show "Off" or the hour value
            Text(intervalHours == 0 ? "Off" : "\(Int(intervalHours))h")
                .foregroundStyle(.secondary)
            
            Stepper("", value: $intervalHours, in: 0...12, step: 1)
                .labelsHidden()
        }
    }
    
    /// Summary of when bells will ring
    private var bellTimesSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Schedule", systemImage: "calendar.badge.clock")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Debug button
                // debugButton
                
                Text("\(bellTimes.count) bell\(bellTimes.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            
            // Times grid
            let columns = [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
            
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(bellTimes, id: \.timeIntervalSince1970) { time in
                    Text(formatTime(time))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accent.opacity(0.1))
                        )
                }
            }
            
            // Summary text
            if bellTimes.count > 0 {
                Text("Every \(Int(intervalHours)) hour\(intervalHours == 1 ? "" : "s") from \(formatTime(startTime)) to \(formatTime(endTime))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    /// Schedule toggle
    private var scheduleToggle: some View {
        Toggle(isOn: Binding(
            get: { isScheduled },
            set: { newValue in
                if newValue {
                    // Check notification permission when enabling
                    Task {
                        let status = await checkNotificationStatus()
                        await MainActor.run {
                            switch status {
                            case .notDetermined:
                                showNotificationAlert = true
                                notificationAlertType = .needsPermission
                            case .denied:
                                showNotificationAlert = true
                                notificationAlertType = .denied
                            case .authorized, .provisional, .ephemeral:
                                withAnimation(.spring(response: 0.3)) {
                                    isScheduled = true
                                }
                                saveSettings()
                                scheduleNotifications()
                            @unknown default:
                                break
                            }
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        isScheduled = false
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    saveSettings()
                    // Remove all pending notifications
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                }
            }
        )) {
            Label("Schedule Active", systemImage: "clock.badge.checkmark")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Debug button for testing notifications
    private var debugButton: some View {
        Button {
            scheduleDebugNotification()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Label("Test", systemImage: "clock.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Format a date to show only the time
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    /// Load saved settings from SwiftData
    private func loadSavedSettings() {
        guard let settings = currentSettings else { return }
        
        if let savedStart = settings.mindfulnessBellStartTime {
            startTime = savedStart
        }
        if let savedEnd = settings.mindfulnessBellEndTime {
            endTime = savedEnd
        }
        intervalHours = settings.mindfulnessBellIntervalHours
        isScheduled = settings.mindfulnessBellIsScheduled
        
        // If scheduled, verify notifications exist
        if isScheduled {
            Task {
                let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
                if pending.isEmpty {
                    print("⚠️ Schedule was on but no notifications found, rescheduling...")
                    scheduleNotifications()
                } else {
                    print("✅ Found \(pending.count) scheduled notifications")
                }
            }
        }
    }
    
    /// Save current settings to SwiftData
    private func saveSettings() {
        guard let settings = currentSettings else { return }
        
        settings.mindfulnessBellStartTime = startTime
        settings.mindfulnessBellEndTime = endTime
        settings.mindfulnessBellIntervalHours = intervalHours
        settings.mindfulnessBellIsScheduled = isScheduled
        
        do {
            try modelContext.save()
            print("✅ Saved mindfulness bell settings")
            print("Is scheduled: \(isScheduled)")
        } catch {
            print("❌ Error saving settings: \(error)")
        }
    }
    
    /// Validate settings and update UI state
    private func validateAndUpdate() {
        // Only cancel schedule if settings actually changed and we're currently scheduled
        if isScheduled {
            let hours = Calendar.current.dateComponents([.hour], from: startTime, to: endTime).hour ?? 0
            let settingsChanged = Double(hours) < intervalHours || endTime <= startTime
            
            if settingsChanged {
                withAnimation {
                    isScheduled = false
                }
                // Remove notifications since settings are invalid
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            }
        }
        
        // Validate interval against time period
        if intervalHours > 0 {
            let hours = Calendar.current.dateComponents([.hour], from: startTime, to: endTime).hour ?? 0
            if Double(hours) < intervalHours {
                // Automatically adjust interval to maximum possible
                withAnimation {
                    intervalHours = max(1, Double(hours))
                }
            }
        }
        
        // Save settings after validation
        saveSettings()
    }
    
    // MARK: - Notification Methods
    
    /// Check notification permission status
    private func checkNotificationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
    
    /// Request notification permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    // Permission granted, enable schedule and schedule notifications
                    withAnimation(.spring(response: 0.3)) {
                        isScheduled = true
                    }
                    saveSettings()
                    scheduleNotifications()
                    
                    // Verify schedule was set
                    Task {
                        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
                        if pending.isEmpty {
                            print("⚠️ No notifications were scheduled")
                            isScheduled = false
                        } else {
                            print("✅ Verified \(pending.count) notifications are scheduled")
                            isScheduled = true
                        }
                        saveSettings()
                    }
                } else {
                    // Permission denied, show settings alert
                    notificationAlertType = .denied
                    showNotificationAlert = true
                    isScheduled = false
                    saveSettings()
                }
            }
            
            if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }
    
    /// Get the custom notification sound
    private func getNotificationSound() -> UNNotificationSound {
        // Debug bundle contents
        print("📦 Bundle resource paths:")
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                for item in contents {
                    print("  - \(item)")
                }
            } catch {
                print("❌ Error listing bundle contents: \(error)")
            }
        }
        
        // Try to find our custom sound
        if let soundURL = Bundle.main.url(forResource: "bell-meditation-75335", withExtension: "mp3") {
            print("✅ Found sound file at: \(soundURL)")
            return UNNotificationSound(named: UNNotificationSoundName(soundURL.lastPathComponent))
        } else {
            print("⚠️ Could not find bell sound file, using default")
            return .default
        }
    }
    
    /// Schedule all notifications for bell times
    private func scheduleNotifications() {
        // Remove any existing notifications first
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard isScheduled else { return }
        
        // Reset instruction index when starting fresh schedule
        currentInstructionIndex = 0
        
        // Schedule each bell time
        for time in bellTimes {
            // Create notification content with sequential instruction
            let content = UNMutableNotificationContent()
            content.title = "Gotama struck the bell"
            content.body = MindfulnessInstructions.getInstruction(forIndex: currentInstructionIndex)
            content.sound = getNotificationSound()
            
            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            let request = UNNotificationRequest(
                identifier: "mindfulnessBell-\(time.timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error scheduling notification: \(error)")
                }
            }
            
            // Increment instruction index for next notification
            currentInstructionIndex += 1
        }
        
        print("✅ Scheduled \(bellTimes.count) notifications with sequential instructions")
    }
    
    /// Schedule a debug notification for testing
    private func scheduleDebugNotification() {
        // First check and print current notification settings
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            print("📱 Current notification settings:")
            print("  Authorization status: \(settings.authorizationStatus.rawValue)")
            print("  Alert setting: \(settings.alertSetting.rawValue)")
            print("  Sound setting: \(settings.soundSetting.rawValue)")
            
            // List any pending notifications
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            print("📋 Pending notifications: \(pending.count)")
            for request in pending {
                print("  - \(request.identifier)")
                if let content = request.content.mutableCopy() as? UNMutableNotificationContent {
                    print("    Message: \(content.body)")
                }
            }
        }
        
        // Use the same content as production notifications but with random instruction
        let content = UNMutableNotificationContent()
        content.title = "Mindfulness Bell"
        content.body = MindfulnessInstructions.getRandomInstruction()
        content.sound = getNotificationSound()
        
        // Schedule for 10 seconds from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        print("🔔 Scheduling debug notification for 10 seconds from now at \(Date().addingTimeInterval(10))")
        
        let request = UNNotificationRequest(
            identifier: "debugBell-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling debug notification: \(error)")
            } else {
                print("✅ Successfully scheduled debug notification")
            }
        }
    }
    
    /// Open app settings
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        print("📬 Will present notification: \(notification.request.identifier)")
        return [.banner, .sound]
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        print("👆 Did receive notification response: \(response.notification.request.identifier)")
    }
}

// MARK: - Previews
#Preview {
    NavigationStack {
        MindfulnessBellView()
    }
} 