class_name Uid
## Stable-UID helper for the .tres build tools. ResourceSaver.save() drops the `uid=` header
## attribute, which breaks every by-UID reference (scenes, motion tables). These helpers capture
## an existing file's UID before a save (or mint a fresh, registered one for a new file) and
## re-inject it into the `[gd_resource ...]` header afterward, keeping references stable.

## The current UID of `path` (preserved if the file exists), or a freshly minted + registered one.
## Returns the "uid://..." text. Call BEFORE saving over the path.
static func preserve_or_mint(path: String) -> String:
	var existing := _read_header_uid(path)
	if existing != "":
		return existing
	var id := ResourceUID.create_id()
	ResourceUID.add_id(id, path)
	return ResourceUID.id_to_text(id)

## Ensure `path`'s `[gd_resource ...]` header carries `uid_text`. No-op if already present/empty.
static func stamp(path: String, uid_text: String) -> void:
	if uid_text == "":
		return
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	if text.contains('uid="'):
		return
	# Inject before the closing ']' of the first header line (the only `format=N]` in the file).
	var nl := text.find("\n")
	if nl < 0:
		return
	var header := text.substr(0, nl)
	var rest := text.substr(nl)
	if not header.ends_with("]"):
		return
	header = header.substr(0, header.length() - 1) + ' uid="%s"]' % uid_text
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(header + rest)
	f.close()

static func _read_header_uid(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	var first := f.get_line()
	f.close()
	var rx := RegEx.create_from_string('uid="(uid://[^"]+)"')
	var m := rx.search(first)
	return m.get_string(1) if m != null else ""
