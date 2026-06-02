class_name SoundCategory
## Sound categories. Impact categories ARE the arcade move categories — which our `AMode`
## enum already mirrors (PUNCH, HDBUTT, KICK, ...) — so a move's `attack_mode` is used directly
## as the lookup key (arcade WRSND indexes the sound table by move type). The voice/event
## categories below live ABOVE the AMode range so they never collide with an impact category.
const PAIN := 100        # victim grunt on taking a hit (arcade pain voice)
const EFFORT := 101      # attacker effort grunt (arcade ANI_SOUND grunts, e.g. 82h)
const TAUNT := 102       # laugh/taunt
const BODY_DROP := 103   # the thud of a body hitting the floor (arcade bounce_l1 / RUGSLAM_IMPACT)

# Announcer / play-by-play commentary categories (resolved against the announcer_table).
const ANNC_IMPRESSIVE := 200   # a big move landed (knockdown-family hit / throw)
const ANNC_KO := 201           # a fighter was knocked out (reached 0 health)
const ANNC_NEAR_KO := 202      # knocked down, still alive, low health ("can he get up in time")
