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
priv struct SemanticFile {
  path : String
  package_path : String
  raw_lines : Array[String]
  code_lines : Array[String]
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
fn semantic_body_end(code_lines : Array[String], start_line : Int) -> Int? {
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
  raw_lines : Array[String],
  code_lines : Array[String],
) -> SemanticModel {
  let tests : Array[SemanticUnit] = []
  let functions : Array[SemanticUnit] = []
  for line_index = 0
      line_index < code_lines.length()
      line_index = line_index + 1 {
    let raw_line = raw_lines[line_index]
    let code_line = code_lines[line_index]
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
  code_lines : Array[String],
  function_names : Array[String],
) -> Array[String] {
  let calls : Array[String] = []
  for line_index = unit.start_line
      line_index <= unit.end_line
      line_index = line_index + 1 {
    let code_line = mask_declaration_name(code_lines[line_index])
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
  raw_lines : Array[String],
  code_lines : Array[String],
  options : ScanOptions,
  today : String?,
  test_name : String,
  call_path : Array[String],
) -> Array[Finding] {
  let findings : Array[Finding] = []
  for line_index = unit.start_line
      line_index <= unit.end_line
      line_index = line_index + 1 {
    let raw_line = raw_lines[line_index]
    let previous_line = if line_index == 0 {
      ""
    } else {
      raw_lines[line_index - 1]
    }
    let code_line = mask_declaration_name(code_lines[line_index])
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
fn semantic_source_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  for line in source.split("\n") {
    lines.push(line.to_owned())
  }
  lines
}

///|
fn semantic_package(path : String) -> String {
  let normalized = path.replace_all(old="\\", new="/")
  let chars = normalized.to_array()
  let mut last_slash : Int? = None
  for index = 0; index < chars.length(); index = index + 1 {
    if chars[index] == '/' {
      last_slash = Some(index)
    }
  }
  match last_slash {
    Some(index) => normalized.exact_view(end=index).to_owned()
    None => "."
  }
}

///|
fn semantic_file(path : String, source : String) -> SemanticFile {
  let raw_lines = semantic_source_lines(source)
  let code_lines = semantic_source_lines(mask_source(source))
  let model = parse_semantic_model(raw_lines, code_lines)
  {
    path,
    package_path: semantic_package(path),
    raw_lines,
    code_lines,
    tests: model.tests,
    functions: model.functions,
  }
}

///|
fn semantic_find_function(
  models : Array[SemanticFile],
  package_path : String,
  name : String,
) -> (Int, SemanticUnit)? {
  for model_index = 0
      model_index < models.length()
      model_index = model_index + 1 {
    if models[model_index].package_path == package_path {
      for function in models[model_index].functions {
        if function.name == name {
          return Some((model_index, function))
        }
      }
    }
  }
  None
}

///|
fn semantic_function_names(
  models : Array[SemanticFile],
  package_path : String,
) -> Array[String] {
  let names : Array[String] = []
  for model in models {
    if model.package_path == package_path {
      for function in model.functions {
        if !names.contains(function.name) {
          names.push(function.name)
        }
      }
    }
  }
  names
}

///|
fn semantic_trace_function(
  model_index : Int,
  function : SemanticUnit,
  package_path : String,
  models : Array[SemanticFile],
  function_names : Array[String],
  options : ScanOptions,
  today : String?,
  test_name : String,
  call_path : Array[String],
  visited : Array[String],
  findings : Array[Finding],
) -> Unit {
  let model = models[model_index]
  let visit_key = model.path + "::" + function.name
  if visited.contains(visit_key) {
    return
  }
  visited.push(visit_key)
  for
    finding in semantic_findings_in_unit(
      model.path,
      function,
      model.raw_lines,
      model.code_lines,
      options,
      today,
      test_name,
      call_path,
    ) {
    findings.push(finding)
  }
  for
    called_name in semantic_calls_in_unit(
      function,
      model.code_lines,
      function_names,
    ) {
    match semantic_find_function(models, package_path, called_name) {
      Some((called_model_index, called)) => {
        let next_path = copy_call_path(call_path)
        next_path.push(called.name)
        semantic_trace_function(
          called_model_index, called, package_path, models, function_names, options,
          today, test_name, next_path, visited, findings,
        )
      }
      None => ()
    }
  }
}

///|
fn semantic_scan_sources(
  sources : Array[(String, String)],
  options : ScanOptions,
  today : String?,
) -> Array[Finding] {
  let models : Array[SemanticFile] = []
  let seen_paths : Array[String] = []
  for pair in sources {
    let path = pair.0
    let source = pair.1
    if !seen_paths.contains(path) {
      seen_paths.push(path)
      models.push(semantic_file(path, source))
    }
  }
  let findings : Array[Finding] = []
  for model_index = 0
      model_index < models.length()
      model_index = model_index + 1 {
    let model = models[model_index]
    let function_names = semantic_function_names(models, model.package_path)
    for test_unit in model.tests {
      let root_path : Array[String] = [test_unit.name]
      for
        finding in semantic_findings_in_unit(
          model.path,
          test_unit,
          model.raw_lines,
          model.code_lines,
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
          test_unit,
          model.code_lines,
          function_names,
        ) {
        match semantic_find_function(models, model.package_path, called_name) {
          Some((called_model_index, function)) => {
            let call_path : Array[String] = [test_unit.name, function.name]
            semantic_trace_function(
              called_model_index,
              function,
              model.package_path,
              models,
              function_names,
              options,
              today,
              test_unit.name,
              call_path,
              visited,
              findings,
            )
          }
          None => ()
        }
      }
    }
  }
  findings.sort_by((left, right) => {
    let path_order = left.path.compare(right.path)
    if path_order != 0 {
      path_order
    } else {
      let line_order = left.line - right.line
      if line_order != 0 {
        line_order
      } else {
        left.column - right.column
      }
    }
  })
  findings
}

///|
fn semantic_scan_source(
  path : String,
  source : String,
  options : ScanOptions,
  today : String?,
) -> Array[Finding] {
  semantic_scan_sources([(path, source)], options, today)
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

///|
/// Scan a MoonBit package across files while tracing only test-reachable code.
pub fn scan_sources_semantically(
  sources : Array[(String, String)],
) -> Array[Finding] {
  semantic_scan_sources(sources, default_scan_options(), None)
}

///|
/// Cross-file semantic scan with rule overrides and a UTC reference date.
pub fn scan_sources_semantically_with_options_and_date(
  sources : Array[(String, String)],
  options : ScanOptions,
  today : String,
) -> Array[Finding] {
  semantic_scan_sources(sources, options, Some(today))
}
