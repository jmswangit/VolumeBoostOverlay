# VolumeBoostOverlay

A standalone [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) plugin that adds an
independent volume boost control to the iOS YouTube video player overlay.

The boost is applied to YouTube's internal audio pipeline (via `AVPlayer`,
`AVAudioPlayer`, `AVAudioPlayerNode` and `AVSampleBufferAudioRenderer`), so it does
**not** touch the iOS system volume.

## Features

- A `Volume boost` text button in the video overlay (top or bottom, configurable
  in YouTube Settings → Video Overlay).
- Tap it to open a slider (100% – 2000%) with `-`/`+` buttons and quick presets.
- Up to 200x physical amplitude at 2000%.
- No screen-edge gestures; the overlay button is the only control.

## Prerequisites

- [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) `>= 2.2.0`
  (`com.ps.ytvideooverlay`), installed as a separate package.

## Build

```
make package FINALPACKAGE=1
```

Requires Theos plus the following headers on the include path:

- [YouTubeHeader](https://github.com/PoomSmart/YouTubeHeader) → `$THEOS/include/YouTubeHeader`
- [PSHeader](https://github.com/PoomSmart/PSHeader) → `$THEOS/include/PSHeader`
- [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) → sibling `../YTVideoOverlay`

A GitHub Actions workflow is included that sets all of this up and publishes the
`.deb`, `.dylib` and `.bundle.zip`.
