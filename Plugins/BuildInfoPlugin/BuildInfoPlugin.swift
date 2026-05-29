import PackagePlugin
import Foundation

@main
struct BuildInfoPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let outputDirectory = context.pluginWorkDirectoryURL
        let outputFile = outputDirectory.appending(path: "BuildInfo.swift")
        let script = """
        set -euo pipefail
        output_file="$1"
        build_version="${INKLET_BUILD_VERSION:-}"
        if [ -z "$build_version" ]; then
          build_version="$(date '+%Y.%m%d.%H%M')"
        fi
        mkdir -p "$(dirname "$output_file")"
        cat > "$output_file" <<SWIFT
        import Foundation

        enum BuildInfo {
            static let version = "$build_version"

            static var displayVersion: String {
                Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? version
            }
        }

        SWIFT
        """

        return [
            .prebuildCommand(
                displayName: "Generate Inklet build info",
                executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", script, "generate-build-info", outputFile.path],
                outputFilesDirectory: outputDirectory
            )
        ]
    }
}
