# Unicorn Cloud Cat (toy style) — Roblox import

Files
- `daughter_cat_parts.glb` — separate meshes: Cat, Eyes, Mane, Tail, Cloud, Rainbow, Heart1–Heart6 (each < 20k tris). **Use this one.**
- `daughter_cat_combined.glb` — single static smooth mesh, 19,500 tris (no animation).
- Rebuild: `python3 build.py` (shapes → src_parts.glb) then `~/blender-4.2.3-linux-x64/blender -b -P blender_build.py` (voxel remesh, smoothing, color transfer, smooth normals, export, Cycles preview).
- `UnicornCloudCat.rbxmx` — Model containing the `Animator` Script.
- `UnicornCloudCatAnimator.server.lua` — same script as plain text.

Steps in Roblox Studio
1. **Import 3D** (Home or Avatar tab) > choose `daughter_cat_parts.glb`. Turn **off** "Import as single mesh", keep vertex colors on, scale ~3x, Import. A Model with MeshParts appears.
2. Check part names in Explorer: Cat, Eyes, Mane, Tail, Cloud, Rainbow, Heart1…Heart6 (remove any importer suffixes).
3. Right-click Workspace > **Insert from File…** > `UnicornCloudCat.rbxmx`. Drag `Animator` into your imported Model; delete the empty UnicornCloudCat model.
4. Model > Properties > **PrimaryPart = Cloud**. Position it before Play (script records start poses).
5. Optional: set heart Material to Glass/SmoothPlastic + Reflectance 0.2 for gloss; Cloud material SmoothPlastic.
6. Play: cloud+cat bob (eased sine), cat tilts and breathes, mane sways, tail swishes, hearts float/spin/pulse out of phase, rainbow shimmers, sparkles drift off the cloud.

Client-side option (smoothest, zero server cost): move the Model under Workspace as usual, convert `Animator` to a LocalScript placed in StarterPlayerScripts and change `local model = script.Parent` to `local model = workspace:WaitForChild("UnicornCloudCat")` (your Model name). Toggle sparkles with `SPARKLES` at the top.

## Effects (toggle in CONFIG at top of the script)
- GLOW_LIGHTS: lavender PointLight in the cloud, gold PointLight at the horn tip.
- NEON_HEARTS: hearts switch to Neon (glow). HEART_PARTICLES: little sparkles drift up from each heart.
- CLOUD_SPARKLES / HORN_TWINKLE: pastel sparkles off the cloud, twinkle on the horn tip.
- RAINBOW_BEAM: curved shimmering Beam over the rainbow (flip CurveSize0/1 signs if it bends the wrong way).
- HAPPY_MOMENT: every HAPPY_INTERVAL (8s) the cat hops, tail swishes faster, heart burst.
- PET_PROMPT: "Pet" ProximityPrompt on the cat → heart burst + purr.
- Purr sound: set PURR_SOUND_ID to a Creator Store audio id (e.g. "rbxassetid://...") — empty means silent.
- Heart particles use Roblox's built-in sparkle texture; for true heart shapes, upload/pick a heart decal and set HEART_TEXTURE.
- Mobile: LOW_QUALITY_MOBILE halves particle rates on touch devices when run as a LocalScript.
- Everything the script creates is destroyed and all connections disconnected when the Model or Script is removed.
- Neon tip: Neon ignores vertex colors' shading; if hearts look too flat/bright, set NEON_HEARTS=false.
- EYE_GLOW: the `Eyes` part becomes Neon pink with a soft pink PointLight; glow gently pulses and moves with the cat (incl. hops). Sparkle highlights stay white on the Cat part.
