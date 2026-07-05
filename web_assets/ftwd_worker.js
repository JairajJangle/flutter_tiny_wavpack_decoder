// Web Worker hosting the WASM build of the WavPack tiny decoder.
//
// Spawned by WasmDecodeRunner (lib/src/wasm_decode_runner.dart), which sends
// one message per decode:
//   { id, glueUrl, wasmUrl, input: ArrayBuffer, maxSamples, bitsPerSample }
// and receives, per decode, zero or more
//   { id, type: 'progress', value }
// followed by exactly one
//   { id, type: 'result', success, error, output?: ArrayBuffer }.
//
// The runner serializes decodes (the C decoder keeps static state), so this
// worker never sees overlapping requests. The WASM module is instantiated
// once on the first request and reused.
'use strict';

var modulePromise = null;

function ensureModule(glueUrl, wasmUrl) {
  if (!modulePromise) {
    importScripts(glueUrl);
    modulePromise = createFtwdModule({
      locateFile: function () { return wasmUrl; }
    });
  }
  return modulePromise;
}

self.onmessage = function (event) {
  var msg = event.data;
  var id = msg.id;
  ensureModule(msg.glueUrl, msg.wasmUrl).then(function (Module) {
    var inPtr = 0, outPtrPtr = 0, outLenPtr = 0, errPtr = 0, cbPtr = 0;
    try {
      var input = new Uint8Array(msg.input);
      inPtr = Module._malloc(input.length);
      Module.HEAPU8.set(input, inPtr);
      outPtrPtr = Module._malloc(4);
      outLenPtr = Module._malloc(4);
      errPtr = Module._malloc(80);
      cbPtr = Module.addFunction(function (progress, _context) {
        self.postMessage({ id: id, type: 'progress', value: progress });
      }, 'vfi');

      var status = Module._ftwd_decode_buffer(
        inPtr, input.length, msg.maxSamples, msg.bitsPerSample,
        cbPtr, 0, outPtrPtr, outLenPtr, errPtr);

      if (status === 1) {
        var outPtr = Module.getValue(outPtrPtr, 'i32');
        var outLen = Module.getValue(outLenPtr, 'i32');
        // slice() copies out of the WASM heap so the buffer stays valid
        // (and transferable) after ftwd_free_buffer.
        var wav = Module.HEAPU8.slice(outPtr, outPtr + outLen);
        Module._ftwd_free_buffer(outPtr);
        self.postMessage(
          { id: id, type: 'result', success: true, error: '', output: wav.buffer },
          [wav.buffer]);
      } else {
        self.postMessage({
          id: id, type: 'result', success: false,
          error: Module.UTF8ToString(errPtr, 80)
        });
      }
    } catch (e) {
      self.postMessage({ id: id, type: 'result', success: false, error: String(e) });
    } finally {
      if (cbPtr) Module.removeFunction(cbPtr);
      if (inPtr) Module._free(inPtr);
      if (outPtrPtr) Module._free(outPtrPtr);
      if (outLenPtr) Module._free(outLenPtr);
      if (errPtr) Module._free(errPtr);
    }
  }).catch(function (e) {
    self.postMessage({
      id: id, type: 'result', success: false,
      error: 'WASM decoder failed to load: ' + String(e)
    });
  });
};
