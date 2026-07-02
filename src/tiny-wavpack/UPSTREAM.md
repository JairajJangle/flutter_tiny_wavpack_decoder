# Vendored WavPack "tiny decoder" sources — DO NOT EDIT

Everything under this directory is a **byte-identical** copy of
`src/tiny-wavpack/` from the
[react-native-tiny-wavpack-decoder](https://github.com/JairajJangle/react-native-tiny-wavpack-decoder)
repository (copied at commit `09dd296`, 2026-07-02).

- `lib/` — the original WavPack 4.40 "tiny decoder" by David Bryant,
  Copyright (c) 1998–2006 Conifer Software, BSD license (see `lib/license.txt`).
- `common/` — the portable C glue (`decode_wavpack_to_wav`) added by the
  react-native-tiny-wavpack-decoder project.

Do not modify any file here. Anything the Flutter plugin needs beyond this
API lives in `../ftwd_shim.{h,c}`, which only *calls* these sources.

SHA-256 checksums at vendoring time:

```
7e34a79f2650c5a6ab09b1cb1d7bb056af1e5656d385bd7a8cab59f300a653b1  common/TinyWavPackDecoderInterface.c
fdc8fb1a1d5e004664b402b7a09a15ce654dda805b86899f1a916b7b443b9d8b  common/TinyWavPackDecoderInterface.h
00ff76dceebe343ec7b4a3f9dee0e952d5a271c1cd34acd7947709e68520a43d  lib/bits.c
fbecbbf78770a224729ddce5014c039c45457c5df10fceca0d059376a045a41d  lib/float.c
87fc453ae8c28e10be07fbcc064237ad4594d3959a7ee002bad5cf3a3e699375  lib/license.txt
08a1b3e1873ff0ad3ff7c732d4d98979115045a0f48f4396cb387131e6e7a8a3  lib/metadata.c
cad79008323f07ff6875deb35a5b3dfa0d2d726e9caca0baddebef449f35eb0e  lib/readme.txt
550637673839eb8b23bb5cc8340b7c44102af42ab027937cab726e82a38e6bb1  lib/unpack.c
e4e944fd0d2af87abecc9bb742d42a36dab25287c1c82ed61555c18b186d6b97  lib/wavpack.h
e7dd57a47017c45992b092daf5575e960df16a2fd562735a4e304ce16a8c20a4  lib/words.c
f327f034033e16fa4c28e1fbb8a0c78efb9e6aaad47d2a277a615216e9bb8a1b  lib/wputils.c
```

Verify with: `cd src/tiny-wavpack && shasum -a 256 -c <(grep -E '^[0-9a-f]{64}' UPSTREAM.md)`
