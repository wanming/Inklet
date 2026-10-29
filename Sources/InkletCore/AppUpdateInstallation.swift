import Foundation

/// Whether an update can replace the running app in place.
public enum AppUpdateInstallLocation {
    /// The bundle and its folder must be writable, and the app must not run from App Translocation,
    /// where macOS keeps a read-only copy of an app opened straight from Downloads or a disk image.
    public static func canReplace(
        bundleURL: URL,
        isWritable: (String) -> Bool = { FileManager.default.isWritableFile(atPath: $0) }
    ) -> Bool {
        let bundleURL = bundleURL.standardizedFileURL
        guard bundleURL.pathExtension == "app",
              !bundleURL.path.contains("/AppTranslocation/")
        else {
            return false
        }
        return isWritable(bundleURL.path)
            && isWritable(bundleURL.deletingLastPathComponent().path)
    }
}

/// Remembers which build an install tried to put in place until that build is running,
/// so an install that didn't take is offered again only when the person asks for it.
public struct AppUpdateInstallAttempts {
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Call on launch: forgets an attempt the running build has reached.
    public func settle(currentBuild: Int) {
        let attemptedBuild = userDefaults.integer(forKey: InkletPreferenceKeys.attemptedUpdateInstallBuild)
        if attemptedBuild > 0, currentBuild >= attemptedBuild {
            clear()
        }
    }

    public func record(build: Int) {
        userDefaults.set(build, forKey: InkletPreferenceKeys.attemptedUpdateInstallBuild)
    }

    public func clear() {
        userDefaults.removeObject(forKey: InkletPreferenceKeys.attemptedUpdateInstallBuild)
    }

    /// True after `settle` when an earlier install of this build left the old version running.
    public func didFail(build: Int) -> Bool {
        userDefaults.integer(forKey: InkletPreferenceKeys.attemptedUpdateInstallBuild) == build
    }
}

/// Swaps the staged app in once Inklet has quit, and puts the old app back if that fails.
public enum AppUpdateSwapScript {
    public static let source = """
    #!/bin/sh
    # Arguments: <Inklet pid> <installed app> <new app> <backup path> <relaunch: 1 or 0>
    pid="$1"
    target="$2"
    replacement="$3"
    backup="$4"
    relaunch="$5"
    workdir="$(dirname "$replacement")"

    waited=0
    while kill -0 "$pid" 2>/dev/null; do
      if [ "$waited" -ge 600 ]; then
        exit 1
      fi
      sleep 0.1
      waited=$((waited + 1))
    done

    status=1
    if mv "$target" "$backup"; then
      if mv "$replacement" "$target"; then
        status=0
      else
        mv "$backup" "$target"
      fi
    fi

    if [ "$relaunch" = "1" ]; then
      /usr/bin/open "$target"
    fi
    # Keep the staging folder if the old app couldn't be put back, so it is never deleted.
    if [ -d "$target" ]; then
      rm -rf "$workdir"
    fi
    exit "$status"
    """

    /// The backup lands in the staging folder, which sits on the same volume as the installed app,
    /// so both moves are renames and the app is never missing for more than an instant.
    public static func arguments(
        scriptPath: String,
        processIdentifier: Int32,
        installedAppURL: URL,
        replacementURL: URL,
        relaunches: Bool
    ) -> [String] {
        [
            scriptPath,
            String(processIdentifier),
            installedAppURL.path,
            replacementURL.path,
            replacementURL.deletingLastPathComponent().appendingPathComponent("Previous.app").path,
            relaunches ? "1" : "0",
        ]
    }
}
