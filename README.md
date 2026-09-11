# VolumeBoostOverlay

> **This is a fork/rework of [VolumeBoostYT](https://github.com/irum0320/VolumeBoostYT)** by
> [irum0320](https://github.com/irum0320). The original tweak boosted YouTube's internal
> volume with a right-edge pan gesture; this fork removes the gesture and rebuilds the whole
> thing as a [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) plugin, with the
> overlay button + slider UI adapted from
> [YouSpeed](https://github.com/PoomSmart/YouSpeed) by [PoomSmart](https://github.com/PoomSmart).

A standalone YTVideoOverlay plugin that adds an independent volume boost control to the iOS
YouTube video player overlay.

The boost is applied to YouTube's internal audio pipeline (via `AVPlayer`,
`AVAudioPlayer`, `AVAudioPlayerNode` and `AVSampleBufferAudioRenderer`), so it does
**not** touch the iOS system volume.

## Features

- A standard volume icon button in the video overlay (top or bottom, configurable in
  YouTube Settings → Video Overlay).
- Tap the icon to open a slider (0% – 2000%) with `-`/`+` buttons and quick presets.
- The icon switches to a muted icon at 0%.
- Up to 200x physical amplitude at 2000%.
- No screen-edge gestures; the overlay button is the only control.

## Credits

- [VolumeBoostYT](https://github.com/irum0320/VolumeBoostYT) by irum0320 — original
  independent-audio-boost approach and `AVPlayer`/`AVAudioPlayer`/`AVSampleBufferAudioRenderer`
  hooks.
- [YouSpeed](https://github.com/PoomSmart/YouSpeed) by PoomSmart — overlay registration and
  the slider alert UI this fork is modeled on.
- [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) by PoomSmart — overlay button
  and settings framework.

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
