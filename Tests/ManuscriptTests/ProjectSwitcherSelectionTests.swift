import XCTest
@testable import ScribblesNScripts

final class ProjectSwitcherSelectionTests: XCTestCase {
    func testSynchronizeSelectionDefaultsToFirstProject() {
        var selection = ProjectSwitcherSelection()
        let projects = makeProjects(["A", "B"])

        selection.synchronizeSelection(with: projects)

        XCTAssertEqual(selection.selectedProjectID, projects[0].id)
    }

    func testSynchronizeSelectionPreservesExistingSelectionWhenStillPresent() {
        let projects = makeProjects(["A", "B", "C"])
        var selection = ProjectSwitcherSelection(selectedProjectID: projects[1].id)

        selection.synchronizeSelection(with: projects)

        XCTAssertEqual(selection.selectedProjectID, projects[1].id)
    }

    func testSynchronizeSelectionClearsSelectionForEmptyProjects() {
        var selection = ProjectSwitcherSelection(selectedProjectID: "stale")

        selection.synchronizeSelection(with: [])

        XCTAssertNil(selection.selectedProjectID)
    }

    func testMoveSelectionAdvancesAndClampsBounds() {
        let projects = makeProjects(["A", "B", "C"])
        var selection = ProjectSwitcherSelection(selectedProjectID: projects[0].id)

        selection.moveSelection(offset: 1, in: projects)
        XCTAssertEqual(selection.selectedProjectID, projects[1].id)

        selection.moveSelection(offset: 99, in: projects)
        XCTAssertEqual(selection.selectedProjectID, projects[2].id)
    }

    func testMoveSelectionRetreatsAndClampsBounds() {
        let projects = makeProjects(["A", "B", "C"])
        var selection = ProjectSwitcherSelection(selectedProjectID: projects[2].id)

        selection.moveSelection(offset: -1, in: projects)
        XCTAssertEqual(selection.selectedProjectID, projects[1].id)

        selection.moveSelection(offset: -99, in: projects)
        XCTAssertEqual(selection.selectedProjectID, projects[0].id)
    }

    func testMoveSelectionDefaultsToFirstWhenCurrentSelectionMissing() {
        let projects = makeProjects(["A", "B"])
        var selection = ProjectSwitcherSelection(selectedProjectID: "missing")

        selection.moveSelection(offset: 1, in: projects)

        XCTAssertEqual(selection.selectedProjectID, projects[0].id)
    }

    func testSelectedProjectReturnsSelectedOrFirstFallback() {
        let projects = makeProjects(["A", "B"])
        var selection = ProjectSwitcherSelection(selectedProjectID: projects[1].id)

        XCTAssertEqual(selection.selectedProject(in: projects)?.id, projects[1].id)
        selection.selectedProjectID = nil
        XCTAssertEqual(selection.selectedProject(in: projects)?.id, projects[0].id)
        XCTAssertNil(selection.selectedProject(in: []))
    }

    private func makeProjects(_ names: [String]) -> [RecentProjectEntry] {
        names.map { name in
            let path = "/tmp/\(name)"
            return RecentProjectEntry(
                id: path,
                name: name,
                url: URL(fileURLWithPath: path, isDirectory: true)
            )
        }
    }
}
