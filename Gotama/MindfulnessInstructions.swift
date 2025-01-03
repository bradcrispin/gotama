import Foundation

/// Stores mindfulness instructions for bell notifications
struct MindfulnessInstructions {
    /// Sequential list of mindfulness instructions
    static let instructions = [
        "Notice your breath without changing it",
        "Feel your feet touching the ground",
        "Observe thoughts passing like clouds",
        "Listen to sounds without naming them",
        "Notice tension dissolving in your shoulders",
        "Feel the air touching your skin",
        "Watch desires arise and fade",
        "Notice spaces between thoughts",
        "Feel your hands without moving them",
        "Observe how moods change like weather",
        "Notice what judges and labels",
        "Feel the weight of your body",
        "Watch reactions without following them",
        "Notice what seeks to become something",
        "Feel the stillness behind movement",
        "Observe what clings and what releases",
        "Rest in simple awareness"
    ]
    
    /// Returns the instruction for a given index, cycling through the list if needed
    static func getInstruction(forIndex index: Int) -> String {
        let normalizedIndex = index % instructions.count
        return instructions[normalizedIndex]
    }
    
    /// Returns a random instruction from the list
    static func getRandomInstruction() -> String {
        instructions.randomElement() ?? instructions[0]
    }
} 