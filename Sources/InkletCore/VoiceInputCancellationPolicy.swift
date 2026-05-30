public enum VoiceInputCancellationPolicy {
    public static func shouldCancel(keyCode: UInt16, isVoiceInputActive: Bool) -> Bool {
        isVoiceInputActive && keyCode == 53
    }
}
