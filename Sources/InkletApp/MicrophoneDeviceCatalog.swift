import AVFoundation
import Foundation

struct MicrophoneDeviceOption: Identifiable, Equatable {
    static let systemDefaultID = "__system_default_microphone__"

    let id: String
    let deviceID: String?
    let name: String

    var localizedName: String {
        deviceID == nil ? L10n.text("settings.microphone.systemDefault") : name
    }

    static func systemDefault() -> MicrophoneDeviceOption {
        MicrophoneDeviceOption(
            id: systemDefaultID,
            deviceID: nil,
            name: L10n.text("settings.microphone.systemDefault")
        )
    }
}

@MainActor
struct MicrophoneDeviceCatalog {
    func options() -> [MicrophoneDeviceOption] {
        let deviceOptions = Self.availableAudioDevices().map { device in
            MicrophoneDeviceOption(
                id: device.uniqueID,
                deviceID: device.uniqueID,
                name: device.localizedName
            )
        }

        return [MicrophoneDeviceOption.systemDefault()] + deviceOptions
    }

    static func availableAudioDevices() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        var seenDeviceIDs = Set<String>()
        return discoverySession.devices.filter { device in
            seenDeviceIDs.insert(device.uniqueID).inserted
        }
    }
}
