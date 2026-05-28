# fantasy_camera_flutter

Flutter camera app backed by the local `camera_avfoundation` package.

## Camera zoom

The app keeps camera zoom state in `cameraStateProvider`.

On iOS, the active camera's raw AVFoundation zoom capabilities are loaded with
`AVFoundationCamera.getZoomCapabilities`. The app treats
`recommendedMaxZoomFactor` as the effective maximum raw zoom when it is
available, because `maxZoomFactor` maps to
`AVCaptureDevice.maxAvailableVideoZoomFactor` and can be much higher than the
system Camera app's zoom UI range.

Fallback behavior:

- Use `recommendedMaxZoomFactor` when AVFoundation provides it.
- Otherwise use `maxZoomFactor`.

All zoom entry points clamp to the effective raw range:

- pinch zoom via `setScaledZoom`
- zoom stop selection via `setDisplayZoom`
- immediate display zoom via `setDisplayZoomImmediately`

The visible zoom labels use `displayZoomFactorMultiplier` to convert raw
AVFoundation zoom into display zoom.
