# Arcade Research: Damage, Collision & Reactions

Source: `historicalsource/wwf-wrestlemania` (TMS34010 asm). Reverse-engineered, read-only.
Captured 2026-05-27. All values cite `file:line` in the arcade tree.

**Units:** Health/damage = life-bar pixels (max 163). Box dims = world units (≈ screen px at the object's plane).
Times = ticks; **`TSEC = 53` ticks/second** (`DISPLAY.EQU:46`) — NOTE: arcade logic runs at **53 Hz**, not 60.
Positions are 16.16 fixed-point (`*POS`/`*POSINT`); collision uses the integer halves.

## 1. Damage values (`DAMAGE.EQU`)

Each `D_*` has a paired `RD_*` "repeat damage" = `D_* × 2/3`, used when the victim took damage in the
last 50 ticks. Puppet/grapple moves (`DAMAGE.EQU:129-166`) are pre-scaled `×135/100`.

Strikes (`DAMAGE.EQU:8-123`): D_PUNCH 8, D_KICK 13, D_UPRCUT 20, D_BIGBOOT 18, D_KNEE 12, D_BOXPUNCH 20,
D_STOMP 8, D_SPINKIK 17, D_CLINE 20, D_JUMPKICK 20, D_BCKHAND 19, D_BUZZ 25, D_HAYMAKER 23, D_FLYKICK 28,
D_HDBUTT 12, D_LBDROP 17, D_PUSH 1, D_BUTTSTOMP 28, D_BIGKNEE 17, D_SPDKIK 10, D_ARMBRK 17, D_RSLASH 14,
D_SALT 15, D_GUTPUSH 15, D_NAPALM 20, D_FIRE_PUNCH 10 (full list in source). Grab/hold/throw = 0 damage
(damage comes from the puppet move that follows).

Puppet/grapple effective (raw→×1.35): D_BSLAM 27, D_GSUPLEX 29, D_FSTEIN 33, D_HIPTOSS 27, D_PILEDRIVER 33,
D_FACESLAM1 27, D_BACKBRKR 33, D_SCISSOR 32, D_KICKTOSS 29, D_NECKBRKR 29, D_FLIPSLAM 35, D_FACERAKE 21.

Runtime lookup `damage_values` (`REACT1.ASM:1626-1692`): AMODE index → `.word D_xxx, RD_xxx`.

**Damage formula** (`REACT1.ASM:490-507`): `final = base × (256+offense_mod)/256 × (256+defense_mod)/256`.
- offense_mod = `_35PCT` = 89 for ALL wrestlers → universal ×1.348 (`REACT1.ASM:1695-1704`, `GAME.EQU:460`).
- defense_mod = 0 for all.
- Further: combo scaling `(15 − hit#)` floor 4 (`LIFEBAR.ASM:1434-1447`), `DAM_MULT` bonus ×3/2…×5/2,
  drone-count + speed_adjustment. Friendly-fire = 1px.

## 2. Collision model

Player struct boxes (`PLYR.EQU:35-54`), each `{XOFF,YOFF,ZOFF,WIDTH,HEIGHT,DEPTH}`:
- **OBJ_BOX\*** — body/push box (body-blocking).
- **OBJ_COLL\*** — computed hurt box (defensive): `COLLX1/X2,Y1/Y2,Z1/Z2`.
- **OBJ_ATT\*** — attack box (offensive reach), set per attack frame.

Combat is **3D AABB** on X (horizontal), Y (screen-height), Z (depth into belt-scroll plane).

`set_collision_boxes` (`COLLIS.ASM:260-354`): X/Y/W/H from the current animation frame's embedded box
(`IANI3X/Y/Z/ID`, offsets `SYS.EQU:241-244`). **Z depth set by mode** (`COLLIS.ASM:270-296`):
- standing/normal: `BOXZOFF=-30, BOXDEPTH=60` (±30 Z half-depth)
- `MODE_ONGROUND`: `-15 / 30`
- `MODE_RUNNING`: `-5 / 10` (thin — runners slip past)

**Hit test** `check_collis` (`COLLIS.ASM:486-524`): 6-way AABB overlap of attacker attack-box vs victim
hurt-box; miss if any axis disjoint. **A hit lands only when attack-box Z overlaps victim body Z; standing
depth tolerance ≈ 60 world units total.** Then eligibility filters (target match, dead/teammate, pin,
in-ring, airborne rules, immobilize, no-collis). Hit side from relative X/Z (`COLLIS.ASM:639-655`).
Active only when attacker in an attack frame (`MODE_CHECKHIT_BIT`, `ANIM.EQU:200-201`); runs even/odd ticks.

Body-blocking movement = separate `overlap_collision` (`COLLIS.ASM:56-256`) using OBJ_COLL boxes.
`COLL2.ASM` is dead Robotron/Total Carnage pixel-scan code — NOT used for wrestlers.

## 3. Reaction system

`wrestler_hit` (`REACT1.ASM:420-638`): reaction chosen by the **attacker's `ATTACK_MODE`** via 56-entry
`#hit_table` jump table (`REACT1.ASM:833-901`) — **by move, not damage threshold**. Then damage applied.
- Turnbuckle victim → `hit_ontbukl` (flung into air).
- Repeat/weak hit: victim damaged within **50 ticks** → use `RD_*` (⅔) column (`REACT1.ASM:457-466`).
- Block: each `hit_*` checks `MODE_BLOCK` → `block_hit`; blocked damage = 1px (except BSTOMP/BLBOWDROP ignore block).

Core reaction families (per-wrestler anim tables `REACT1.ASM:1723-1866`): `head_hit`, `head_hit2`,
`head_hit_dizzy`, `body_hit`, `body_hit_dizzy`, `fall_back`, `hitblock`, `hitblock_flail`,
`losebal` (stagger), `hitonground`, `knockdwn`, `convulse` (death). Fall-back vs stand-hit branches on
victim height above `GROUND_Y` ≥ 20.

Reaction routines spread REACT1-9 by AMODE: punch/firepunch, hdbutt, kick/superkick, flykick (knockdown),
grab/hold/fling (0 dmg), uprcut (fall-back + upward Y-vel), lbowdrop (only hits down/airborne),
push/gutpush (stagger + fling, won't kill), bigboot/knee/boxpunch, stomp/spinkick/cline/buttstomp,
run/puppet/backhand/buzz/haymaker/earslap (REACT5, largest), shawn kicks (REACT8), razor slash/napalm (REACT9).

**Getup/hitstun** `set_getup_time` (`GETUP.ASM:32-184`): per-AMODE × per-wrestler table. Most moves = **0**
(get right up). Knockdowns (FLYKICK, HIPTOSS, BIGBOOT, BIGKNEE) = `STAY_TIME = 270` ticks ≈ **5.1s** down
(`GAME.EQU:14`). Other timers: `DELAY_METER`, `IMMOBILIZE_TIME`, `SAFE_TIME`, `DELAY_BUTNS`.

**Dizzy:** `PLYR_DIZZY`/`PLYR_DIZZY_CNT` (`PLYR.EQU:117-118`), `MODE_DIZZY=8`; dizzy anim tables exist, but
inline `check_dizzy` calls in REACT are **commented out** — dizzy is triggered from inside animation
sequences now. `check_dizzy` defined elsewhere (referenced `DNK.ASM:111`). (Trigger condition: see agent B.)

## 4. Health (`LIFEBAR.ASM`)

- **LIFE_MAX = 163** (`LIFEBAR.ASM:135`); everyone starts full. `adjust_health` (1366) adds signed delta,
  clamps `[0,163]`, sets `LAST_DAMAGE=PCNT`.
- Lethal fudge: a would-be-kill with life-after > −10 **and hit ≥20** sets life to 5 (survives) (`:1557-1573`).
  (Verified against source 2026-05-27: `cmpi -20,a0 / jrgt #no_fudge`, `a0` = negative damage ⇒ fudge fires only when dmg ≥ 20. Comment in source: "If it was a 20+ point hit … fudge it." An earlier draft of this note inverted the threshold to ≤20.)
- Low-health warning when crossing >30 → ≤30. KO at life == 0 → `MODE_DEAD`, death anim.
- Combo death deferred: killed mid-combo → life restored to 1, `I_WILL_DIE` set, dies at combo end.
- Pin = state machine on a downed/pinnable opponent (`B_PINABLE/PINNED`, `AUTO_PIN_CNTDOWN`), separate from KO.

## Uncertain / not determined
- Exact per-move attack-box dims (`OBJ_ATT*`) — written from per-wrestler SEQ animation data, not a static table.
- Per-frame hurt-box (`IANI3*`) — embedded in compiled IMG frame headers, not readable constants.
- `check_dizzy` trigger thresholds — defined outside files read (DNK.ASM context).
- Pin success mash counts; `speed_adjustment`/drone damage tables exact entries.
