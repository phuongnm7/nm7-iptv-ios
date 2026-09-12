import Foundation

struct PlaylistSource: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var url: URL
    let isBuiltIn: Bool
}
