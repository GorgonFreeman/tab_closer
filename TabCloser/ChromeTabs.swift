import AppKit
import Foundation

struct ChromeTab: Identifiable, Hashable {
    let id: String
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String
    let domain: String
}

enum ChromeTabsError: LocalizedError {
    case chromeNotRunning
    case appleScriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .chromeNotRunning:
            return "Google Chrome is not running."
        case .appleScriptFailed(let message):
            return message
        }
    }
}

enum ChromeTabs {
    private static let fieldSeparator = "\u{001f}"

    static func isChromeRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.google.Chrome"
        }
    }

    static func fetchTabs() throws -> [ChromeTab] {
        guard isChromeRunning() else {
            throw ChromeTabsError.chromeNotRunning
        }

        let sep = fieldSeparator
        let script = """
        tell application "Google Chrome"
            set output to ""
            set windowIndex to 1
            repeat with w in windows
                set tabIndex to 1
                repeat with t in tabs of w
                    set tabTitle to title of t
                    set tabURL to URL of t
                    set output to output & windowIndex & "\(sep)" & tabIndex & "\(sep)" & tabTitle & "\(sep)" & tabURL & linefeed
                    set tabIndex to tabIndex + 1
                end repeat
                set windowIndex to windowIndex + 1
            end repeat
            return output
        end tell
        """

        let raw = try runAppleScript(script)
        return parseTabs(raw)
    }

    static func activateTab(_ tab: ChromeTab) throws {
        guard isChromeRunning() else {
            throw ChromeTabsError.chromeNotRunning
        }

        let script = """
        tell application "Google Chrome"
            activate
            if (count of windows) >= \(tab.windowIndex) then
                set index of window \(tab.windowIndex) to 1
                tell window 1
                    if (count of tabs) >= \(tab.tabIndex) then
                        set active tab index to \(tab.tabIndex)
                    end if
                end tell
            end if
        end tell
        """
        _ = try runAppleScript(script)
    }

    static func closeTab(_ tab: ChromeTab) throws {
        guard isChromeRunning() else {
            throw ChromeTabsError.chromeNotRunning
        }

        let script = """
        tell application "Google Chrome"
            if (count of windows) >= \(tab.windowIndex) then
                tell window \(tab.windowIndex)
                    if (count of tabs) >= \(tab.tabIndex) then
                        close tab \(tab.tabIndex)
                    end if
                end tell
            end if
        end tell
        """
        _ = try runAppleScript(script)
    }

    /// Bookmarks the tab under Bookmarks Bar → "TabCloser save for later", then closes it.
    static func bookmarkAndCloseTab(_ tab: ChromeTab) throws {
        guard isChromeRunning() else {
            throw ChromeTabsError.chromeNotRunning
        }

        let folderName = "TabCloser save for later"
        let title = escapeAppleScriptString(tab.title)
        let url = escapeAppleScriptString(tab.url)

        let script = """
        tell application "Google Chrome"
            set folderName to "\(folderName)"
            set bar to bookmarks bar
            set targetFolder to missing value
            repeat with f in bookmark folders of bar
                if title of f is folderName then
                    set targetFolder to f
                    exit repeat
                end if
            end repeat
            if targetFolder is missing value then
                tell bar
                    set targetFolder to make new bookmark folder with properties {title:folderName}
                end tell
            end if
            tell targetFolder
                make new bookmark item with properties {title:"\(title)", URL:"\(url)"}
            end tell
            if (count of windows) >= \(tab.windowIndex) then
                tell window \(tab.windowIndex)
                    if (count of tabs) >= \(tab.tabIndex) then
                        close tab \(tab.tabIndex)
                    end if
                end tell
            end if
        end tell
        """
        _ = try runAppleScript(script)
    }

    /// Closes tabs highest-index-first so AppleScript indices stay valid.
    static func closeTabs(_ tabs: [ChromeTab]) throws {
        guard isChromeRunning() else {
            throw ChromeTabsError.chromeNotRunning
        }

        let ordered = tabs.sorted {
            if $0.windowIndex != $1.windowIndex {
                return $0.windowIndex > $1.windowIndex
            }
            return $0.tabIndex > $1.tabIndex
        }

        for tab in ordered {
            try closeTab(tab)
        }
    }

    private static func escapeAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func parseTabs(_ raw: String) -> [ChromeTab] {
        let lines = raw.split(whereSeparator: \.isNewline)
        var tabs: [ChromeTab] = []

        for line in lines {
            let parts = line.split(separator: Character(fieldSeparator), maxSplits: 3, omittingEmptySubsequences: false)
            guard parts.count == 4,
                  let windowIndex = Int(parts[0]),
                  let tabIndex = Int(parts[1]) else {
                continue
            }

            let title = String(parts[2])
            let url = String(parts[3])
            let domain = domain(from: url)
            let id = "\(windowIndex)-\(tabIndex)-\(url)-\(title)"
            tabs.append(
                ChromeTab(
                    id: id,
                    windowIndex: windowIndex,
                    tabIndex: tabIndex,
                    title: title.isEmpty ? url : title,
                    url: url,
                    domain: domain
                )
            )
        }

        return tabs
    }

    static func groupedByDomain(_ tabs: [ChromeTab]) -> [(domain: String, tabs: [ChromeTab])] {
        let grouped = Dictionary(grouping: tabs, by: \.domain)
        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { domain in
                let sortedTabs = (grouped[domain] ?? []).sorted {
                    $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return (domain: domain, tabs: sortedTabs)
            }
    }

    private static func domain(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host, !host.isEmpty else {
            return "(no domain)"
        }
        return host.lowercased()
    }

    private static func runAppleScript(_ source: String) throws -> String {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw ChromeTabsError.appleScriptFailed("Could not create AppleScript.")
        }

        let result = script.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript failed."
            throw ChromeTabsError.appleScriptFailed(message)
        }

        return result.stringValue ?? ""
    }
}
