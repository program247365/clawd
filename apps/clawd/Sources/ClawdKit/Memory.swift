import Foundation

public enum Memory {
    /// Hands memory the allocator is holding but not using back to the system.
    ///
    /// Parsing a large animation briefly needs tens of megabytes. Once it is freed the allocator keeps
    /// those pages for reuse, which counts against the app for the rest of the day unless it is asked to let go.
    public static func returnUnused() {
        malloc_zone_pressure_relief(nil, 0)
    }
}
