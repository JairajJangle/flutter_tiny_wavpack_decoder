# flutter_tiny_wavpack_decoder example

A minimal Flutter app that decodes either a bundled WavPack sample
(`assets/sine_stereo_16bit_44100.wv`) or a `.wv` file you pick, and shows
live decode progress, the elapsed time, and the resulting size.

On native platforms it uses the path-based `decode()` API and writes the
`.wav` to a temporary directory. On the web it uses `decodeBytes()` (the
decode runs as WASM in a Web Worker) and offers Play and Download buttons
for the in-memory result.

## Run

```sh
flutter run             # on a connected device or emulator
flutter run -d macos    # or -d linux / -d windows for desktop
flutter run -d chrome   # web
```

Press "Decode sample" to decode the bundled asset, or "Pick .wv file" to
choose your own WavPack file.
