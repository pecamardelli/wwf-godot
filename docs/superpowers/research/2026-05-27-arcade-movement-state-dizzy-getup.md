# Arcade Research: Movement, State Machine, Dizzy & Getup

Source: `historicalsource/wwf-wrestlemania` (TMS34010 asm). Read-only. Captured 2026-05-27.

## 0. Units / fixed-point
- Positions `OBJ_*POS` = 32-bit **16.16 fixed-point**; integer-pixel mirror in `OBJ_*POSINT` (`PLYR.EQU:24-31`).
- Velocities `OBJ_*VEL` = 16.16 px/tick (divide hex by 0x10000 for px/tick).
- **Planes: X = horizontal, Z = depth (the belt-scroll walk plane), Y = vertical height (jumps/gravity only).**

## 1. Timing model — TICK → frame
- Display IRQ (DIRQ) fires at **60 Hz** (`MAIN.ASM:748,1186`); one process dispatch = one tick = one frame.
- **`TSEC = 53` "ticks per second"** (`DISPLAY.EQU:46`) — the game's own seconds conversion (DMA/draw overhead
  ⇒ effective ~53 Hz). **Constants written `N*TSEC` are seconds; raw tick-counts are frames.**
- **Godot mapping:** run gameplay at fixed 60 Hz. Treat `*TSEC` constants as `ticks/53` seconds; apply raw
  tick-counts 1:1 at 60 Hz (or ×53/60 for exact wall-clock feel). `PCNT` = main-loop counter (timestamps).

## 2. Movement (all wrestlers share walk speeds)
- Per-tick integrate: `XPOS+=XVEL; ZPOS+=ZVEL; YPOS+=YVEL` (`WRESTLE2.ASM:2282+`). No walk acceleration —
  velocity is **set instantly** from an 8-way table each tick; neutral stick zeroes it instantly.
- **Walk:** cardinal `#VEL = 0x3a000` = **3.625 px/tick**; diagonal `#DVEL = 0x31000` = **3.0625 px/axis**
  (diagonal total ≈4.33, intentionally faster, NOT normalized).
- **Modifiers:** moving backward vs facing ×0.90; opponent down/dead or WALK_FAST ×1.50 (`WRESTLE.ASM:5431+`).
- **Run/dash:** `*_XRUN` Doink/Hart/Under/Bam/Shawn = `0x64000` = **6.25 px/tick** (Yoko 5.5, Razor/Lex 6.0);
  fast-powerup `*_XRUN2`=8.5; during run depth-drift `*_ZDRIFT`=±2.5 px/tick from up/down. `RUN_TIME` gates flying kick.
- **Gravity** `GRAVITY=0x8000` = 0.5 px/tick² on Y (`GAME.EQU:436`); only when not `MODE_NOGRAVITY`.
- **Friction:** X-only, when `MODE_FRICTION` set; XVEL decays toward 0 by `OBJ_FRICTION`/tick. Decays flung momentum.
- **Confinement** (`confine_wrestler`): clamp Z to ring depth `RING_TOP=1023..RING_BOT=1345` (`RING.EQU`), X to ropes.
- Flung: `start_run_flung` halves XVEL once, zeroes ZVEL, friction decays.

## 3. Player state (key `PLYR.EQU` fields)
- Physics: `OBJ_*POS/POSINT`, `OBJ_*VEL`, `OBJ_GRAVITY`, `OBJ_FRICTION`, `GROUND_Y`.
- Facing/intent: `MOVE_DIR`, `FACING_DIR`/`NEW_FACING_DIR`, `RUN_TIME`, `INRING`.
- **`PLYRMODE`** (primary state) values `MODE_*` 0-25 (`PLYR.EQU:276-306`): NORMAL=0, RUNNING=1, INAIR=2,
  ATTACHED=3, ONGROUND=4, BOUNCING=5, ONTURNBKL=6, BLOCK=7, **DIZZY=8**, DEAD=9, HEADHELD=19, PUPPET=20,
  INAIR2=21, CHOKEHOLD/CHOKING=24/25.
- `ATTACK_MODE`(AMODE_*), `ATTACK_TYPE`/`ATTACK_TIME`, `ANIMODE`/`ANIMODE2`, `STATUS_FLAGS` (B_KOD, B_PINNED,
  B_PRESS_LAST mash-tracking…).
- Stun/getup: **`GETUP_TIME`** (master stun countdown — nonzero = no control), `ROLL_POS`, `PLYR_DIZZY`,
  `PLYR_DIZZY_CNT`, `STARS_FLAG`, `DELAY_BUTNS`, `SAFE_TIME`, `DELAY_METER`, `IMMOBILIZE_TIME`.
- Input: `BUT_VAL_CUR/DOWN/UP`, `STICK_VAL_CUR/DOWN/UP`, `STICK_REL_CUR/NEW` (facing-relative).
- Combat: `COMBO_COUNT/START`, `CONSECUTIVE_HITS`, `BUCKOFF_COUNT`, `SPECIAL_MOVE_ADDR`, `WHOHITME/WHOIHIT`.

## 4. DIZZY / STUN — how control is disabled (IMPORTANT)
- **No separate dizzy timer** — old `check_dizzy` is commented out (`WRESTLE2.ASM:1366-1416`). In the shipping
  game, **stun = knockdown = `GETUP_TIME > 0`** (optionally with `PLYR_DIZZY`/stars set by the reaction anim).
- **How control is bypassed:** per-character `move_xxx` dispatches by `PLYRMODE`; the helpless handlers
  `mode_inair`, `mode_onground`, `mode_dizzy` are **literally `rets`** — joystick/button reading only happens
  in `mode_normal`/`mode_running`. So input is simply never read while helpless. Even `mode_running` checks
  `if GETUP_TIME != 0 → out_of_control`.
- **How it ends** (main loop `WRESTLE.ASM:2408+`): each tick if `GETUP_TIME != 0` decrement it; at 0 →
  `#clr_dizzy` clears `PLYR_DIZZY`/stars and sets `DELAY_BUTNS = 40` ticks (input lockout so you don't
  accidentally fire on recovery).
- **Reaction anims** emit `ANI_SETPLYRMODE MODE_DIZZY` and `ANI_GETUP,<ticks>` (stuffs `GETUP_TIME` if not
  already dizzy); `ANI_GETUP_WAIT` holds the down frame until `GETUP_TIME==0`.

## 5. Knockdown / getup timings & mash-to-recover
- `set_getup_time` (`GETUP.ASM:32`) indexes `#hit_table` by attacker `ATTACK_MODE` (per-attack × per-wrestler).
- **Most attacks → 0 ticks** (hit reactions, get right back up).
- **Knockdowns (hiptoss, big boot, flykick, big knee) → `STAY_TIME = 270` ticks ≈ 5.1 s** (`GAME.EQU:14`).
- **Flung → `FLUNG_TIME = 120` ticks ≈ 2.26 s** (`GAME.EQU:510`).
- **Mash-to-recover** (`WRESTLE.ASM:2585-2614`): each tick while down, a fresh button/stick press (or one last
  tick, tracked by `B_PRESS_LAST`) subtracts **3** from `GETUP_TIME` (clamp 0). Mashing ≈ up to ~3× faster.
- Post-getup: `DELAY_BUTNS=40` input lockout; `SAFE_TIME` 30-50 ticks collision-immunity while rising.
- Getup meter: `GETUP_SIZE=80`px, `MAX_TIME=6*TSEC=318` ticks (`WRESTLE2.ASM:939-941`).

## 6. Per-tick wrestler loop order (`WRESTLE.ASM:2408+`)
1. `update_joystat` (capture stick/buttons, facing-relative) →
2. `wrestler_veladd` (integrate pos + gravity) →
3. `wrestler_friction` (decay X) →
4. `move_wrestler` → `move_xxx` → `mode_normal` → `execute_walk` → `set_velocities` (8-way table) →
5. `confine_wrestler` (clamp Z depth / X ropes) →
6. GETUP/dizzy countdown + mash handling.

## Godot cheat-sheet (divide hex by 65536 for px/tick)
- Walk cardinal 3.625, diagonal 3.0625/axis; backward ×0.9; opp-down/fast ×1.5.
- Run 6.25 (Yoko 5.5, Razor/Lex 6.0); fast 8.5; run depth-drift ±2.5.
- Gravity 0.5 px/tick² on Y. Friction = linear X decay when active.
- Knockdown 270 ticks; flung 120; mash −3/tick; 40-tick post-getup lockout; 30-50 tick rise invuln.
- **1 second = 53 ticks.**

## Uncertain
- Exact TSEC=53 vs 60 Hz wall-clock semantics (treat 53 for `*TSEC`, 60 for raw IRQ).
- `OBJ_FRICTION` numeric value (per-character/per-anim, not one global). Mechanism (X-only decay) is certain.
- No walk acceleration ramp (instant set). Diagonal intentionally faster (not normalized).
