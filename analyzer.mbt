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
    Random => ["@random.", "@env.rand(", ".random(", "random_", "rand("]
    Environment =>
      [
        "@env.get_env_var(", "@env.get_env_vars(", "getenv(", "process.env", "env_var(",
      ]
    Network =>
      [
        "@http.", "http_get(", "http_post(", "fetch(", "@socket.", ".connect(", "listen(",
        "dns_",
      ]
    Process =>
      [
        "@process.", "@shell.", "Command::new(", "exec(", "spawn(", "run_command(",
      ]
    Filesystem =>
      [
        "@fs.", "read_file", "write_file", "read_dir(", "path_exists(", "is_file(",
        "is_dir(", "File::open(",
      ]
    Sleep => ["sleep(", "delay(", "wait_until(", "Thread::sleep"]
  }
}

///|
pub fn rule_catalog() -> Array[RuleKind] {
  [Clock, Random, Environment, Network, Process, Filesystem, Sleep]
}

///|
fn first_pattern(code : String, rule : RuleKind) -> (String, Int)? {
  for pattern in patterns_for(rule) {
    if code.find(pattern) is Some(index) {
      return Some((pattern, index))
    }
  }
  None
}

///|
fn is_ignored(raw_line : String, previous_line : String) -> Bool {
  raw_line.contains("hermetic:ignore") ||
  previous_line.contains("hermetic:ignore-next")
}

///|
fn is_function_declaration(code_line : String) -> Bool {
  let trimmed = code_line.trim_start()
  trimmed.has_prefix("fn ") ||
  trimmed.has_prefix("async fn ") ||
  trimmed.has_prefix("pub fn ") ||
  trimmed.has_prefix("extern fn ")
}

///|
/// Scan one MoonBit source file. Paths are only used in the report.
///
/// A finding can be suppressed on its line with `// hermetic:ignore`. The
/// directive `// hermetic:ignore-next` suppresses every finding on the next
/// line.
pub fn scan_source(path : String, source : String) -> Array[Finding] {
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
    if !is_ignored(raw_line, previous_line) {
      let code_line = code_lines[line_index].to_owned()
      if !is_function_declaration(code_line) {
        for rule in rule_catalog() {
          if first_pattern(code_line, rule) is Some((_, column)) {
            findings.push({
              path,
              line: line_index + 1,
              column: column + 1,
              rule,
              severity: default_severity(rule),
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
  { scanned_files, findings, }
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
