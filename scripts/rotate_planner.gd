class_name RotatePlanner
## Plan the `rotate` clip frame list (0-indexed) to pivot between two Facing.State corners,
## along the shorter arc of the 4-cycle FR→BR→BL→FL→FR. Each adjacent step is one segment.
## Frame map (from the imported 12-frame `rotate` clip):
##   FR→BR [2,3,4]  BR→BL [5,6,7]  BL→FL [8,9,10]  FL→FR [11,0,1]
## Going backward reverses the segment that would be traversed forward.

const _SEG := [[2, 3, 4], [5, 6, 7], [8, 9, 10], [11, 0, 1]]

static func plan(from_state: int, to_state: int) -> Array:
	if from_state == to_state:
		return []
	var fwd := (to_state - from_state + 4) % 4
	var bwd := 4 - fwd
	var frames: Array = []
	if fwd <= bwd:
		for k in range(fwd):
			frames.append_array(_SEG[(from_state + k) % 4])
	else:
		for k in range(bwd):
			# s = corner we depart on this backward step; _SEG[i] is the segment LEAVING
			# corner i, so the edge we cross backward is the one before s: _SEG[s-1], reversed.
			var s := (from_state - k + 4) % 4
			var seg: Array = _SEG[(s - 1 + 4) % 4].duplicate()
			seg.reverse()
			frames.append_array(seg)
	return frames
