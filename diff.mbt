///|
pub(all) suberror DiffParseError {
  DiffParseError(String)
}

///|
pub(all) struct ChangedFile {
  path : String
  lines : Array[Int]
}

///|
/// Added line numbers indexed by new-file path.
pub(all) struct DiffFilter {
  files : Array[ChangedFile]
}

///|
fn normalize_diff_path(path : String) -> String {
  let mut normalized = path.trim().replace_all(old="\\", new="/").to_owned()
  if normalized.has_prefix("./") {
    normalized = normalized.view(start_offset=2).to_owned()
  }
  normalized
}

///|
fn parse_patch_path(value : String) -> String? {
  let raw = match value.find("\t") {
    Some(index) => value.view(end_offset=index).to_owned()
    None => value.trim().to_owned()
  }
  if raw == "/dev/null" {
    return None
  }
  let unquoted = if raw.has_prefix("\"") &&
    raw.has_suffix("\"") &&
    raw.char_length() >= 2 {
    raw.view(start_offset=1, end_offset=raw.char_length() - 1).to_owned()
  } else {
    raw
  }
  let path = if unquoted.has_prefix("b/") || unquoted.has_prefix("a/") {
    unquoted.view(start_offset=2).to_owned()
  } else {
    unquoted
  }
  let normalized = normalize_diff_path(path)
  if normalized.is_empty() {
    None
  } else {
    Some(normalized)
  }
}

///|
fn parse_new_line_start(header : String) -> Int? {
  let plus = match header.find("+") {
    Some(index) => index
    None => return None
  }
  let mut index = plus + 1
  let mut value = 0
  let mut digits = 0
  while index < header.char_length() {
    match header.get_char(index) {
      Some(c) if c >= '0' && c <= '9' => {
        value = value * 10 + (c.to_int() - '0'.to_int())
        digits = digits + 1
        index = index + 1
      }
      _ => break
    }
  }
  if digits == 0 {
    None
  } else {
    Some(value)
  }
}

///|
fn add_changed_line(
  files : Array[ChangedFile],
  path : String,
  line : Int,
) -> Unit {
  for file in files {
    if file.path == path {
      if !file.lines.contains(line) {
        file.lines.push(line)
      }
      return
    }
  }
  files.push({ path, lines: [line], })
}

///|
/// Parse a unified diff and collect added line numbers in the new files.
pub fn parse_unified_diff(patch : String) -> DiffFilter raise DiffParseError {
  let files : Array[ChangedFile] = []
  let lines = patch.split("\n").to_array()
  let mut current_path : String? = None
  let mut new_line = 0
  let mut in_hunk = false
  let mut saw_file_header = false
  let mut saw_content = false
  for raw in lines {
    let line = raw.to_owned()
    if line.is_empty() {
      continue
    }
    saw_content = true
    if line.has_prefix("diff --git ") {
      current_path = None
      in_hunk = false
      new_line = 0
    } else if line.has_prefix("+++ ") {
      current_path = parse_patch_path(line.view(start_offset=4).to_owned())
      in_hunk = false
      new_line = 0
      saw_file_header = true
    } else if line.has_prefix("@@ ") {
      new_line = match parse_new_line_start(line) {
        Some(value) => value
        None => raise DiffParseError("invalid hunk header: \{line}")
      }
      if current_path is None && new_line > 0 {
        raise DiffParseError("hunk encountered before a new-file header")
      }
      in_hunk = true
    } else if in_hunk {
      if line.has_prefix("+") {
        match current_path {
          Some(path) if new_line > 0 => add_changed_line(files, path, new_line)
          _ => ()
        }
        new_line = new_line + 1
      } else if line.has_prefix("-") {
        ()
      } else if line.has_prefix(" ") {
        new_line = new_line + 1
      } else if line.has_prefix("\\") {
        ()
      } else {
        in_hunk = false
      }
    }
  }
  if saw_content && !saw_file_header {
    raise DiffParseError("input does not contain a unified diff file header")
  }
  { files, }
}

///|
/// Check whether an added line is present in the diff.
pub fn DiffFilter::includes(
  self : DiffFilter,
  path : String,
  line : Int,
) -> Bool {
  let normalized = normalize_diff_path(path)
  for file in self.files {
    let target = file.path
    if (normalized == target || normalized.has_suffix("/" + target)) &&
      file.lines.contains(line) {
      return true
    }
  }
  false
}

///|
/// Keep only findings located on lines added by the diff.
pub fn filter_findings(
  findings : Array[Finding],
  filter : DiffFilter,
) -> Array[Finding] {
  findings
  .iter()
  .filter(finding => filter.includes(finding.path, finding.line))
  .collect()
}
