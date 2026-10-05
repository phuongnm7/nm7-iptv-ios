import XCTest
@testable import NM7IPTV

@MainActor
final class SourceSelectionTests: XCTestCase {
    func testOpeningTelevisionKeepsImportedPlaylistSelected() {
        XCTAssertNil(
            AppViewModel.builtInSourceID(for: .television, activeSourceID: "imported-m3u")
        )
    }

    func testOpeningSportsKeepsImportedPlaylistSelected() {
        XCTAssertNil(
            AppViewModel.builtInSourceID(for: .sports, activeSourceID: "imported-m3u")
        )
    }

    func testOpeningTelevisionFromBuiltInSportsSourceSelectsDefaultTelevision() {
        XCTAssertEqual(
            AppViewModel.builtInSourceID(for: .television, activeSourceID: SourceStore.sportsID),
            SourceStore.defaultID
        )
    }

    func testOpeningSportsFromDefaultSourceSelectsBuiltInSportsPlaylist() {
        XCTAssertEqual(
            AppViewModel.builtInSourceID(for: .sports, activeSourceID: SourceStore.defaultID),
            SourceStore.sportsID
        )
    }
}
