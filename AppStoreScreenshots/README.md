# App Store screenshots

Ready-to-upload screenshot sets for App Store Connect. Upload them in file-name order.

| Folder | Size (px) | App Store Connect slot |
| --- | --- | --- |
| `iPhone-6.5_1284x2778/` | 1284 × 2778 | iPhone 6.5" Display |
| `iPhone-6.5_1242x2688/` | 1242 × 2688 | iPhone 6.5" Display (alternate size) |
| `iPhone-6.9_1320x2868/` | 1320 × 2868 | iPhone 6.9" Display |
| `iPad-13_2064x2752/` | 2064 × 2752 | iPad 13" Display |
| `Mac_2880x1800/` | 2880 × 1800 | Mac |

All files are RGB PNGs with no transparency. `preview.png` shows every set side by side.

## Slides

1. **Big enough to read from the mic.** Ready state, 5:00.
2. **Start & stop with your headphones.** Running, with the Bluetooth play/pause callout. (Mac: Space, Return or play/pause.)
3. **The last minute can't be missed.** Final-minute yellow screen with giant seconds.
4. **Time's up? Everyone knows.** Red 0:00.
5. **Tight five to headliner set.** Settings sheet (iPhone and iPad only).
6. **Fills any screen, any way you hold it.** iPhone and iPad together, portrait and landscape (iPhone and iPad only).

## How they're made

The app screens are an HTML replica of `Open Micer Timer/ContentView.swift` (same layout math as `StageLayout`), placed in device frames with captions and rendered by headless Chromium. Fonts: SF Pro when installed, otherwise the bundled Inter and Nunito.

```sh
cd AppStoreScreenshots/generator
npm install
npm run render                          # every set + preview.png
node render.js iPhone-6.5_1284x2778     # one set
```

Edit captions and scenes in `generator/slides.js`. If the timer UI changes, update `generator/app.js` to match.

### Using real simulator captures

To frame real captures instead of the replica, save them as `generator/real/<folder>/<slide>.png` (for example `generator/real/iPhone-6.5_1284x2778/01-giant-countdown.png`) and re-run the render. A capture from an iPhone 6.9" simulator (1320 × 2868) fits the phone frame exactly. Slide 6 always uses the replica because it shows two devices.
