import AVFoundation
import CoreAudio

/// Detects whether the camera or microphone is actively in use by another application.
/// Uses AVCaptureDevice for camera detection and CoreAudio HAL for microphone detection.
/// These checks do NOT trigger TCC permission prompts — they only query device state.
///
/// Sandbox note: In the App Sandbox, AVCaptureDevice discovery may return an empty list
/// and CoreAudio property queries may fail silently. Both methods return `false` in that
/// case (assume media is not in use), meaning blackouts may occasionally fire during
/// video/audio calls. This is an acceptable degradation for the sandboxed App Store build.
class MediaUsageDetector {

    static let shared = MediaUsageDetector()
    private init() {}

    /// Returns true if any camera or microphone is currently in use
    func isMediaInUse() -> Bool {
        return isCameraInUse() || isMicrophoneInUse()
    }

    // MARK: - Camera Detection

    /// Check if any video capture device is being used by another app
    private func isCameraInUse() -> Bool {
        let cameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        ).devices

        return cameras.contains { $0.isInUseByAnotherApplication }
    }

    // MARK: - Microphone Detection

    /// Check if any audio input device is running (i.e., actively capturing audio)
    private func isMicrophoneInUse() -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Get the list of all audio device IDs
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize
        )
        guard status == noErr else { return false }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { return false }

        // Check each device: does it have input channels and is it running?
        for deviceID in deviceIDs {
            if hasInputChannels(deviceID) && isDeviceRunning(deviceID) {
                return true
            }
        }

        return false
    }

    /// Check whether the given audio device has any input channels
    private func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return false }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }

        let getStatus = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferListPointer)
        guard getStatus == noErr else { return false }

        let bufferList = bufferListPointer.pointee
        return bufferList.mNumberBuffers > 0 && bufferList.mBuffers.mNumberChannels > 0
    }

    /// Check if a device is currently running (capturing audio somewhere)
    private func isDeviceRunning(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var isRunning: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &isRunning)
        return status == noErr && isRunning != 0
    }
}
