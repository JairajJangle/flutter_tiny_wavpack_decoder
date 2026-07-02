# flutter_tiny_wavpack_decoder example

A minimal Flutter app that decodes a bundled WavPack sample
(`assets/sine_stereo_16bit_44100.wv`) to a PCM `.wav` file and shows live
decode progress, the elapsed time, and the resulting file size.

## Run

```sh
flutter run            # on a connected device or emulator
flutter run -d macos   # or -d linux / -d windows for desktop
```

Press "Decode sample" to run the decode. The bundled asset is copied to a
temporary directory, decoded through the plugin, and the output path and size
are displayed on success.
