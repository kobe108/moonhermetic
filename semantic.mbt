///|
priv struct SemanticUnit {
  name : String
  start_line : Int
  end_line : Int
}

///|
priv struct SemanticModel {
  tests : Array[SemanticUnit]
  functions : Array[SemanticUnit]
}

///|
fn semantic_identifier_start(value : Char) -> Bool {
  (value >= 'a' && value <= 'z') ||
  (value >= 'A' && value <= 'Z') ||
  value == '_'
}

///|
fn semantic_identifier_char(value : Char) -> Bool {
  semantic_identifier_start(value) || (value >= '0' && value <= '9')
}

///|
fn semantic_strip_prefixes(value : String, prefixes : Array[String]) -> String? {
  for prefix in prefixes {
    if value.strip_prefix(prefix) is Some(rest) {
      return Some(rest.trim_start().to_owned())
    }
  }
  None
}

///|
fn semantic_test_name(raw_line : String) -> String? {
  let rest = match
    semantic_strip_prefixes(raw_line.trim_start().to_owned(), [
      "pub async test ", "async test ", "pub test ", "test ",
    ]) {
    Some(rest) => rest
    None => return None
  }
  if rest.has_prefix("\"") {
    let name = rest.exact_view(start=1)
    match name.find("\"") {
      Some(index) => Some(name.exact_view(end=index).to_owned())
      None => Some("<unnamed-test>")
    }
  } else if rest.has_prefix("{") {
    Some("<anonymous-test>")
  } else {
    Some("<unnamed-test>")
  }
}

///|
fn semantic_function_name(code_line : String) -> String? {
  let rest = match
    semantic_strip_prefixes(code_line.trim_start().to_owned(), [
      "pub async fn ", "priv async fn ", "async fn ", "pub fn ", "priv fn ", "fn ",
    ]) {
    Some(rest) => rest
    None => return None
  }
  let chars = rest.to_array()
  if chars.is_empty() || !semantic_identifier_start(chars[0]) {
    return None
  }
  let mut end = 1
  while end < chars.length() && semantic_identifier_char(chars[end]) {
    end = end + 1
  }
  Some(rest.exact_view(end~).to_owned())
}

///|
fn semantic_body_end(code_lines : Array[StringView], start_line : Int) -> Int? {
  let mut depth = 0
  let mut started = false
  for line_index = start_line
      line_index < code_lines.length()
      line_index = line_index + 1 {
    for current in code_lines[line_index].to_array() {
      if current == '{' {
        depth = depth + 1
        started = true
      } else if current == '}' && started {
        depth = depth - 1
        if depth == 0 {
          return Some(line_index)
        }
      }
    }
  }
  None
}

///|
fn parse_semantic_model(
  raw_lines : Array[StringView],
  code_lines : Array[StringView],
) -> SemanticModel {
  let tests : Array[SemanticUnit] = []
  let functions : Array[SemanticUnit] = []
  for line_index = 0
      line_index < code_lines.length()
      line_index = line_index + 1 {
    let raw_line = raw_lines[line_index].to_owned()
    let code_line = code_lines[line_index].to_owned()
    if semantic_test_name(code_line) is Some(_) &&
      semantic_test_name(raw_line) is Some(name) {
      if semantic_body_end(code_lines, line_index) is Some(end_line) {
        tests.push({ name, start_line: line_index, end_line, })
      }
    }
    if semantic_function_name(code_line) is Some(name) {
      if semantic_body_end(code_lines, line_index) is Some(end_line) {
        functions.push({ name, start_line: line_index, end_line, })
      }
    }
  }
  { tests, functions, }
}

///|
fn semantic_calls_in_unit(
  unit : SemanticUnit,
  code_lines : Array[StringView],
  function_names : Array[String],
) -> Array[String] {
  let calls : Array[String] = []
  for line_index = unit.start_line
      line_index <= unit.end_line
      line_index = line_index + 1 {
    let code_line = mask_declaration_name(code_lines[line_index].to_owned())
    let chars = code_line.to_array()
    let mut index = 0
    while index < chars.length() {
      if !semantic_identifier_start(chars[index]) {
        index = index + 1
        continue
      }
      let previous = if index == 0 { None } else { Some(chars[index - 1]) }
      let mut end = index + 1
      while end < chars.length() && semantic_identifier_char(chars[end]) {
        end = end + 1
      }
      let mut after = end
      while after < chars.length() &&
            (chars[after] == ' ' || chars[after] == '\t') {
        after = after + 1
      }
      let qualified = match previous {
        Some(value) => value == '.' || value == '@' || value == ':'
        None => false
      }
      if !qualified && after < chars.length() && chars[after] == '(' {
        let name = code_line.exact_view(start=index, end~).to_owned()
        if function_names.contains(name) && !calls.contains(name) {
          calls.push(name)
        }
      }
      index = end
    }
  }
  calls
}

///|
fn copy_call_path(path : Array[String]) -> Array[String] {
  let copied : Array[String] = []
  for item in path {
    copied.push(item)
  }
  copied
}

///|
fn semantic_findings_in_unit(
  path : String,
  unit : SemanticUnit,
  raw_lines : Array[StringView],
  code_lines : Array[StringView],
  options : ScanOptions,
  today : String?,
  test_name : String,
  call_path : Array[String],
) -> Array[Finding] {
  let findings : Array[Finding] = []
  for line_index = unit.start_line
      line_index <= unit.end_line
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
        if resolve_severity(rule, options) is Some(severity) &&
          !is_suppressed(rule, raw_line, previous_line, today) {
          findings.push({
            path,
            line: line_index + 1,
            column: column + 1,
            rule,
            severity,
            evidence: raw_line.trim().to_owned(),
            test_name: Some(test_name),
            call_path: copy_call_path(call_path),
          })
        }
      }
    }
  }
  findings
}

///|
fn semantic_trace_function(
  path : String,
  function : SemanticUnit,
  model : SemanticModel,
  function_names : Array[String],
  raw_lines : Array[StringView],
  code_lines : Array[StringView],
  options : ScanOptions,
  today : String?,
  test_name : String,
  call_path : Array[String],
  visited : Array[String],
  findings : Array[Finding],
) -> Unit {
  if visited.contains(function.name) {
    return
  }
  visited.push(function.name)
  for
    finding in semantic_findings_in_unit(
      path, function, raw_lines, code_lines, options, today, test_name, call_path,
    ) {
    findings.push(finding)
  }
  for
    called_name in semantic_calls_in_unit(function, code_lines, function_names) {
    for called in model.functions {
      if called.name == called_name {
        let next_path = copy_call_path(call_path)
        next_path.push(called.name)
        semantic_trace_function(
          path, called, model, function_names, raw_lines, code_lines, options, today,
          test_name, next_path, visited, findings,
        )
      }
    }
  }
}

///|
fn semantic_scan_source(
  path : String,
  source : String,
  options : ScanOptions,
  today : String?,
) -> Array[Finding] {
  let masked = mask_source(source)
  let raw_lines = source.split("\n").to_array()
  let code_lines = masked.split("\n").to_array()
  let model = parse_semantic_model(raw_lines, code_lines)
  let function_names = model.functions.map(function => function.name)
  let findings : Array[Finding] = []
  for test_unit in model.tests {
    let root_path : Array[String] = [test_unit.name]
    for
      finding in semantic_findings_in_unit(
        path,
        test_unit,
        raw_lines,
        code_lines,
        options,
        today,
        test_unit.name,
        root_path,
      ) {
      findings.push(finding)
    }
    let visited : Array[String] = []
    for
      called_name in semantic_calls_in_unit(
        test_unit, code_lines, function_names,
      ) {
      for function in model.functions {
        if function.name == called_name {
          let call_path : Array[String] = [test_unit.name, function.name]
          semantic_trace_function(
            path,
            function,
            model,
            function_names,
            raw_lines,
            code_lines,
            options,
            today,
            test_unit.name,
            call_path,
            visited,
            findings,
          )
        }
      }
    }
  }
  findings.sort_by((left, right) => {
    let line_order = left.line - right.line
    if line_order != 0 {
      line_order
    } else {
      left.column - right.column
    }
  })
  findings
}

///|
/// Scan with test reachability semantics and the default rule policy.
pub fn scan_source_semantically(
  path : String,
  source : String,
) -> Array[Finding] {
  semantic_scan_source(path, source, default_scan_options(), None)
}

///|
/// Scan with test reachability, rule overrides, and a UTC reference date.
pub fn scan_source_semantically_with_options_and_date(
  path : String,
  source : String,
  options : ScanOptions,
  today : String,
) -> Array[Finding] {
  semantic_scan_source(path, source, options, Some(today))
}
