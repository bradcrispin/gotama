import Foundation

enum AncientText: String, CaseIterable, Identifiable {
    case none = "None"
    case atthakas = "Atthakas (Snp 4.2 - 4.5)"
    case atthakavagga = "Atthakavagga (Snp 4)"
    
    var id: String { rawValue }
    
    var content: String {
        switch self {
        case .none:
            return ""
        case .atthakas:
            return AncientTextAtthakas.content
        case .atthakavagga:
            return AncientTextAtthakavagga.content
        }
    }
    
    var description: String {
        switch self {
        case .none:
            return "No ancient text selected"
        case .atthakas:
            return "Selected verses from the Atthaka collection"
        case .atthakavagga:
            return "The complete Atthaka collection"
        }
    }
} 