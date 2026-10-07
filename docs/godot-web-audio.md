# Godot web audio: lessons learned

These notes come from shipping music in PRs please's single-threaded web export, built with Godot 4.7.2 and the Compatibility renderer. Use them as a checklist for any Godot project that ships to the browser.

## TL;DR

- **Play music as a stream on the web:** set `player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM`. Godot's web default is Web Audio *samples*. In a real user's Chrome they started, ran and ramped volume correctly, yet came out silent. Streams played fine on the same machine.
- **"Tests pass" and "the track started" do not mean anyone can hear it.** Check that sound actually reaches the output in a real browser. Better still, have a human listen on their own machine.
- **Automated Chrome is not a real user's Chrome.** DevTools-driven Chrome lets audio play without a click, so autoplay bugs and some audio-path bugs never show up there.
- **Leave yourself a way in.** A one-line console report and a URL switch between playback paths found the bug in two messages; guessing had failed for hours.

## Samples vs. streams on the web

Godot 4.3+ web exports default to `PLAYBACK_TYPE_SAMPLE`. The engine decodes the stream into an `AudioBuffer` and plays it with native Web Audio nodes (`AudioBufferSourceNode`, then a channel splitter, per-channel gains, a merger, then bus gain nodes, then the destination).

| | Samples (web default) | Streams |
| --- | --- | --- |
| Where it runs | Native Web Audio nodes | Godot's mixer in an `AudioWorklet` |
| Bus effects (low-pass, reverb) | **Ignored**; only bus volume, mute and solo apply | Work as on desktop |
| `loop_offset` on Ogg/WAV | **Ignored**: a loop restarts from wherever `play()` began | Honoured |
| Silent-output failure seen in the wild | **Yes**, in the user's normal Chrome on macOS | No |
| CPU / glitch risk | Low | The single-threaded build mixes on the main thread, so it may crackle when the page is busy |

What to do:
- Use streams for music. Samples are fine for short SFX, but test them by ear.
- Keep a URL switch (`?music=sample`) so you can compare the two paths on a user's machine without a rebuild. Read it with `JavaScriptBridge.eval("location.search", true)`.
- With samples, you have to drive loop points yourself: play a non-looping pass, then on `finished` restart at the loop offset. With streams this workaround isn't needed.

## Autoplay and the first gesture

- Browsers keep the `AudioContext` suspended until a user gesture (click or keypress). Godot resumes it itself (`_godot_audio_resume`) on the first input event, so you don't need custom JS for that.
- Gate *starting* music on the first input in `_input`, and show a subtle "click anywhere for sound" hint until it arrives.
- A gesture that lands while the engine is still loading activates the page but never reaches Godot. The hint must stay up until Godot itself sees an input.
- Give the menu a visible music on/off control. `user://` is backed by IndexedDB on the web, so a saved "music off" survives reloads. With the toggle buried in an in-game settings screen, it looks exactly like a bug.

## Debugging recipe: what helped and what misled

1. **Instrument from page start.** Use the Chrome DevTools MCP `navigate_page` with an `initScript` to patch `AudioBufferSourceNode.prototype.start/stop`, `AudioParam.value`, and `AudioNode.prototype.connect`. That logs every source start (with offset and buffer duration), every gain change and every graph edge.
2. **Measure levels node by node, at measurement time.** Godot rewires its bus graph with `disconnect()`, which silently drops any analyser you attached when the graph was built. Connect an `AnalyserNode` to the node you care about just before reading, then disconnect it. A meter attached early read 0 and sent me chasing a bus-routing theory that was wrong.
3. **Validate the meter.** Play a known oscillator into `ctx.destination` and confirm the meter reads non-zero before trusting a zero.
4. **Check the buffer itself.** Inside the patched `start()`, compute the RMS of `this.buffer.getChannelData(0)`. That separates a decode problem (silent buffer) from a routing problem.
5. **Simulate autoplay.** In the `initScript`, wrap `AudioContext` so it starts suspended (`ctx.suspend()`) and log who calls `resume()`. Automated Chrome otherwise starts it `running`.
6. **Ship a console report.** `web/shell.html` defines `prsAudioReport()`, which prints each context's state, sample rate, `sinkId`, and the live output level of every node feeding the destination. Ask the user to run `await prsAudioReport()` and paste the result.
7. **A/B by URL.** `?music=stream` vs. `?music=sample` isolated the cause in one message from the user.

## Other gotchas

- **Loop seams.** Godot clicked at the loop point when the loop end sat exactly at the end of the data. Padding a few samples (64) of the loop's start after the loop end fixed it. Check by recording Godot's own playback, not only by inspecting the file.
- **Several players in lockstep.** Start them all in the same frame while the mixer is locked (`AudioServer.lock()` / `unlock()`). `AudioStreamSynchronized` can't play as a web sample.
- **Loudness.** Master every track to one target (about −16 LUFS) and apply a single in-game gain. Suno and other generated tracks arrive at very different levels.
- **Size.** Ogg Vorbis at about 110–150 kbps stereo keeps a soundtrack of a few minutes per scene around 10 MB. ffmpeg's built-in Vorbis encoder is "experimental"; it's fine below 8 kHz but softer above. `oggenc` or libvorbis is better if you have it. Commit only the encoded files, never the WAV masters.
- **Headless tests.** The dummy audio driver plays nothing, so tests can assert player state and gains but never sound. Gate real playback in tests behind an explicit flag (`Music.play_headless`) to avoid leak warnings in other suites.
- **Pause ducking.** With samples on the web, a bus low-pass does nothing, so ducking has to be volume only. With streams it works as on desktop.

## Files in this repo

- `native/music.gd`: scene-to-track table, crossfades, ducking, first-gesture start, and the web stream/sample switch.
- `web/shell.html`: the `prsAudioReport()` console diagnostic.
- `tools/music/prepare_tracks.py`: cuts, loudness-matches and encodes the masters into `audio/music/*.ogg`.
- `tests/test_music.gd`: scene mapping, toggles, loop restarts and the menu toggle (logic only; see Headless tests above).
