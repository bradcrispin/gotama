import SwiftUI

/// Typography extensions for consistent text styling across the app
extension View {
    /// Applies standard reading text configuration for optimal readability
    func readingText() -> some View {
        self
            .font(.system(size: 18)) // iOS standard reading size
            .lineSpacing(5) // Optimal line height for readability
    }
    
    /// Applies secondary reading text configuration (for metadata, etc)
    func secondaryReadingText() -> some View {
        self
            .font(.system(size: 16)) // Slightly smaller than main text
            .lineSpacing(4) // Slightly tighter line spacing
            .foregroundStyle(.secondary)
    }
    
    /// Applies monospaced code text configuration
    func codeText() -> some View {
        self
            .font(.system(.subheadline, design: .monospaced))
            .lineSpacing(4)
    }
    
    /// Applies section header text configuration
    func sectionHeaderText() -> some View {
        self
            .font(.system(size: 20, weight: .semibold)) // Slightly smaller, still prominent
            .foregroundStyle(.primary)
            .textCase(nil) // Ensure proper case by default
    }
    
    /// Applies navigation row text configuration
    func navigationRowText() -> some View {
        self
            .font(.system(size: 17))
            .lineLimit(1)
            .truncationMode(.tail)
    }
    
    /// Applies metadata text configuration for navigation items
    func navigationMetadataText() -> some View {
        self
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
    }
    
    /// Applies form section header text configuration
    func formSectionHeaderText() -> some View {
        self
            .font(.system(size: 13, weight: .medium))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
    
    /// Applies form row title text configuration
    func formRowTitleText() -> some View {
        self
            .font(.system(size: 17))
            .foregroundStyle(.primary)
    }
    
    /// Applies form row subtitle text configuration
    func formRowSubtitleText() -> some View {
        self
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .lineSpacing(2)
    }
    
    /// Applies form footer text configuration
    func formFooterText() -> some View {
        self
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
} 