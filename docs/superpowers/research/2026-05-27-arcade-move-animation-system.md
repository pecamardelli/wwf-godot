# Arcade Research: Move / Animation System & Doink Moveset

Source: `historicalsource/wwf-wrestlemania` (TMS34010 asm, Jamie Rivett). Read-only.
Captured 2026-05-27. Doink is internally `dnk` / wrestler #6.

## 1. Animation / "puppet" system

Two anim channels per wrestler: `ANIMODE` (primary: legs/body) + `ANIMODE2` (secondary: torso),
stepped each frame by `animate_wrestler` (`ANIM.ASM:68-89`). Channel block (`ANIM.ASM:61-65`):
`OANIMODE` (mode bits), `OANIBASE` (seq start), `OANIPC` (program counter), `OANICNT` (ticks left on
frame), `OCUR_FRAME` (current image).

**Sequence data format** (engine walks it, `ANIM.ASM:115-194`):
- high bit set → **command** (`n + 8000h`, dispatched via `#ani_commands`, `ANIM.ASM:214-350`)
- zero → `ANI_ZIP` no-op
- positive word `N` → a **frame**: `N` = base tick duration, followed by `.long` image ptr (the `WL n,img`
  macro, `MACROS.H:296`). Displayed duration scaled by `ANI_SPEED` (100h = 1.0×) and `hyper_speed`.

**Hitbox window (two-stage):**
- `ANI_STARTATTACK type,#ticks` (`ANIM.ASM:4271`) — declares attack, sets `ATTACK_TYPE` + startup window.
- **`ANI_ATTACK_ON mode,x,y,w,h`** (`ANIM.ASM:438`) — **hit goes live**: sets `MODE_CHECKHIT`, stores
  `ATTACK_MODE` (an `AMODE_*`), writes attack-box offsets (Z width default 10).
- `ANI_ATTACK_OFF` (`ANIM.ASM:488`) — hit dead.
- So **active frames = between ON and OFF**; startup = before ON; recovery = after OFF to `ANI_END`.
- `ANI_WAITHITOPP` holds a frame until the attack connects (throws/buzz).

Example — Doink #2 punch (`DNKSEQ2.ASM:93-132`): SETMODE UNINT|NOAUTOFLIP → windup frames →
`ANI_STARTATTACK AT_PUNCH,5` → `ANI_ATTACK_ON AMODE_PUNCH,22,86,55,9` → 2 active frames →
`ANI_ATTACK_OFF` → `ANI_SLIDE_BACK` recoil if missed → recovery → `ANI_END`.

ANIMODE bits (`ANIM.EQU:186-234`): `MODE_UNINT` (uninterruptable, gates new input), `MODE_CHECKHIT`
(attack live), `MODE_KEEPATTACHED` (hold opponent—throws), `MODE_NOGRAVITY`, `MODE_GHOST`, `MODE_WAITHITOPP`.

## 2. Input → move mapping

**5 buttons** (`GAME.EQU:407-428`): `PUNCH`(b0), `BLOCK`(b1), `SPUNCH` super-punch(b2), `KICK`(b3),
`SKICK` super-kick(b4). Cabinet = 3 buttons + Turbo; super variants = hold Turbo (`BUT_VAL_DOWN & 01111b`).
Snapshots: `BUT_VAL_CUR/_DOWN/_UP`, `STICK_VAL_CUR/_DOWN/_UP` (`PLYR.EQU:212-218`).

**8-way joystick** bitfield (`GAME.EQU:355-388`): `MOVE_UP=1,DOWN=2,LEFT=4,RIGHT=8` (diagonals OR'd).
Relative: `J_TOWARD=RIGHT`, `J_AWAY=LEFT`, etc.

**Normal move selection:** `move_doink` (`DOINK.ASM:1654`) → `check_secret_moves` first, then dispatch on
`PLYRMODE` (0–25) via `#mode_table`. In `mode_normal`: if `MODE_UNINT` → ignore; else `BUT_VAL_DOWN & 01111b`
indexes `#action_table` (`DOINK.ASM:1845`). Each handler uses the **JJXM macro** (range dispatch): picks
close (`LESS`) vs far (`MORE`) move by opponent `CLOSEST_XDIST`/`ZDIST` within `DX×DZ`. So the *same button*
gives different moves by PLYRMODE + range. `FACE24` then picks the `_2_` (face up/right) or `_4_`
(face down/right) anim variant.

**Special/"secret" moves — two mechanisms:**
- (A) **Motion buffer** `check_secret_moves` (`WRESTLE.ASM:4851`): 16-entry rolling input-history buffer
  `wrest_joystat` (each entry `tick<<16 | (joy|button)`), filled per stick-change/button-down. Each move =
  list of `{value,mask}` pairs terminated by `8000h|maxframes`; matches newest entry, scans back; whole
  motion within `maxframes` ticks → trigger. Doink motion moves (`DOINK.ASM:328-619`): boxing glove
  (PUNCH×7/60), hammer (SKICK,toward,toward/32), ear slap (PUNCH,toward,down-toward,down/50), neck grab
  (SPUNCH,toward,toward/32), grab-fling (SPUNCH,away,away/32), hip toss (PUNCH,away,away/32), joybuzzer
  (hold PUNCH≥100 then release).
- (B) **Background "smove" processes** (`dnk_smove_table`, `DOINK.ASM:239`): loop on input sequences, write
  a follow-up sequence into `SPECIAL_MOVE_ADDR` — used for held-opponent follow-ups, charged flying kick,
  run, taunt, finishers.

## 3. Doink moveset

"anim" = base label (`_2_`/`_4_` by facing). Damage from `DAMAGE.EQU`. STD = shared standard-sequence move.

| Move | Input | KD/Dizzy/Grab | Dmg | Cite |
|---|---|---|---|---|
| Punch (STD) | PUNCH, far >50×45 | — | 8 | DOINK.ASM:1882, DNKSEQ2:93 |
| Head butt (STD) | PUNCH, close ≤50×45 | — | 12 | DOINK.ASM:1921 |
| Elbow drop (STD) | PUNCH vs grounded ≤160×140 | hits grounded | 17 | DOINK.ASM:1931 |
| Kick (STD) | KICK, far >50×92 | — | 13 | DOINK.ASM:2169 |
| Knee (STD) | KICK, close ≤50×92 | — | 12 | DOINK.ASM:2180 |
| Stomp (STD) | KICK vs grounded | hits grounded | 8 | DOINK.ASM:2190 |
| Run | PUNCH+KICK | enables flying moves | 0 | DOINK.ASM:1811 |
| Backhand slap | SPUNCH, far >85×55 | Doink-specific | 19 | DOINK.ASM:2012 |
| Head butts / Uppercut | SPUNCH close; stick down=butts, up=uppercut | — | 9/20 | DOINK.ASM:2021 |
| Hair pickup | SPUNCH near opp head | **grab** | — | DOINK.ASM:2101 |
| Spin kick | SKICK, far >60×60 | jumping | 17 | DOINK.ASM:2265 |
| Close super-kick/knee-fall | SKICK close; toward→knee | — | — | DOINK.ASM:2275 |
| Big boot | SKICK while RUNNING | KD | 18 | DOINK.ASM:2310 |
| Super stomp | SKICK vs grounded | grounded | — | DOINK.ASM:2300 |
| TB spin kick | SKICK in air/off turnbuckle | aerial | — | DOINK.ASM:2255 |
| Flying kick | hold SKICK≥100 release | charged | — | DOINK.ASM:1346 |
| Flying clothesline | PUNCH while running | aerial | 20 | DOINK.ASM:164 |
| **Hip toss** | PUNCH+away,away or vs running | **throw, KD** | 27 | DOINK.ASM:572, DNKSEQ2:4228 |
| **Grab & fling** | SPUNCH+away,away | **throw, KD** | — | DOINK.ASM:504, DNKSEQ2:3828 |
| Hip toss 2 | PUNCH+away vs airborne | **throw** | — | DOINK.ASM:477 |
| **Boxing glove** | PUNCH×7 rapid | signature | 20 | DOINK.ASM:330, DNKSEQ2:182 |
| Hammer | SKICK+toward,toward | — | 12 | DOINK.ASM:365, DNKSEQ2:2933 |
| Ear slap | PUNCH+toward,down-toward,down | — | 20 | DOINK.ASM:391 |
| **Neck/head grab** | SPUNCH+toward,toward | **grab** (head hold) | 0 | DOINK.ASM:426 |
| **Joybuzzer** | hold PUNCH≥100 release / from head-hold | **grab+shock** | 25 | DOINK.ASM:260, DNKSEQ3:92 |
| Head slam | head-hold: down,down+SKICK | grapple follow-up | — | DOINK.ASM:685 |
| Piledriver | head-hold: toward,toward+SPUNCH | grapple | 33 | DOINK.ASM:762, DNKSEQ3:537 |
| Held combos | head-hold+toward+SPUNCH/SKICK | grapple combos | — | DOINK.ASM:907 |
| Block | BLOCK | defensive | — | DOINK.ASM:1941 |
| Pin | any button, opp down, all opps dead | pin | — | DOINK.ASM:1763 |
| Taunt/finishers | smove processes | meta | — | DOINK.ASM:1092 |

STDSEQ-shared (all wrestlers, `STDSEQ.DOC`): punch/push/lbowdrop/butt/kick/stomp/knee, flying_kick,
run, and reaction anims head_hit/head_hit2/losebal/body_hit/hitonground/fall_back/dizzy. Everything in the
motion/charge/head-hold rows is **Doink-specific** (matches `MOVES1.DOC`).

## 4. Grapples / throws

- **Trigger/range:** gate on `CLOSEST_DIST`/`CLOSEST_XDIST` (hip toss ≤70h; head-grab close ≤90). Refuse if
  opp is DEAD/ONGROUND/HEADHELD.
- **Attach:** `LEAPATOPP` homes onto target; `ANI_ATTACK_ON AMODE_PUPPET*` + `ANI_WAITHITOPP` waits for
  connect; on hit `ANI_ATTACHZ` binds victim via `ATTACH_PROC` pointers; `MODE_GHOST`+`MODE_KEEPATTACHED`
  make victim a puppet.
- **Puppet playback:** `ANI_SUPERSLAVE2` drives the victim's image/position from the attacker's sequence
  frame-by-frame (both bodies animate from one master sequence).
- **Throw outcome:** at slam frame: `ANI_CODE HIT_THE_MAT`, screen shake, `ANI_DAMAGEOPP D_HIPTOSS,RD_HIPTOSS`,
  `ANI_SLAVEANIM #rollout`, `ANI_DETACH` → release into `MODE_ONGROUND`. Near ropes → fling out of ring.
- **Head-hold & reversals:** `#neck_grab` → attacker `MODE_HEADHOLD`, victim `MODE_HEADHELD`; background
  smoves read follow-up inputs. Victim counter (if not immobilized) → `DO_REVERSAL` swaps roles, sets
  `IMMOBILIZE_TIME=15` on loser.

## Uncertain
- Exact recovery-frame totals per move (derivable by summing `WL` ticks after ANI_ATTACK_OFF; not tabulated).
- Per-move KD-vs-dizzy outcome lives in the *defender's* reaction code (AMODE→reaction), not the offense seq.
- "Flower squirt"/"whoopee cushion" in design docs but no dedicated sequence labels found.
- Exact sub-field packing of `ANI_ATTACK_ON` x/y/w/h within the stored longs not fully decoded.
