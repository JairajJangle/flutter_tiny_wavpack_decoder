# flutter_tiny_wavpack_decoder example

A minimal Flutter app that decodes either a bundled WavPack sample
(`assets/sine_stereo_16bit_44100.wv`) or a `.wv` file you pick from disk to a
PCM `.wav` file, and shows live decode progress, the elapsed time, and the
resulting file size.

## Run

```sh
flutter run            # on a connected device or emulator
flutter run -d macos   # or -d linux / -d windows for desktop
```

Press "Decode sample" to decode the bundled asset, or "Pick .wv file" to choose
your own WavPack file. The input is decoded through the plugin to a temporary
directory, and the output path and size are displayed on success.
