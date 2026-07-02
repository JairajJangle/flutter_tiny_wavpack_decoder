#!/usr/bin/env bash
# Regenerates all audio fixtures under test/fixtures/ (they are committed;
# this script exists for provenance and regeneration). Requires ffmpeg with
# the native WavPack encoder.
set -euo pipefail
cd "$(dirname "$0")/.."

REF=test/fixtures/reference/sine_stereo_16bit_44100.wav
WV=test/fixtures/sine_stereo_16bit_44100.wv

dart run tool/generate_fixture_wav.dart "$REF"

# ffmpeg's native WavPack encoder, default (lossless) mode.
ffmpeg -hide_banner -loglevel error -y -i "$REF" -c:a wavpack "$WV"

# Error-path fixtures.
head -c 4096 "$WV" > test/fixtures/truncated.wv
printf 'This is definitely not a WavPack bitstream.' > test/fixtures/not_wavpack.wv
dart run tool/corrupt_fixture.dart "$WV" test/fixtures/corrupt_crc.wv

# Gate 1: the tiny decoder only accepts stream versions 0x402..0x410.
dart run tool/check_wv_version.dart "$WV"

# Gate 2: the real C decoder must reproduce the reference WAV byte-exactly
# (requires tool/build_host_lib.sh to have been run).
dart run tool/verify_fixture_roundtrip.dart

# The example app bundles the same sample.
mkdir -p example/assets
cp "$WV" example/assets/

ls -la test/fixtures test/fixtures/reference
