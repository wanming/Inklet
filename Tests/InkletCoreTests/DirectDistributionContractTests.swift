import CoreFoundation
import Foundation
import XCTest

final class DirectDistributionContractTests: XCTestCase {
    func testPlistBooleanTrueRejectsNumericLookalikes() throws {
        let propertyList = try propertyList(from: Data(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0">
            <dict>
                <key>integer</key>
                <integer>1</integer>
                <key>real</key>
                <real>1.0</real>
                <key>boolean</key>
                <true/>
            </dict>
            </plist>
            """.utf8
        ))

        XCTAssertFalse(isTruePlistBoolean(propertyList["integer"]))
        XCTAssertFalse(isTruePlistBoolean(propertyList["real"]))
        XCTAssertTrue(isTruePlistBoolean(propertyList["boolean"]))
    }

    func testEntitlementsContainOnlyDirectDistributionMicrophoneAccess() throws {
        let entitlements = try propertyList(at: repositoryRoot
            .appendingPathComponent("StoreSupport/Inklet.entitlements"))
        let expected: [String: Any] = [
            "com.apple.security.device.audio-input": true
        ]

        XCTAssertEqual(entitlements as NSDictionary, expected as NSDictionary)
        XCTAssertTrue(isTruePlistBoolean(entitlements["com.apple.security.device.audio-input"]))

        let forbiddenKeys = [
            "com.apple.security.app-sandbox",
            "com.apple.security.network.client",
            "com.apple.security.device.microphone",
            "com.apple.security.automation.apple-events",
            "com.apple.security.get-task-allow"
        ]
        for key in forbiddenKeys {
            XCTAssertNil(entitlements[key], "Direct distribution must not include \(key)")
        }
    }

    func testInfoPlistDeclaresOnlyMicrophonePrivacyUsage() throws {
        let infoPlist = try propertyList(at: repositoryRoot
            .appendingPathComponent("StoreSupport/Info.plist"))
        let microphoneUsageDescription = try XCTUnwrap(
            infoPlist["NSMicrophoneUsageDescription"] as? String
        )

        XCTAssertEqual(
            microphoneUsageDescription,
            "Inklet uses the microphone only during a valid Dictation hold. Speech is recognized on this Mac, or by OpenAI if you choose it, and a temporary recovery recording is kept for that session."
        )
        XCTAssertNil(infoPlist["NSAppleEventsUsageDescription"])
    }

    func testAllLocalizedInfoPlistStringsDeclareOnlyMicrophonePrivacyUsage() throws {
        let localizationsRoot = repositoryRoot
            .appendingPathComponent("StoreSupport/InfoPlistStrings", isDirectory: true)
        let expectedMicrophoneUsageDescriptions = [
            "de.lproj/InfoPlist.strings": "Inklet verwendet das Mikrofon nur, während du die Diktierfunktion gültig gedrückt hältst. Die Sprache wird auf diesem Mac erkannt oder, wenn du es wählst, von OpenAI, und für diese Sitzung wird eine temporäre Wiederherstellungsaufnahme gespeichert.",
            "en.lproj/InfoPlist.strings": "Inklet uses the microphone only during a valid Dictation hold. Speech is recognized on this Mac, or by OpenAI if you choose it, and a temporary recovery recording is kept for that session.",
            "es.lproj/InfoPlist.strings": "Inklet usa el micrófono solo durante una pulsación válida para Dictado. La voz se reconoce en este Mac, o en OpenAI si lo eliges, y se conserva una grabación temporal de recuperación para esa sesión.",
            "fr.lproj/InfoPlist.strings": "Inklet utilise le microphone uniquement lors d’un appui valide pour la dictée. La parole est reconnue sur ce Mac, ou par OpenAI si vous le choisissez, et un enregistrement temporaire de récupération est conservé pour cette session.",
            "it.lproj/InfoPlist.strings": "Inklet usa il microfono solo durante una pressione valida per la dettatura. Il parlato viene riconosciuto su questo Mac, o da OpenAI se lo scegli, e viene conservata una registrazione temporanea di recupero per la sessione.",
            "ja.lproj/InfoPlist.strings": "Inklet は有効な音声入力の長押し中だけマイクを使います。音声はこの Mac で認識されるか、選択した場合は OpenAI で認識され、そのセッション用の一時的な復旧録音を保持します。",
            "ko.lproj/InfoPlist.strings": "Inklet은 유효한 받아쓰기 길게 누르기 동안에만 마이크를 사용합니다. 음성은 이 Mac에서 인식되거나, 선택한 경우 OpenAI에서 인식되며, 해당 세션의 임시 복구 녹음을 보관합니다.",
            "pt.lproj/InfoPlist.strings": "O Inklet usa o microfone apenas durante um pressionamento válido para Ditado. A fala é reconhecida neste Mac, ou pela OpenAI se você escolher, e uma gravação temporária de recuperação é mantida para essa sessão.",
            "zh-Hans.lproj/InfoPlist.strings": "Inklet 仅在有效长按听写快捷键时使用麦克风。语音在本机识别，或在你选择时由 OpenAI 识别，并为该次会话保留一份临时恢复录音。",
            "zh-Hant.lproj/InfoPlist.strings": "Inklet 僅在有效長按聽寫快速鍵時使用麥克風。語音會在本機辨識，或在你選擇時由 OpenAI 辨識，並為該次工作階段保留一份暫時復原錄音。"
        ]
        let expectedLocalizationPaths = Set(expectedMicrophoneUsageDescriptions.keys)
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(
            at: localizationsRoot,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ))
        var localizationURLs: [URL] = []

        for case let fileURL as URL in enumerator
            where fileURL.lastPathComponent == "InfoPlist.strings"
        {
            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            guard resourceValues.isRegularFile == true else {
                continue
            }
            localizationURLs.append(fileURL)
        }

        localizationURLs.sort { $0.path < $1.path }
        let discoveredLocalizationPaths = Set(localizationURLs.map { localizationURL in
            localizationURL.pathComponents
                .dropFirst(localizationsRoot.pathComponents.count)
                .joined(separator: "/")
        })
        let missingPaths = expectedLocalizationPaths.subtracting(discoveredLocalizationPaths)
        let unexpectedPaths = discoveredLocalizationPaths.subtracting(expectedLocalizationPaths)

        XCTAssertEqual(localizationURLs.count, 10)
        XCTAssertEqual(
            discoveredLocalizationPaths,
            expectedLocalizationPaths,
            """
            Localized InfoPlist.strings paths differ.
            Missing: \(missingPaths.sorted())
            Unexpected: \(unexpectedPaths.sorted())
            """
        )

        for localizationURL in localizationURLs {
            let localizedStrings = try propertyList(at: localizationURL)
            let microphoneUsageDescription = try XCTUnwrap(
                localizedStrings["NSMicrophoneUsageDescription"] as? String,
                "Missing microphone privacy copy in \(localizationURL.path)"
            )

            let relativePath = localizationURL.pathComponents
                .dropFirst(localizationsRoot.pathComponents.count)
                .joined(separator: "/")
            XCTAssertEqual(
                microphoneUsageDescription,
                expectedMicrophoneUsageDescriptions[relativePath],
                "Unexpected microphone privacy copy in \(localizationURL.path)"
            )
            XCTAssertNil(
                localizedStrings["NSAppleEventsUsageDescription"],
                "Unexpected Apple Events privacy copy in \(localizationURL.path)"
            )
        }
    }

    func testPrivacyPolicyDeclaresRealtimeDictationContractWithExactUpdateDate() throws {
        let policy = try text(at: "docs/privacy-policy.md")
        let updateLines = policy.split(separator: "\n").filter {
            $0.hasPrefix("Last updated:")
        }

        XCTAssertEqual(updateLines, ["Last updated: October 25, 2026"])
        for required in [
            "Active microphone audio is streamed to OpenAI's Realtime transcription service as it is captured.",
            "Dictation audio is sent only to OpenAI, and only when you choose OpenAI for speech recognition; with On this Mac, dictation audio never leaves your Mac.",
            "one temporary local `.m4a` recovery recording",
            "https://api.openai.com/v1/audio/transcriptions",
            "The recovery model is configurable, but the endpoint is not editable.",
            "same existing OpenAI API key used by realtime dictation",
            "remains local until the fallback request actually begins",
            "uploaded at most once",
            "success, no speech, fallback success or failure, Escape, focus loss, popover closure, supersession, migration maintenance, and app termination",
            "does not log audio or transcript content, Authorization headers, microphone identifiers, or temporary file paths",
            "Audio is never placed on the clipboard or stored in History.",
            "An unprocessed dictated draft creates no History entry.",
            "Existing legacy Voice entries remain locally readable.",
            "Microphone permission is distinct from Accessibility permission",
            "finishing dictation does not insert text into another app",
        ] {
            XCTAssertTrue(policy.contains(required), required)
        }

        let distributionContract = try text(at: "scripts/test-direct-distribution.sh")
        XCTAssertTrue(distributionContract.contains("Last updated: October 25, 2026"))
        XCTAssertFalse(distributionContract.contains("Last updated: September 5, 2026"))
        XCTAssertFalse(distributionContract.contains("Last updated: August 30, 2026"))
        XCTAssertFalse(distributionContract.contains("Last updated: August 12, 2026"))
    }

    func testReadmesDescribeFixedSingleRequestDictationRecovery() throws {
        let english = try text(at: "README.md")
        let chinese = try text(at: "README.zh-CN.md")

        for required in [
            "Advanced Dictation exposes only the recovery model; the recovery endpoint is not editable.",
            "https://api.openai.com/v1/audio/transcriptions",
            "same existing OpenAI API key used by realtime dictation",
            "remains local until the fallback request actually begins",
            "uploaded at most once",
        ] {
            XCTAssertTrue(english.contains(required), required)
        }
        for required in [
            "高级听写只提供恢复模型，不提供端点设置；恢复端点不可编辑。",
            "https://api.openai.com/v1/audio/transcriptions",
            "实时听写所用的同一把现有 OpenAI API key",
            "在备用请求真正开始前始终只保存在本机",
            "最多上传一次",
        ] {
            XCTAssertTrue(chinese.contains(required), required)
        }
    }

    func testReadmesDescribeMergedHoldOnlyWritingDictationAndRejectStandaloneWorkflow() throws {
        let english = try text(at: "README.md")
        let chinese = try text(at: "README.zh-CN.md")
        let combined = english + "\n" + chinese

        for required in [
            "Open Writing Assistant",
            "Confirm a Prompt Mode",
            "Hold the configured Dictation shortcut",
            "Release to finalize",
            "Press Return only when ready",
            "A short press does nothing.",
            "does not run the Prompt Mode or insert text into another app",
        ] {
            XCTAssertTrue(english.contains(required), required)
        }
        for step in [
            "1. **Open Writing Assistant**",
            "2. **Confirm a Prompt Mode**",
            "3. **Put the caret in the source draft, or select text to replace.**",
            "4. **Hold the configured Dictation shortcut**",
            "5. **Release to finalize**",
            "6. Review and edit the dictated draft.",
            "7. **Press Return only when ready**",
            "Dictation inserts at the caret or replaces the selection.",
        ] {
            XCTAssertTrue(english.contains(step), step)
        }
        for required in [
            "打开写作助手",
            "确认一个 Prompt 模式",
            "长按已配置的听写快捷键",
            "松开以完成转写",
            "准备好后再按 Return",
            "短按不会执行任何操作",
            "不会运行 Prompt 模式，也不会把文本插入其他 App",
        ] {
            XCTAssertTrue(chinese.contains(required), required)
        }
        for step in [
            "1. 用 `Option+Space` **打开写作助手**",
            "2. **确认一个 Prompt 模式**",
            "3. **把光标放入原文草稿，或选中要替换的文本。**",
            "4. **长按已配置的听写快捷键**",
            "5. **松开以完成转写**",
            "6. 检查并编辑听写草稿。",
            "7. **准备好后再按 Return**",
            "听写会在光标处插入，或替换选区。",
        ] {
            XCTAssertTrue(chinese.contains(step), step)
        }
        for retired in [
            "Voice Write Assistant",
            "tap-to-toggle",
            "double-tap recording",
            "Voice Recording Mode",
            "compact voice window",
            "Auto Process",
            "单击开始/停止",
            "双击开始/停止",
        ] {
            XCTAssertFalse(combined.contains(retired), retired)
        }
    }

    func testSecurityAndManualChecklistCoverRealtimeDictationRisksAndWorkflowMatrix() throws {
        let security = try text(at: "SECURITY.md")
        for required in [
            "Realtime transport authentication",
            "bounded in-memory PCM",
            "terminal-session arbitration",
            "temporary recovery-file deletion",
            "Legacy stored endpoint values are normalized to the fixed canonical endpoint",
            "https://api.openai.com/v1/audio/transcriptions",
            "same OpenAI API key as realtime dictation",
            "same-host and cross-host redirects",
            "before forwarding the Authorization header or audio",
            "audio payloads, transcript contents, Authorization headers, microphone identifiers, or temporary file paths",
        ] {
            XCTAssertTrue(security.contains(required), required)
        }

        let checklist = try text(at: "docs/manual-test-checklist.md")
        for required in [
            "mode picker and result editor",
            "modifier already held",
            "combining marks",
            "one-step undo",
            "marked-text Escape",
            "connection failure while held",
            "late-event races",
            "permission is not requested",
            "rapid reopen",
            "no draft-only History",
            "legacy Voice History",
            "phase-only announcements",
            "Advanced Dictation exposes only the recovery model",
            "recovery endpoint is not editable",
            "compare responsiveness with the prior local build",
            "speak immediately after holding",
            "the beginning of the utterance is preserved",
        ] {
            XCTAssertTrue(checklist.contains(required), required)
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .standardizedFileURL
    }

    private func propertyList(at fileURL: URL) throws -> [String: Any] {
        try propertyList(from: Data(contentsOf: fileURL))
    }

    private func propertyList(from data: Data) throws -> [String: Any] {
        let propertyList = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        return try XCTUnwrap(propertyList as? [String: Any])
    }

    private func text(at relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func isTruePlistBoolean(_ value: Any?) -> Bool {
        guard let value,
              CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID()
        else {
            return false
        }
        return (value as? Bool) == true
    }
}
