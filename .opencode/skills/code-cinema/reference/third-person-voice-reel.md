# 3rd Person Voice Reel

This is the user's named format for Code Cinema videos.

## Definition

A **3rd Person Voice Reel** is a vertical cinematic short with:

- first-person POV visuals,
- continuous third-person omniscient narration in indirect speech,
- direct speech only for in-world broadcasts, ads, and emergency announcements,
- a voice-forward soundtrack,
- no static or empty shots.

The narrator is a storyteller, not the protagonist. The camera is the protagonist.

## Narration rules

- After the opening hook, use third person: he, she, they, the man, the girl.
- Do not write the body of the film as "you".
- Keep the narration continuous. Aim for a line every 2-4 seconds, with deliberate short pauses only for tension.
- Use indirect speech for action: "He steps outside. The rain is already waiting."
- Use direct speech only for diegetic audio: TV anchor, radio ad, emergency alert.
- Do not use the narrator to perform child crying, screams, or crowd chatter.
- The opening hook may be direct: "What if a zombie apocalypse started right now?"
- The closing line should be a question or a sharp cliffhanger.

## Voice rules

- Native English, neutral US or UK.
- Cinematic, calm, omniscient; not conversational and not accented.
- Preferred providers/voices: Edge TTS `en-US-GuyNeural`, `en-US-AriaNeural`, `en-GB-RyanNeural`, or equivalent neural voices.
- Never use Sarvam `en-IN` voices for narration: `ishita`, `ratan`, `shubh`, `tanya`, `varun`.
- Direct-speech broadcast voices may be separate, but they must still sound native English.

## Audio rules

- Voice-forward mix: dialogue clearly above music and SFX.
- Verify the final MP4, not only the WAV.
- Use real SFX for:
  - rain and wet footsteps,
  - city ambience and crowds,
  - alerts, sirens, phones, TVs,
  - zombie growls,
  - a child crying, sobbing, and breathing.
- Child crying must be an actual crying/sobbing SFX layer. Do not use adult TTS for crying.
- Do not let music or rain mask dialogue.

## Visual rules

- Every shot must have motion: camera move, actor motion, prop action, particles, or first-person hand action.
- Apartment: add a first-person hand and coffee mug; animate a sip if the shot is otherwise static.
- Street: add pedestrians, umbrellas, traffic, and small background motion. The street should feel populated.
- Mart: add multiple shelf rows, products, signs, and aisle depth. It should feel stocked, not empty.
- Use fades/dips to black at location changes:
  - apartment to morning walk,
  - walk to mart,
  - mart to reveal.
- Keep the camera first-person. Do not show the protagonist's full body.
- Hands, coffee cups, phones, and other POV props are allowed and encouraged.

## Story flow template

1. Direct hook.
2. Third-person apartment routine; coffee sip; rain outside.
3. Third-person morning walk; wet street; people around.
4. Diegetic ad, then emergency alert (direct speech).
5. Third-person panic; run to a nearby mart; shelter.
6. Third-person discovery; a girl crying.
7. Cliffhanger question.

## Output formats

Use `styles/formats.json` for all output sizes.

- `vertical`: 1080x1920
- `square`: 1080x1080
- `landscape`: 1920x1080
- `draft`: reserved placeholder; do not render yet

Choose a format with `--format vertical|square|landscape|draft`. The format registry is
the source of truth; do not hard-code output dimensions in screenplays or scripts.

## Central audio farm

Audio is centralized through `code_cinema/audio_manifest.json` and
`code_cinema/voices.json`.

- Default mix profile: `clean`
- Optional mix profile: `voice_forward_retro`
- Retro profile is explicit only
- Child crying must use the generated `girl_cry.sobbing` SFX
- No adult TTS line may replace child crying
- SFX gains are defined per category in the audio manifest

## Open-source asset downloads

The 2026 PDF pack directory is cataloged in
`assets/pdf_asset_directory_2026.json` and downloaded by
`scripts/fetch_asset_directory.py`.

- Kenney, OpenGameArt, Blender Studio, and many direct archive links download automatically.
- Google Drive/itch downloads that require browser sessions are recorded as failed/manual.
- Keep every pack's `LICENSE.txt`, source page, and attribution in `CREDITS.md`.
- Respect Quaternius site terms and Blender Studio CC-BY credits.

## Shot checklist

- Is the narration third person after the hook?
- Is narration continuous across the timeline?
- Is the broadcast/direct speech clearly diegetic?
- Does every shot have motion?
- Are there people in the walking scenes?
- Does the mart have stocked shelves?
- Is there a fade at each location change?
- Is the voice native English and free of Indian accent?
- Is there real crying SFX for the girl?
- Is the final MP4 remuxed from the latest preview and mix?
