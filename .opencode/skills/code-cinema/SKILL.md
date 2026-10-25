---
name: code-cinema
description: Build and revise Code Cinema short films with the Godot + Python pipeline across 9:16, 1:1, 16:9, and draft formats. Use for screenplays, voiceover, SFX, centralized audio, scene/prop changes, previews, final MP4s, open-source asset downloads, or when the user mentions "3rd Person Voice Reel", "voice reel", "SAVE HER", or asks for a cinematic short.
---

# Code Cinema

## Named format: 3rd Person Voice Reel

Label every film in this style exactly **3rd Person Voice Reel**.

Definition: a vertical, first-person-POV visual short with continuous third-person omniscient narration (indirect speech). Diegetic broadcasts, ads, and emergency announcements stay direct speech. The narrator carries the story wall-to-wall while the camera shows the protagonist's point of view.

## Output formats

Use the central registry at `styles/formats.json`. Do not hard-code output sizes.

| Key | Label | Native output | Status |
|---|---|---:|---|
| `vertical` | 9:16 Vertical Short | 1080x1920 | Full render |
| `square` | 1:1 Cinematic | 1080x1080 | Full render |
| `landscape` | 16:9 Cinematic | 1920x1080 | Full render |
| `draft` | Draft | 540x960 | Reserved, not renderable yet |

Pass one format to `make`, `render`, `mux`, or `poster`:

```powershell
python $CC make save_her --project D:\code-cinema\studio --format vertical
python $CC make save_her --project D:\code-cinema\studio --format square
python $CC make save_her --project D:\code-cinema\studio --format landscape
```

Output naming:

- `out\<slug>_<format>.mp4`
- `out\<slug>_<format>_preview.mp4`
- `out\<slug>_<format>_poster.jpg`

Rendering is native to the selected format. The pipeline temporarily sets the Godot
window override to the render size, then restores `project.godot` automatically.

## Non-negotiable user defaults

- **Format:** 1080x1920, 30 fps, H.264 + AAC stereo. Fast preview is 540x960/15 fps; remux the latest preview to the final 1080x1920 file.
- **Narration:** continuous third-person indirect speech. Use he/she/they after the opening hook, not "you". Keep narration running across the timeline; avoid long silent gaps.
- **Opening hook:** may be direct, e.g. "What if a zombie apocalypse started right now?"
- **Direct speech:** only for in-world TV/radio/ads/emergency announcements. Do not use the narrator for these.
- **Voice:** native English, neutral US/UK, cinematic and omniscient. Never use Indian-accented TTS for narration. Do not use Sarvam `en-IN` voices such as `ishita`, `ratan`, `shubh`, `tanya`, or `varun`. Prefer Edge TTS neural voices such as `en-US-GuyNeural`, `en-US-AriaNeural`, `en-GB-RyanNeural`, or similar.
- **Child crying:** use a real crying/sobbing SFX layer (child/female), with breath and whimpers. Never use an adult TTS line as a substitute for crying.
- **Mix:** voice-forward. Dialogue must sit clearly above music and SFX. Verify the final MP4, not just the WAV.
- **No static shots:** every shot needs camera motion, actor motion, prop action, particles, or first-person hand action.
- **Public scenes:** add pedestrians/crowds, traffic, and lived-in detail. Never leave a street empty.
- **Mart/interior:** stock multiple shelf rows, products, and signage. Avoid empty rooms.
- **Apartment:** add first-person hand/prop action, e.g. a coffee mug sip, when the shot would otherwise be static.
- **Transitions:** use dip-to-black or crossfade for location changes (apartment to walk, walk to mart). Do not hard-cut into a new location unless it is intentional.
- **POV:** first-person camera. Do not show the protagonist's full body. Hands and props in frame are allowed and encouraged.
- **No textual opening card** unless requested.
- **Final delivery:** remux the latest preview with the latest mix. Never ship a stale MP4.

## Story flow template

1. Hook: direct question.
2. Third-person setup: protagonist at home, routine, coffee.
3. Third-person walk: rainy morning, people around.
4. Diegetic ad + emergency alert: direct speech.
5. Third-person panic: runs to a nearby mart, takes shelter.
6. Third-person discovery: hears a girl crying; real crying SFX.
7. Cliffhanger/question.

Write narration to cover this flow continuously, not as sparse one-liners.

## Workflow

1. Read `films/<slug>/screenplay.json` and the active kit.
2. Keep the named style and the user defaults above.
3. Validate the screenplay.
4. Generate native-English TTS; never reuse the old `en-IN` cache for narration.
5. Resolve the timeline.
6. Render a fast preview and inspect key frames.
7. Fix static shots, empty environments, missing fades, and audio problems.
8. Mix voice-forward audio, remux the latest preview, and verify the final MP4.

## Pipeline commands

Set the CLI path once:

```powershell
$CC = "D:\code-cinema\.opencode\skills\code-cinema\scripts\codecinema.py"
```

Core commands:

```powershell
python $CC validate save_her --project D:\code-cinema\studio
python $CC tts save_her --project D:\code-cinema\studio
python $CC resolve save_her --project D:\code-cinema\studio
python $CC render save_her --project D:\code-cinema\studio --format vertical --dry-run
python $CC make save_her --project D:\code-cinema\studio --format square --fast
```

## Central audio farm

Audio setup is centralized in:

- `D:\code-cinema\studio\code_cinema\audio_manifest.json`
- `D:\code-cinema\studio\code_cinema\voices.json`
- `D:\code-cinema\.opencode\skills\code-cinema\scripts\cc_sfx.py`

Generate/validate SFX:

```powershell
python D:\code-cinema\.opencode\skills\code-cinema\scripts\cc_sfx.py --project D:\code-cinema\studio
```

The manifest defines SFX categories, gains, generators, and mix profiles. The default
mix profile is `clean`. `voice_forward_retro` is optional and applies retro voice
processing only when explicitly requested; it never applies retro to crying/SFX by default.

Use a real child-crying SFX, e.g. `girl_cry.sobbing`. Do not use TTS for crying.

## Open-source asset downloads

The PDF is at:

`D:\code-cinema\studio\out\OpenSource_3D_Asset_Directory_2026.pdf`

The catalog created from it is at:

`D:\code-cinema\.opencode\skills\code-cinema\assets\pdf_asset_directory_2026.json`

Download supported direct pack archives:

```powershell
python D:\code-cinema\.opencode\skills\code-cinema\scripts\fetch_asset_directory.py --dest D:\code-cinema\studio\open_assets\pdf_2026
```

Download one pack:

```powershell
python D:\code-cinema\.opencode\skills\code-cinema\scripts\fetch_asset_directory.py --dest D:\code-cinema\studio\open_assets\pdf_2026 --only E1
```

The target directory contains per-pack archives, `LICENSE.txt`, `PAGE.html`,
`manifest.json`, and `CREDITS.md`. Failed packs are recorded with reasons instead of
silently skipped. Google Drive/itch sources that require browser sessions are recorded
as failed/manual until their download flow is automated.

## Verification checklist

- `python -m py_compile scripts\*.py` passes.
- `validate` reports no screenplay errors and no forbidden `en-IN` narration voices.
- `cc_sfx.py` reports no missing audio and the child crying files exist.
- `ffprobe` reports one H.264 video stream and one AAC stereo audio stream.
- Selected format dimensions match the format registry exactly.
- The final MP4 has audible voice at the opening line and all dialogue cues.
- SFX are present, especially rain, footsteps, alerts, zombie growls, and crying.
- The voice is not masked by music or SFX.
- The child crying uses `girl_cry.sobbing`, not TTS or the old overdriven cry.
- The current film has `audio.mix_profile: clean` unless retro was explicitly requested.
- No shot is visually static.
- Streets have people; the mart has stocked shelves.
- Location changes use fades.
- The final MP4 was built from the latest render and latest mix.
- `open_assets\pdf_2026\manifest.json` records every attempted PDF pack.

## Key files

- `D:\code-cinema\studio\films\<slug>\screenplay.json` — shots, dialogue, SFX, camera, actors.
- `D:\code-cinema\studio\code_cinema\kit.json` — characters, props, SFX, music, voices, anchors.
- `D:\code-cinema\studio\code_cinema\episode_player.gd` — runtime camera, actors, animations, fades, POV.
- `D:\code-cinema\studio\code_cinema\tools\author_save_her_v2.gd` — SAVE HER set generator.
- `D:\code-cinema\studio\code_cinema\build\<slug>\` — resolved timeline, preview AVI, voice cache, mix WAV.
- `D:\code-cinema\studio\out\<slug>_<format>.mp4` — final delivery.
- `D:\code-cinema\.opencode\skills\code-cinema\styles\formats.json` — output format registry.
- `D:\code-cinema\studio\code_cinema\audio_manifest.json` — central SFX/mix setup.
- `D:\code-cinema\studio\code_cinema\voices.json` — central voice setup.
- `D:\code-cinema\.opencode\skills\code-cinema\assets\pdf_asset_directory_2026.json` — PDF asset catalog.
- `D:\code-cinema\studio\open_assets\pdf_2026\manifest.json` — asset download status and credits source.

## Detailed style guide

Read `reference/third-person-voice-reel.md` for the full narration, shot, audio, and transition rules. The machine-readable label is `styles/third_person_voice_reel.json` with label `3rd Person Voice Reel`.
