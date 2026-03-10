import Foundation

struct ProjectSwitcherSelection {
    var selectedProjectID: String?

    mutating func synchronizeSelection(with filteredProjects: [RecentProjectEntry]) {
        let ids = filteredProjects.map(\.id)
        guard !ids.isEmpty else {
            selectedProjectID = nil
            return
        }
        if let selectedProjectID, ids.contains(selectedProjectID) {
            return
        }
        selectedProjectID = ids[0]
    }

    mutating func moveSelection(offset: Int, in filteredProjects: [RecentProjectEntry]) {
        guard !filteredProjects.isEmpty else {
            selectedProjectID = nil
            return
        }
        guard let currentSelectionID = selectedProjectID,
              let index = filteredProjects.firstIndex(where: { $0.id == currentSelectionID }) else {
            selectedProjectID = filteredProjects[0].id
            return
        }
        let nextIndex = max(0, min(filteredProjects.count - 1, index + offset))
        selectedProjectID = filteredProjects[nextIndex].id
    }

    func selectedProject(in filteredProjects: [RecentProjectEntry]) -> RecentProjectEntry? {
        if let selectedProjectID {
            return filteredProjects.first(where: { $0.id == selectedProjectID })
        }
        return filteredProjects.first
    }
}
