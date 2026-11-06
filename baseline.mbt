///|
pub(all) suberror BaselineError {
  BaselineError(String)
}

///|
pub(all) struct BaselineEntry {
  fingerprint : String
  rule_id : String
  path : String
  evidence : String
  count : Int
}

///|
pub(all) struct Baseline {
  created_on : String
  created_with : String
  entries : Array[BaselineEntry]
}

///|
pub(all) struct BaselineFilterResult {
  findings : Array[Finding]
  suppressed_count : Int
  stale_count : Int
}

///|
fn baseline_error(message : String) -> BaselineError {
  BaselineError(message)
}

///|
fn normalize_baseline_path(value : String) -> String {
  let normalized = value.replace_all(old="\\", new="/")
  if normalized.has_prefix("./") {
    normalized.exact_view(start=2).to_owned()
  } else {
    normalized
  }
}

///|
fn normalized_evidence(value : String) -> String {
  let chars = value.to_array()
  let out : Array[Char] = []
  let mut pending_space = false
  let mut quote : Char? = None
  let mut escaped = false
  for current in chars {
    if quote is Some(mark) {
      out.push(current)
      if escaped {
        escaped = false
      } else if current == '\\' {
        escaped = true
      } else if current == mark {
        quote = None
      }
    } else if current == '"' || current == '\'' {
      if pending_space &&
        out.length() > 0 &&
        !evidence_punctuation(out[out.length() - 1]) {
        out.push(' ')
      }
      pending_space = false
      quote = Some(current)
      out.push(current)
    } else if current == ' ' ||
      current == '\t' ||
      current == '\r' ||
      current == '\n' {
      if out.length() > 0 {
        pending_space = true
      }
    } else {
      if pending_space {
        let previous = out[out.length() - 1]
        if !evidence_punctuation(previous) && !evidence_punctuation(current) {
          out.push(' ')
        }
        pending_space = false
      }
      out.push(current)
    }
  }
  String::from_array(out)
}

///|
fn evidence_punctuation(value : Char) -> Bool {
  value == '(' ||
  value == ')' ||
  value == '[' ||
  value == ']' ||
  value == '{' ||
  value == '}' ||
  value == '<' ||
  value == '>' ||
  value == ',' ||
  value == ';' ||
  value == ':' ||
  value == '.' ||
  value == '=' ||
  value == '+' ||
  value == '-' ||
  value == '*' ||
  value == '/' ||
  value == '%' ||
  value == '&' ||
  value == '|' ||
  value == '!' ||
  value == '?'
}

///|
fn relative_baseline_path(path : String, root : String) -> String {
  let resolved_path = normalize_baseline_path(
    @path.Path(path).resolve().to_string(),
  )
  let resolved_root = normalize_baseline_path(
    @path.Path(root).resolve().to_string(),
  )
  if resolved_root == "/" && resolved_path.has_prefix("/") {
    return resolved_path.exact_view(start=1).to_owned()
  }
  let prefix = "\{resolved_root}/"
  if resolved_path.has_prefix(prefix) {
    resolved_path.exact_view(start=prefix.char_length()).to_owned()
  } else {
    resolved_path
  }
}

///|
/// Compute a SHA-256 identity that survives line and column movement.
///
/// The identity includes the rule, repository-relative path, and whitespace-
/// normalized evidence. Formatting-only changes therefore retain the same
/// fingerprint while changed operations become new findings.
pub fn finding_fingerprint(root : String, finding : Finding) -> String {
  let identity = "\{finding.rule.code()}\n" +
    "\{relative_baseline_path(finding.path, root)}\n" +
    normalized_evidence(finding.evidence)
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(identity)))
}

///|
pub fn create_baseline(
  findings : Array[Finding],
  root : String,
  created_on : String,
  created_with : String,
) -> Baseline {
  let entries : Array[BaselineEntry] = []
  for finding in findings {
    let fingerprint = finding_fingerprint(root, finding)
    let mut found = false
    for index = 0; index < entries.length(); index = index + 1 {
      if entries[index].fingerprint == fingerprint {
        entries[index] = { ..entries[index], count: entries[index].count + 1, }
        found = true
        break
      }
    }
    if !found {
      entries.push({
        fingerprint,
        rule_id: finding.rule.code(),
        path: relative_baseline_path(finding.path, root),
        evidence: normalized_evidence(finding.evidence),
        count: 1,
      })
    }
  }
  { created_on, created_with, entries, }
}

///|
fn valid_fingerprint(value : String) -> Bool {
  if value.char_length() != 64 {
    return false
  }
  for current in value.to_array() {
    let valid = (current >= '0' && current <= '9') ||
      (current >= 'a' && current <= 'f') ||
      (current >= 'A' && current <= 'F')
    if !valid {
      return false
    }
  }
  true
}

///|
fn validate_baseline_relative_path(value : String) -> Bool {
  if value.is_empty() ||
    value.has_prefix("/") ||
    value.contains("..") ||
    (
      value.get_char(1) == Some(':') &&
      value.get_char(0) is Some(first) &&
      first >= 'A' &&
      first <= 'Z'
    ) ||
    (
      value.get_char(1) == Some(':') &&
      value.get_char(0) is Some(first) &&
      first >= 'a' &&
      first <= 'z'
    ) {
    return false
  }
  true
}

///|
fn baseline_entry_to_json(entry : BaselineEntry) -> Json {
  Json::object({
    "fingerprint": Json::string(entry.fingerprint),
    "ruleId": Json::string(entry.rule_id),
    "path": Json::string(entry.path),
    "evidence": Json::string(entry.evidence),
    "count": Json::number(entry.count.to_double()),
  })
}

///|
pub fn render_baseline_json(baseline : Baseline) -> String {
  Json::object({
    "schema": Json::string("moonhermetic/baseline-v1"),
    "createdOn": Json::string(baseline.created_on),
    "createdWith": Json::string(baseline.created_with),
    "findings": Json::array(baseline.entries.map(baseline_entry_to_json)),
  }).stringify(indent=2)
}

///|
pub fn parse_baseline(text : String) -> Baseline raise BaselineError {
  let parsed = @json.parse(text) catch {
    _ => raise baseline_error("baseline is not valid JSON")
  }
  let root = match parsed {
    Json::Object(root) => root
    _ => raise baseline_error("baseline root must be an object")
  }
  for key, _ in root {
    match key {
      "schema" | "createdOn" | "createdWith" | "findings" => ()
      _ => raise baseline_error("unknown baseline field '\{key}'")
    }
  }
  let schema = match root.get("schema") {
    Some(Json::String(value)) => value
    _ => raise baseline_error("baseline schema must be a string")
  }
  if schema != "moonhermetic/baseline-v1" {
    raise baseline_error("unsupported baseline schema '\{schema}'")
  }
  let created_on = match root.get("createdOn") {
    Some(Json::String(value)) if valid_iso_date(value) => value
    _ => raise baseline_error("baseline createdOn must be YYYY-MM-DD")
  }
  let created_with = match root.get("createdWith") {
    Some(Json::String(value)) if !value.is_empty() => value
    _ => raise baseline_error("baseline createdWith must be a non-empty string")
  }
  let items = match root.get("findings") {
    Some(Json::Array(items)) => items
    _ => raise baseline_error("baseline findings must be an array")
  }
  let entries : Array[BaselineEntry] = []
  for item in items {
    let fields = match item {
      Json::Object(fields) => fields
      _ => raise baseline_error("baseline finding must be an object")
    }
    for key, _ in fields {
      match key {
        "fingerprint" | "ruleId" | "path" | "evidence" | "count" => ()
        _ => raise baseline_error("unknown baseline finding field '\{key}'")
      }
    }
    let fingerprint = match fields.get("fingerprint") {
      Some(Json::String(value)) if valid_fingerprint(value) => value
      _ =>
        raise baseline_error("baseline fingerprint must be 64 hex characters")
    }
    if entries.any(entry => entry.fingerprint == fingerprint) {
      raise baseline_error("duplicate baseline fingerprint '\{fingerprint}'")
    }
    let rule_id = match fields.get("ruleId") {
      Some(Json::String(value)) if RuleKind::from_code(value) is Some(_) =>
        RuleKind::from_code(value).unwrap().code()
      _ => raise baseline_error("baseline ruleId is not a known rule")
    }
    let path = match fields.get("path") {
      Some(Json::String(value)) if validate_baseline_relative_path(value) =>
        normalize_baseline_path(value)
      _ => raise baseline_error("baseline path must be a safe relative path")
    }
    let evidence = match fields.get("evidence") {
      Some(Json::String(value)) => normalized_evidence(value)
      _ => raise baseline_error("baseline evidence must be a string")
    }
    let count = match fields.get("count") {
      Some(Json::Number(value, ..)) => {
        let count = value.to_int()
        if count <= 0 || count.to_double() != value {
          raise baseline_error("baseline count must be a positive integer")
        }
        count
      }
      _ => raise baseline_error("baseline count must be a positive integer")
    }
    entries.push({ fingerprint, rule_id, path, evidence, count, })
  }
  { created_on, created_with, entries, }
}

///|
pub fn filter_with_baseline(
  findings : Array[Finding],
  baseline : Baseline,
  root : String,
) -> BaselineFilterResult {
  let remaining : Array[Int] = baseline.entries.map(entry => entry.count)
  let kept : Array[Finding] = []
  let mut suppressed = 0
  for finding in findings {
    let fingerprint = finding_fingerprint(root, finding)
    let mut match_index = -1
    for index = 0; index < baseline.entries.length(); index = index + 1 {
      if baseline.entries[index].fingerprint == fingerprint &&
        remaining[index] > 0 {
        match_index = index
        break
      }
    }
    if match_index >= 0 {
      remaining[match_index] = remaining[match_index] - 1
      suppressed = suppressed + 1
    } else {
      kept.push(finding)
    }
  }
  let mut stale = 0
  for count in remaining {
    stale = stale + count
  }
  { findings: kept, suppressed_count: suppressed, stale_count: stale, }
}
