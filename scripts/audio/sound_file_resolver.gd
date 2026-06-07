class_name SoundFileResolver
## Fuzzy filename matching for the sound build tool: the JSON uses a normalized form ("swing4.wav")
## while the source files have spaces/case ("Swing 4.wav"). Both sides normalize the same way.

## Lowercase and remove spaces + underscores (the extension is kept, also lowercased).
static func normalize(name: String) -> String:
	return name.to_lower().replace(" ", "").replace("_", "")

## Look up a (possibly un-normalized) `name` in a prebuilt {normalized -> full_path} index.
## Returns the full path, or "" if absent.
static func resolve(name: String, index: Dictionary) -> String:
	return index.get(normalize(name), "")
