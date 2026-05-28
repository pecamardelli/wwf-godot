# Arcade Research: Motion Buffer & Grapple/Puppet/Throw System (Deep Dive)

Source: `/home/pablin/Games/wwf-wrestlemania` (TMS34010 asm, Jamie Rivett). Read-only. Doink = `dnk` / wrestler #6. Logic runs at **53 Hz** (`TSEC=53`). This **extends and corrects** the two prior research docs (`…-arcade-move-animation-system.md` §2/§4, `…-arcade-damage-collision-reactions.md` §4). Corrections are flagged **[CORRECTION]**.

---

## A. Motion buffer (`check_secret_moves` / `wrest_joystat`)

### A.1 Buffer structure & entry encoding

Rolling input-history buffer `wrest_joystat`, declared `BSSX wrest_joystat, 32*16*NUM_WRES` (`WRESTLE.ASM:206`). Per wrestler: **16 entries × 32 bits** (comment "16 bit joyval : 16 bit count"), stride 32 bits.

Each entry (built in `#insert`, `WRESTLE.ASM:4630-4648`):
```
entry = (round_tickcount << 16) | (16-bit joy/button field)
```
- High 16 bits = `round_tickcount` timestamp (`BSSX round_tickcount,16`, `WRESTLE.ASM:203`; free-running per-round tick counter, the motion time base).
- Low 16 bits = input field (`update_joystat`, `WRESTLE.ASM:4569-4628`, `GAME.EQU:355-428`):
  - **bits 0–3 = joystick, facing-relative**: `J_UP=1`(b0), `J_DOWN=2`(b1), `J_AWAY=4`(b2=`MOVE_LEFT`), `J_TOWARD=8`(b3=`MOVE_RIGHT`). Diagonals OR'd (`J_DOWN_TOWARD=10`). **Flipped by `FACING_DIR`** via `#xflip_table` (`WRESTLE.ASM:4650-4662`) so toward/away is opponent-relative.
  - **bits 4–8 = buttons** (`B_xxx = PLAYER_xxx_VAL << 4`, `GAME.EQU:424-428`): `B_PUNCH`=b4, `B_BLOCK`=b5, `B_SPUNCH`=b6, `B_KICK`=b7, `B_SKICK`=b8.
  - **bits 10–11 = real (un-flipped) L/R** (`STICK_VAL_CUR & 1100b` → b10/b11, `WRESTLE.ASM:4576-4579`): `J_LEFT=MOVE_LEFT<<8`, `J_RIGHT=MOVE_RIGHT<<8`, `J_REAL_LR=0C00h`.

**[CORRECTION]** prior doc said `tick<<16 | (joy|button)` with buttons implicitly low — confirmed, but precise layout is joy=b0-3 (facing-flipped), buttons=b4-8, real-LR=b10-11.

### A.2 When entries are pushed

`update_joystat` runs once per wrestler per frame (`WRESTLE.ASM:2452`), inserting on **edge events only**:
- **Stick change**: if `STICK_VAL_UP | STICK_VAL_DOWN ≠ 0`, push one entry w/ current flipped stick (`WRESTLE.ASM:4592-4602`).
- **Button down**: for each of 5 button bits set in `BUT_VAL_DOWN`, push one entry = that single button bit OR'd with current stick (one button per entry) (`WRESTLE.ASM:4606-4623`).

`#insert` shifts all 16 entries down one (oldest drops) and writes the newest at index 0 (`WRESTLE.ASM:4638-4647`).

### A.3 Pattern-match algorithm (`check_secret_moves`, `WRESTLE.ASM:4851-4938`)

`a11`=move table ptr (`doink_secret_moves`, `DOINK.ASM:214`). Gating early-out: `IMMOBILIZE_TIME≠0`, `PLYRMODE==MODE_DIZZY`, `==MODE_WAITANIM`, or `GETUP_TIME≠0` (`WRESTLE.ASM:4853-4864`).

**First table entry is a button-hold test code**: `move *a11+,a0,L / call a0 / jrc #done` (`:4866-4868`). First `.long` = `#charge_buzz` (`DOINK.ASM:220`) — a subroutine for charge/release (A.5) that returns carry-set to abort scanning.

**Freshness gate**: only scan if newest queue entry timestamp == current `round_tickcount` (`:4874-4878`) — a motion only triggers the frame an edge was pushed.

`#next_table` loop (`:4881-4919`) iterates remaining table longs (each → a `{value,mask}` list):
- **Head check** (`:4889-4898`): queue head low-16 AND-NOT first pattern mask; non-zero ⇒ noise since trigger ⇒ reject pattern.
- **Scan newest→back** (`:4900-4919`): pattern read as alternating `value`(word),`mask`(word). A `value` with sign bit set (`8000h|maxframes`) is the terminator. Each step walks back queue entries, splits `tick`(hi16)/`input`(lo16 masked), compares. Up to **8 masked entries** skipped between matches (noise tolerance per step). Step fail → next move.
- **Terminator/time-window** (`#match`, `:4924-4938`): `maxframes = value & 7FFFh`; `elapsed = round_tickcount − tick_of_last_matched_entry`; `elapsed > maxframes` → fail. Else read trailing `.long` handler and jump.

Pattern data shape:
```
.word value0, mask0      ; newest input (trigger)
.word value1, mask1      ; next-older
...
.word 8000h | maxframes  ; terminator; maxframes = whole-motion window (ticks)
.long handler
```

**[CORRECTION]** maxframes = `terminator & 0x7FFF`; window measured to the **last matched** entry's tick; the 8-entry skip budget and freshness gate were undocumented.

### A.4 Doink GRAB/throw/special pattern data (`DOINK.ASM:328-619`)

`B_PUNCH=10h(b4)`, `B_SPUNCH=40h(b6)`, `B_SKICK=100h(b8)`; `J_TOWARD=8`, `J_AWAY=4`, `J_DOWN=2`, `J_DOWN_TOWARD=10`; `J_REAL_LR=0C00h`; `J_ALL=0F0Fh`.

| Move | Pattern (`value,mask` per line → terminator) | Handler |
|---|---|---|
| **Boxing glove** (`#boxing_pnch`,:330) | `B_PUNCH,J_ALL` ×7 ; `8000h\|60` | `scrt_glove` (:341) |
| **Hammer** (`#hammer`,:365) | `B_SKICK,J_ALL` ; `J_TOWARD,J_REAL_LR` ; `J_TOWARD,J_REAL_LR` ; `8000h\|32` | `scrt_hammer` |
| **Ear slap** (`#earslap`,:391) | `B_PUNCH,J_ALL` ; `J_TOWARD,J_REAL_LR` ; `J_DOWN_TOWARD,J_REAL_LR` ; `J_DOWN,J_REAL_LR` ; `8000h\|50` | `#scrt_earslap` |
| **Neck/head grab** (`#neck_grab`,:426) | `B_SPUNCH,J_ALL` ; `J_TOWARD,J_REAL_LR` ; `J_TOWARD,J_REAL_LR` ; `8000h\|32` | `#scrt_neck` (:433) |
| **Grab & fling** (`#grab_fling`,:504) | `B_SPUNCH,J_ALL` ; `J_AWAY,J_REAL_LR` ; `J_AWAY,J_REAL_LR` ; `8000h\|32` | `#scrt_grabfling` |
| **Hip toss** (`#hip_toss`,:572) | `B_PUNCH,J_ALL` ; `J_AWAY,J_REAL_LR` ; `J_AWAY,J_REAL_LR` ; `8000h\|32` | `#scrt_hiptoss` |
| **Grab-fling 2** (vs running/air) (`#grab_fling2`,:477) | `B_SPUNCH\|J_AWAY, J_REAL_LR\|J_UP\|J_DOWN` ; `8000h\|10` | `#scrt_grabfling2` |
| **Hip-toss 2** (vs running/air) (`#hip_toss2`,:482) | `B_PUNCH\|J_AWAY, J_REAL_LR\|J_UP\|J_DOWN` ; `8000h\|10` | `#scrt_grabfling2` |

Masks: `J_ALL=0F0Fh` masks everything (trigger step needs exact button + head-noise check). `J_REAL_LR=0C00h` masks only real L/R bits, so `J_TOWARD`/`J_AWAY` match facing-relative direction ignoring absolute L/R. Combined patterns (`B_PUNCH|J_AWAY`) need button+dir in one entry (button-down while stick already away).

Handler eligibility (common): `ANIMODE & MODE_UNINT` (busy → abort), opp `MODE_ONGROUND`/`MODE_DEAD`/`MODE_HEADHELD`, turnbuckle. `#scrt_neck` adds a **2-second cooldown** vs `LAST_HEADHOLD` (`DOINK.ASM:447-457`: if `PCNT−LAST_HEADHOLD < 2*60` plays a *fake* hold); picks `head_hold2` when `CLOSEST_XDIST ≤ 90` else `head_hold` (`:462-472`). `scrt_glove` refuses if `COMBO_COUNT≠0`.

### A.5 Charge/hold-then-release moves

**(1) dtime counters** (`WRESTLE.ASM:3954-4076`): `punch_dtime1`/etc., one word/wrestler. `update_joy_dtime` (per frame, `:2493`) increments while held, **resets to 0 on release**. `get_punch_dtime` returns held-tick count.

**(2) `#charge_buzz`** (special first table entry, `DOINK.ASM:260-282`): each frame tests `BUT_VAL_UP` for PUNCH (just released); if released, `get_punch_dtime ≥ 100` ticks → `#scrt_buzz`, returns carry-set to abort scan. `#scrt_buzz` picks `buzz2_anim` (leaping) if running/stick-toward else `buzz_anim`. (`#charge_flying_kick` present but commented out.)

---

## B. Grapple attach / puppet / throw / reversal

### B.1 Animation command dispatch

Word ≥ `8000h` = command, dispatched via `#ani_commands` (`ANIM.ASM:202-350`). Opcodes (`ANIM.EQU:14-150`): `ANI_LEAPATOPP=8`, `ANI_DETACH=10`, `ANI_ATTACHZ=18`, `ANI_SUPERSLAVE=63`, `ANI_SLAVEANIM=64`, `ANI_DAMAGEOPP=66`, `ANI_WAITHITOPP=68`, `ANI_SUPERSLAVE2=79`, `ANI_SETOPPMODE=80`, `ANI_CLROPPMODE=81`, `ANI_SET_ATTACH=113`.

### B.2 `LEAPATOPP` — homing onto the target (`ANIM.ASM:512-833`)

`LEAPATOPP ticks,maxTotalDist,maxXdist,maxZdist,maxYvel,target,attXoff,attYoff,attZoff` (`ANIM.EQU:156-161`):
- Target = `CLOSEST_NUM`'s process (`:544-547`).
- **Predicts** target pos `ticks` frames ahead by integrating its X/Z/Y velocity + gravity (`:600-623`). (If target `MODE_RUNNING` near ropes, target current X.)
- Sets attacker's **XVEL/ZVEL/YVEL** to land at `(predicted opp + target offset − attacker box offset)` in `ticks` frames, clamped by max dists; YVEL from `y−y0 = v0·t + ½g·t²` (`:638-795`).
- INRING mismatch → cancel XZ, small upward leap (`:798-831`).

Sets **velocities**, not teleport. Head-hold: `LEAPATOPP 9,999,40,45,90000h,TGT_HEAD,60,105,0` (`DNKSEQ3.ASM:1437`); hip-toss: `LEAPATOPP 8,40,40,40,90000h,TGT_CHEST,40,0,0` (`DNKSEQ2.ASM:4240`).

### B.3 `ANI_ATTACK_ON AMODE_PUPPET*` + `ANI_WAITHITOPP` — waiting for connect

Grab: `ANI_STARTATTACK,AT_PUPPET,n` then `ANI_ATTACK_ON, AMODE_PUPPET…,x,y,w,h` (hip-toss `AMODE_PUPPET_TOSS,33,46,44,38`, `DNKSEQ2.ASM:4238,4244`; head-grab `AMODE_PUPPET,32,60,62,45`, `DNKSEQ3.ASM:1440`).

`ANI_WAITHITOPP` (`ANIM.ASM:2300-2314`): OR's `MODE_WAITHITOPP` into ANIMODE, holds the frame up to `maxticks` (macro `WWL ANI_WAITHITOPP,maxticks,frame`; hip-toss maxticks=4). Connect detected in collision: on a landed hit `check_collis` sees `MODE_WAITHITOPP_BIT`, clears it, **zeroes `ANICNT`/`ANICNT2`** to advance past the wait frame (`COLLIS.ASM:609-619`). Hit/miss read via `ANI_IFNOTSTATUS` (`MODE_STATUS` set on hit, `COLLIS.ASM:657-659`) and `ANI_IFBLOCKED`. `WHOIHIT`=victim set in reaction (`REACT1.ASM:435-439`). Dead victims: `AMODE_PUPPET`/`PUPPET2` disallowed (`COLLIS.ASM:555-560`).

### B.4 `ANI_SET_ATTACH` / binding the victim

**[CORRECTION]** Prior doc said `ANI_ATTACHZ` binds the victim — **wrong**. Binding is **`ANI_SET_ATTACH` (113)**:
```
WHOIHIT → attacker.ATTACH_PROC ;  attacker → victim.ATTACH_PROC
```
(`ANIM.ASM:4156-4159`) — a **two-way pointer link**.

`ANI_ATTACHZ x,y,z` (`ANIM.ASM:1039-1053`) only stores **attach offsets** on the attacker (`ATTACH_XOFF` long incl Y, `ATTACH_ZOFF`). Link is established by the hit (collision → reaction sets `WHOIHIT`) and formalized two-way by `ANI_SET_ATTACH`.

### B.5 `MODE_GHOST` + `MODE_KEEPATTACHED` (`ANIM.EQU:221-228`)

`MODE_GHOST=800h` ("may fall through floor if attached"), `MODE_KEEPATTACHED=2000h`.
- `ANI_SETOPPMODE,MODE_GHOST` on the **victim** during the airborne throw arc (`DNKSEQ2.ASM:4262`): `master_keep_attached` skips the victim floor-clamp if GHOST (`WRESTLE.ASM:4359-4362`); cleared at impact (`:4287`).
- `MODE_KEEPATTACHED` on the **attacker** (`DNKSEQ2.ASM:4263`). Each frame the loop checks `MODE_KEEPATTACHED_BIT` → `master_keep_attached` (`WRESTLE.ASM:2479-2483`), which **forces the victim's X/Y/Z = attacker pos + ATTACH_XOFF/YOFF/ZOFF** (X negated if attacker faces left), zeroes victim YVEL (`:4343-4407`).

### B.6 `ANI_SUPERSLAVE2` & `ANI_SLAVEANIM` — driving the victim frame-by-frame

`ANI_SUPERSLAVE2 ticks,attackerFrame,slaveTable,index` (`ANIM.ASM:2681-2857`). Per frame:
1. Verifies two-way `ATTACH_PROC` link (`:2708-2711`).
2. Attacker frame = `attackerFrame`, held `ticks` (×ANI_SPEED) (`:2713-2727`).
3. Index `slaveTable` by **victim `WRESTLERNUM`** then by `index` into `{LONG frame, WORD xoff, WORD yoff, WORD flip}` (`:2731-2750`).
4. **Victim displayed frame = table frame** (`:2759`) — bespoke per-wrestler "being-tossed" art (`#puppet_tbl`, `DNKSEQ3.ASM:1549-1609`).
5. **Recomputes victim attach offset each frame** from both frames' part-offset metadata: `ATTACH_YOFF = rawY − victim.aniY + attacker.aniY`; `ATTACH_XOFF = rawX + victimXoff − attackerXoff` (negated on facing mismatch) (`:2761-2835`). Victim flip = attacker facing XOR table flip (`:2838-2854`). `master_keep_attached` consumes these same frame.

`ANI_SUPERSLAVE` (63): simpler — image + offsets straight from a `{*image,xoff,yoff,flip}` table, no part math.

`ANI_SLAVEANIM slaveTable` (64, `ANIM.ASM:2130-2162`): runs a **whole anim script** on the victim (indexed by victim `WRESTLERNUM`) via `change_anim1a`. Hands the victim to his own sequence — `#rollout_tbl` after a slam (`DNKSEQ2.ASM:4285`), `#headheld_tbl` for the held loop (`DNKSEQ3.ASM:1468`).

### B.7 Throw outcome (Doink hip toss `dnk_4_hiptoss_anim`, `DNKSEQ2.ASM:4228-4423`)

1. `MODE_UNINT|MODE_NOAUTOFLIP`, `ANI_STARTATTACK,AT_PUPPET,10`, `LEAPATOPP …TGT_CHEST`.
2. `ANI_ATTACK_ON,AMODE_PUPPET_TOSS,…`, `WWL ANI_WAITHITOPP,4,frame`, `ANI_ATTACK_OFF`.
3. `ANI_IFNOTSTATUS #missed` / `ANI_IFBLOCKED #missedb` (`:4251-4252`).
4. On hit: `MAKE_HIM_SCREAM`, `ANI_ATTACHZ,0,0,2`, `ANI_SETOPPMODE,MODE_GHOST`, attacker `…|MODE_OVERLAP|MODE_KEEPATTACHED` (`:4259-4263`).
5. Lift/spin: `ANI_SUPERSLAVE2` frames indexing `#puppet_tbl 0…7` (`:4266-4277`) + `SMALL_BOUNCE`. `ANI_IFROPE,RC_BACK,XTOSSDIST_CLOSE,#throw_him_out` diverts to fling-out (`:4273`).
6. Impact: `ANI_CODE HIT_THE_MAT`, `ANI_SHAKEALL,2`, `ANI_SHAKER,30`, `ANI_DAMAGEOPP,D_HIPTOSS,RD_HIPTOSS` (`:4280-4283`). `ANI_DAMAGEOPP` (`ANIM.ASM:2174-2277`) damages `ATTACH_PROC` (else `WHOIHIT`); uses reduced `RD_*` if victim hit within last 30 ticks; first-hit award + `DAM_MULT`.
7. Release: `ANI_SLAVEANIM,#rollout_tbl` (`:4285`), `ANI_CLROPPMODE,MODE_GHOST`, drop `MODE_KEEPATTACHED`, `ANI_DETACH` (`:4287-4290`), recovery → `ANI_SETPLYRMODE,MODE_NORMAL`, `ANI_END`.

`ANI_DETACH` (`ANIM.ASM:851-887`): clears both `ATTACH_PROC` (if cross-matched); if victim still `MODE_PUPPET`/`PUPPET2`/`ATTACHED` → **forces `MODE_ONGROUND`** (`:867-882`).

**Fling out of ring** (`#throw_him_out`, `:4379-4400`): `ANI_ATTACHVEL,-0a0000h,90000h,0h` (big outward+up vel), `CALL_THROWN_OUT`, `ANI_SLAVEANIM #flyout_tbl`, `ANI_OPPOFFSET release_table`, `ANI_DETACH`.

### B.8 Head-hold & reversals

**Entering** (`dnk_3_head_hold_anim`, `DNKSEQ3.ASM:1424-1474`): grab via `AMODE_PUPPET`+`ANI_WAITHITOPP`; on connect → `ANI_ATTACHZ`, `head_grab_time` (stamps `LAST_HEADHOLD=PCNT`, zeroes victim button counters via `clear_opp_counts`, `:1509-1525`), `MODE_KEEPATTACHED`, `ANI_SUPERSLAVE2` frames, `ANI_SETPLYRMODE,MODE_HEADHOLD` (attacker, `:1467`), `ANI_SLAVEANIM,#headheld_tbl` → victim runs `dnk_3_head_held_anim` → `ANI_SETPLYRMODE,MODE_HEADHELD` (`:1629`). Held loop runs 3–4 cycles then auto-breaks (`:1679-1700`) into `dnk_3_head_held_brk_anim`.

**Follow-ups via background "smove" processes** (`init_smoves` spawns one process per `dnk_smove_table` entry, `WRESTLE2.ASM:4058-4090`, `DOINK.ASM:239-256`). They loop `SLEEPK 1`; on recognized input write a sequence ptr into `SPECIAL_MOVE_ADDR`, which `move_wrestler` plays and clears, overriding `move_doink` (`WRESTLE.ASM:3846-3853`).

Each smove uses **`WAITSWITCH_DWN switches,mask,fail`** (`MACROS.H:652-670`): per tick `SLEEPK 1`, decrement window `a11` (fail on 0), fail if `SPECIAL_MOVE_ADDR` busy, build input `= (BUT_VAL_DOWN<<4)|STICK_REL_NEW`, mask, require **exact** match. Chained calls form a motion w/ per-step `#TIMEOUT` (≈60 ticks).

| Follow-up | Input | Result |
|---|---|---|
| **Head slam** (`dnk_hdhold_slam`,:685) | `J_DOWN`;`J_DOWN`;`B_SKICK` (:703-708) | `dnk_3_head_slam_anim` |
| **Piledriver** (`dnk_hdhold_pile`,:762) | `J_TOWARD`;`J_TOWARD`;`B_SPUNCH` (:779-784) | `dnk_3_pile_driver_anim` (`D_PILEDRIVER`) |
| **Combo uppercut** (`dnk_hdhold_combo1`,:907) | `J_TOWARD`;`J_TOWARD`;`B_SPUNCH`, combo-gated | `dnk_combo_uppercut_to_head_anim` |
| **Combo kick** (`dnk_hdhold_combo2`,:964) | `J_TOWARD`;`J_TOWARD`;`B_SKICK`, combo-gated | `dnk_4_combo_kick_anim` |
| **Head-held buzzer** (`dnk_hdhold_buzz`) | (table :245) | joybuzzer from hold |

Each follow-up branches on `PLYRMODE`:
- `MODE_HEADHOLD` → **holder**: `SMRTTGT a8,WHOIHIT` (lock to held victim), `IMMOBILIZE_TIME=15` on victim, queue slam/pile (`DOINK.ASM:734-759`, `807-831`).
- `MODE_HEADHELD` → **held wrestler = reversal**: guard skip if `I_WILL_DIE` or own `IMMOBILIZE_TIME≠0` (`:715-722`); `DO_REVERSAL` (announcer, `DCSSOUND.ASM:3534`) + `DO_REVERSAL_MESS` (award/message, `LIFEBAR.ASM:3574-3598`); `SMRTTGT a8,WHOHITME` (retarget onto captor), `IMMOBILIZE_TIME=15` on `WHOHITME`, queue same slam/pile → held wrestler throws his captor (`:718-749`, `793-822`).

**`DO_REVERSAL` is NOT a role-swap routine.** Reversal is emergent: the held wrestler runs the *same* follow-up smove, retargets via `SMRTTGT WHOHITME` + immobilizes the captor 15t. Window = per-step `WAITSWITCH_DWN` `#TIMEOUT`≈60t while `MODE_HEADHELD`, allowed only when held wrestler's `IMMOBILIZE_TIME==0`.

`IMMOBILIZE_TIME`: generic per-frame-decremented stun (`WRESTLE.ASM:2525-2528`); also gates `check_secret_moves` (A.3). The value **15** is the literal written by slam/reversal (`movk 15`, `DOINK.ASM:748-749, 821-822`), not a named equate.

---

## Corrections vs prior research
- **Buffer layout** (A.1): joy b0-3 facing-flipped, buttons b4-8, real-LR b10-11; 8-entry per-step noise budget + freshness gate (newest timestamp == current tick).
- **Pattern terminator** (A.3): `maxframes = terminator & 0x7FFF`; window to last-matched entry's tick.
- **Victim binding** (B.4): `ANI_SET_ATTACH` (cmd 113, two-way `ATTACH_PROC`), not `ANI_ATTACHZ`.
- **Per-frame puppet position** (B.6): `ANI_SUPERSLAVE2` recomputes the victim offset each frame; `master_keep_attached` forces world position; victim sprite from per-wrestler slave subtable indexed by attacker step.
- **Reversal** (B.8): no dedicated swap; held wrestler runs the same follow-up smove w/ `SMRTTGT WHOHITME` + `IMMOBILIZE_TIME=15`; `DO_REVERSAL`/`_MESS` are sound/award/message only.

## Uncertain / not fully resolved
- Exact `round_tickcount` increment site not located; assumed one/frame (53 Hz), consistent with `maxframes` 32–60 ticks ≈ 0.6–1.1 s.
- `STICK_VAL_UP/DOWN` getter internals not opened; assumed standard edge snapshots.
- Per-wrestler puppet/headheld slave art tables: literal frame offsets for *non-Doink* victims not transcribed (only Doink-as-attacker relevant for a Doink reimpl).
