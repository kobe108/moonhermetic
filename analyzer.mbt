///|
/// Mask comments and literals while preserving newlines and character offsets.
///
/// The analyzer then searches only source-like text, so documentation or an
/// expectation string mentioning `sleep(` does not become a false finding.
fn mask_source(source : String) -> String {
  let input = source.to_array()
  let output = Array::make(input.length(), ' ')
  let mut i = 0
  while i < input.length() {
    let c = input[i]
    if c == '\n' || c == '\r' {
      output[i] = c
      i = i + 1
    } else if c == '/' && i + 1 < input.length() && input[i + 1] == '/' {
      while i < input.length() && input[i] != '\n' {
        i = i + 1
      }
    } else if c == '/' && i + 1 < input.length() && input[i + 1] == '*' {
      output[i] = ' '
      output[i + 1] = ' '
      i = i + 2
      let mut depth = 1
      while i < input.length() && depth > 0 {
        if input[i] == '\n' || input[i] == '\r' {
          output[i] = input[i]
          i = i + 1
        } else if input[i] == '/' &&
          i + 1 < input.length() &&
          input[i + 1] == '*' {
          depth = depth + 1
          output[i] = ' '
          output[i + 1] = ' '
          i = i + 2
        } else if input[i] == '*' &&
          i + 1 < input.length() &&
          input[i + 1] == '/' {
          depth = depth - 1
          output[i] = ' '
          output[i + 1] = ' '
          i = i + 2
        } else {
          output[i] = ' '
          i = i + 1
        }
      }
    } else if c == '"' || c == '\'' {
      let quote = c
      output[i] = ' '
      i = i + 1
      let mut escaped = false
      while i < input.length() && input[i] != '\n' {
        let current = input[i]
        output[i] = ' '
        i = i + 1
        if escaped {
          escaped = false
        } else if current == '\\' {
          escaped = true
        } else if current == quote {
          break
        }
      }
    } else if c == '#' && i + 1 < input.length() && input[i + 1] == '|' {
      output[i] = ' '
      output[i + 1] = ' '
      i = i + 2
      while i < input.length() && input[i] != '\n' {
        output[i] = ' '
        i = i + 1
      }
    } else {
      output[i] = c
      i = i + 1
    }
  }
  String::from_array(output)
}

///|
fn patterns_for(rule : RuleKind) -> Array[String] {
  match rule {
    Clock =>
      [
        "@env.now(", "@time.now(", ".now(", "current_time(", "localtime(", "today(",
      ]
    Random =>
      [
        "@random.", "@env.rand(", ".random(", "rand(", "random_byte(", "random_bytes(",
        "random_bool(", "random_double(", "random_id(", "random_int(", "random_string(",
        "random_uint(", "random_uuid(",
      ]
    Environment =>
      [
        "@env.get_env_var(", "@env.get_env_vars(", "@env.set_env_var(", "@env.unset_env_var(",
        "getenv(", "process.env", "env_var(",
      ]
    Network =>
      [
        "@http.Client(", "@http.Server(", "@http.get_stream(", "@http.post(", "@http.post_stream(",
        "@http.put(", "@http.put_stream(", "@websocket.connect(", "@socket.Tcp::connect(",
        "@socket.TcpServer(", "@socket.UdpClient(", "@socket.UdpServer(", "@socket.Addr::resolve(",
        "http_get(", "http_post(", "fetch(", ".connect(", "listen(", "dns_",
      ]
    Process =>
      [
        "@process.run(", "@process.spawn(", "@process.collect_stdout(", "@shell.",
        "Command::new(", "exec(", "run_command(",
      ]
    Filesystem =>
      [
        "@fs.atime(", "@fs.can_execute(", "@fs.can_read(", "@fs.can_write(", "@fs.chmod(",
        "@fs.create(", "@fs.ctime(", "@fs.exists(", "@fs.kind(", "@fs.mkdir(", "@fs.mtime(",
        "@fs.open(", "@fs.opendir(", "@fs.rename(", "@fs.realpath(", "@fs.remove(",
        "@fs.remove_dir(", "@fs.remove_file(", "@fs.rmdir(", "@fs.symlink(", "@fs.tmpdir(",
        "@fs.walk(", "@fs.Watcher(", "@fs.read_dir(", "@fs.read_file(", "@fs.read_file_to_bytes(",
        "@fs.read_file_to_string(", "@fs.readdir(", "@fs.write_bytes_to_file(", "@fs.write_file(",
        "@fs.write_string_to_file(", "read_file(", "write_file(", "read_dir(", "path_exists(",
        "is_file(", "is_dir(", "File::open(",
      ]
    Sleep => ["sleep(", "delay(", "wait_until(", "Thread::sleep"]
  }
}

///|
pub fn rule_catalog() -> Array[RuleKind] {
  [Clock, Random, Environment, Network, Process, Filesystem, Sleep]
}

///|
fn is_identifier_char(value : Char) -> Bool {
  (value >= 'a' && value <= 'z') ||
  (value >= 'A' && value <= 'Z') ||
  (value >= '0' && value <= '9') ||
  value == '_'
}

///|
fn find_bounded_pattern(code : String, pattern : String) -> Int? {
  if pattern.is_empty() || !is_identifier_char(pattern.get_char(0).unwrap()) {
    return code.find(pattern)
  }
  let mut base = 0
  let mut remaining = code.view()
  while remaining.find(pattern) is Some(index) {
    let absolute = base + index
    if absolute == 0 ||
      (
        code.get_char(absolute - 1) is Some(previous) &&
        !is_identifier_char(previous)
      ) {
      return Some(absolute)
    }
    base = absolute + 1
    remaining = code.view(start_offset=base)
  }
  None
}

///|
fn first_pattern(code : String, rule : RuleKind) -> (String, Int)? {
  for pattern in patterns_for(rule) {
    if find_bounded_pattern(code, pattern) is Some(index) {
      return Some((pattern, index))
    }
  }
  None
}

///|
priv enum SuppressionScope {
  SameLine
  NextLine
}

///|
priv struct Suppression {
  scope : SuppressionScope
  rules : Array[RuleKind]
  owner : String?
  expires : String?
}

///|
fn line_comment(raw_line : String) -> String? {
  let chars = raw_line.to_array()
  let mut i = 0
  let mut quote : Char? = None
  let mut escaped = false
  while i + 1 < chars.length() {
    let current = chars[i]
    if quote is Some(mark) {
      if escaped {
        escaped = false
      } else if current == '\\' {
        escaped = true
      } else if current == mark {
        quote = None
      }
    } else if current == '"' || current == '\'' {
      quote = Some(current)
    } else if current == '/' && chars[i + 1] == '/' {
      return Some(raw_line.view(start_offset=i + 2).to_owned())
    }
    i = i + 1
  }
  None
}

///|
fn date_digit(value : String, index : Int) -> Int? {
  match value.get_char(index) {
    Some(c) if c >= '0' && c <= '9' => Some(c.to_int() - '0'.to_int())
    _ => None
  }
}

///|
fn valid_iso_date(value : String) -> Bool {
  if value.char_length() != 10 ||
    value.get_char(4) != Some('-') ||
    value.get_char(7) != Some('-') {
    return false
  }
  let digits = [0, 1, 2, 3, 5, 6, 8, 9]
  for index in digits {
    if date_digit(value, index) is None {
      return false
    }
  }
  let year = date_digit(value, 0).unwrap() * 1000 +
    date_digit(value, 1).unwrap() * 100 +
    date_digit(value, 2).unwrap() * 10 +
    date_digit(value, 3).unwrap()
  let month = date_digit(value, 5).unwrap() * 10 + date_digit(value, 6).unwrap()
  let day = date_digit(value, 8).unwrap() * 10 + date_digit(value, 9).unwrap()
  if year < 1970 || month < 1 || month > 12 || day < 1 {
    return false
  }
  let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  let limit = match month {
    2 => if leap { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
  day <= limit
}

///|
fn parse_suppression(raw_line : String) -> Suppression? {
  let comment = match line_comment(raw_line) {
    Some(comment) => comment.trim_start()
    None => return None
  }
  let (scope, after_marker) = if comment.strip_prefix("hermetic:ignore-next")
    is Some(rest) {
    (NextLine, rest)
  } else if comment.strip_prefix("hermetic:ignore") is Some(rest) {
    (SameLine, rest)
  } else {
    return None
  }
  let mut rest = after_marker.trim_start()
  if rest.has_prefix(":") {
    return Some({ scope, rules: [], owner: None, expires: None, })
  }
  let rules : Array[RuleKind] = []
  let mut owner : String? = None
  let mut expires : String? = None
  while !rest.is_empty() {
    let token = match rest.find_by(c => c == ' ' || c == '\t') {
      Some(index) => {
        let token = rest.view(end_offset=index).to_owned()
        rest = rest.view(start_offset=index + 1).trim_start()
        token
      }
      None => {
        let token = rest.to_owned()
        rest = ""
        token
      }
    }
    if token.has_prefix("owner=") {
      let value = token.view(start_offset=6).trim().to_owned()
      if value.is_empty() {
        return None
      }
      owner = Some(value)
    } else if token.has_prefix("expires=") {
      let value = token.view(start_offset=8).trim().to_owned()
      if !valid_iso_date(value) {
        return None
      }
      expires = Some(value)
    } else if token.has_prefix("reason=") {
      break
    } else {
      for rule_id in token.split(",") {
        let rule_id = rule_id.trim()
        if rule_id.is_empty() {
          continue
        }
        match RuleKind::from_code(rule_id.to_owned()) {
          Some(rule) => if !rules.contains(rule) { rules.push(rule) }
          None => return None
        }
      }
    }
  }
  match (rules.is_empty(), owner, expires) {
    (true, None, None) => Some({ scope, rules, owner: None, expires: None, })
    (_, Some(owner), Some(expires)) =>
      Some({ scope, rules, owner: Some(owner), expires: Some(expires), })
    _ => None
  }
}

///|
fn suppression_applies(
  suppression : Suppression,
  rule : RuleKind,
  today : String?,
) -> Bool {
  let rule_matches = suppression.rules.is_empty() ||
    suppression.rules.contains(rule)
  if !rule_matches {
    return false
  }
  match (suppression.owner, suppression.expires, today) {
    (None, None, _) => true
    (Some(_), Some(expires), Some(today)) =>
      valid_iso_date(today) && expires >= today
    _ => false
  }
}

///|
fn is_suppressed(
  rule : RuleKind,
  raw_line : String,
  previous_line : String,
  today : String?,
) -> Bool {
  if parse_suppression(raw_line) is Some(suppression) {
    if suppression.scope is SameLine &&
      suppression_applies(suppression, rule, today) {
      return true
    }
  }
  if parse_suppression(previous_line) is Some(suppression) {
    if suppression.scope is NextLine &&
      suppression_applies(suppression, rule, today) {
      return true
    }
  }
  false
}

///|
fn mask_declaration_name(code_line : String) -> String {
  let trimmed = code_line.trim_start()
  let declaration = trimmed.has_prefix("fn ") ||
    trimmed.has_prefix("async fn ") ||
    trimmed.has_prefix("pub fn ") ||
    trimmed.has_prefix("pub async fn ") ||
    trimmed.has_prefix("extern fn ")
  if declaration {
    match code_line.find("(") {
      Some(index) => {
        let chars = code_line.to_array()
        for i = 0; i < index; i = i + 1 {
          chars[i] = ' '
        }
        String::from_array(chars)
      }
      None => code_line
    }
  } else {
    code_line
  }
}

///|
/// Scan one MoonBit source file with the default rule policy.
pub fn scan_source(path : String, source : String) -> Array[Finding] {
  scan_source_with_options(path, source, default_scan_options())
}

///|
/// Scan one MoonBit source file with explicit rule overrides.
///
/// Expiring, scoped suppressions require the date-aware overload.
pub fn scan_source_with_options(
  path : String,
  source : String,
  options : ScanOptions,
) -> Array[Finding] {
  scan_source_internal(path, source, options, None)
}

///|
/// Scan with rule overrides and an ISO-8601 UTC date for expiry evaluation.
pub fn scan_source_with_options_and_date(
  path : String,
  source : String,
  options : ScanOptions,
  today : String,
) -> Array[Finding] {
  scan_source_internal(path, source, options, Some(today))
}

///|
fn scan_source_internal(
  path : String,
  source : String,
  options : ScanOptions,
  today : String?,
) -> Array[Finding] {
  let masked = mask_source(source)
  let raw_lines = source.split("\n").to_array()
  let code_lines = masked.split("\n").to_array()
  let findings : Array[Finding] = []
  for line_index = 0
      line_index < code_lines.length()
      line_index = line_index + 1 {
    let raw_line = raw_lines[line_index].to_owned()
    let previous_line = if line_index == 0 {
      ""
    } else {
      raw_lines[line_index - 1].to_owned()
    }
    let code_line = mask_declaration_name(code_lines[line_index].to_owned())
    for rule in rule_catalog() {
      if first_pattern(code_line, rule) is Some((_, column)) {
        if resolve_severity(rule, options) is Some(severity) {
          if !is_suppressed(rule, raw_line, previous_line, today) {
            findings.push({
              path,
              line: line_index + 1,
              column: column + 1,
              rule,
              severity,
              evidence: raw_line.trim().to_owned(),
            })
          }
        }
      }
    }
  }
  findings
}

///|
/// Build an aggregate report from findings collected by the CLI.
pub fn make_report(
  scanned_files : Int,
  findings : Array[Finding],
) -> ScanReport {
  { scanned_files, findings, filtered_out: 0, }
}

///|
/// Build a report after diff-aware filtering.
pub fn make_filtered_report(
  scanned_files : Int,
  findings : Array[Finding],
  filtered_out : Int,
) -> ScanReport {
  { scanned_files, findings, filtered_out, }
}

///|
pub fn count_by_severity(report : ScanReport, severity : Severity) -> Int {
  report.findings.iter().filter(finding => finding.severity == severity).count()
}

///|
pub fn should_fail(report : ScanReport, fail_on : Severity) -> Bool {
  match fail_on {
    Warning => report.findings.length() > 0
    Error => report.findings.any(finding => finding.severity == Error)
  }
}

///|
/// Markdown catalog for documentation and `--rules` output.
pub fn rule_catalog_markdown() -> String {
  let out = StringBuilder()
  out.write_string("| Rule | Severity | Meaning | Suggested fix |\n")
  out.write_string("|---|---|---|---|\n")
  for rule in rule_catalog() {
    out.write_string(
      "| `\{rule.code()}` | \{default_severity(rule).to_string()} " +
      "| \{rule.message()} | \{rule.remediation()} |\n",
    )
  }
  out.to_string()
}
