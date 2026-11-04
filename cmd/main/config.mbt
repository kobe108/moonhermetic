///|
priv suberror ConfigError {
  ConfigError(String)
}

///|
priv struct ProjectConfig {
  fail_on : String?
  excludes : Array[String]
  options : @lib.ScanOptions
}

///|
fn default_project_config() -> ProjectConfig {
  { fail_on: None, excludes: [], options: @lib.default_scan_options(), }
}

///|
fn[T] config_fail(path : String, message : String) -> T raise ConfigError {
  raise ConfigError("invalid config '\{path}': \{message}")
}

///|
fn parse_fail_on(path : String, value : String) -> String raise ConfigError {
  match value.trim().to_lower() {
    "never" | "warning" | "error" => value.trim().to_lower().to_owned()
    _ => config_fail(path, "'failOn' must be one of never, warning, or error")
  }
}

///|
fn parse_rule_policy(
  path : String,
  rule_id : String,
  value : Json,
) -> @lib.RuleOverride raise ConfigError {
  let rule = match @lib.RuleKind::from_code(rule_id) {
    Some(rule) => rule
    None => config_fail(path, "unknown rule ID '\{rule_id}'")
  }
  let severity = match value {
    Json::String(value) =>
      match value.trim().to_lower() {
        "off" => None
        "warning" | "warn" => Some(@lib.Warning)
        "error" => Some(@lib.Error)
        _ =>
          config_fail(path, "rule '\{rule_id}' must be off, warning, or error")
      }
    _ => config_fail(path, "rule '\{rule_id}' must be a string")
  }
  { rule, severity, }
}

///|
fn parse_config(
  path : String,
  text : String,
) -> ProjectConfig raise ConfigError {
  let parsed = @json.parse(text) catch {
    _ => config_fail(path, "file is not valid JSON")
  }
  let root = match parsed {
    Json::Object(root) => root
    _ => config_fail(path, "top-level value must be an object")
  }
  for key, _ in root {
    match key {
      "version" | "failOn" | "exclude" | "rules" => ()
      _ => config_fail(path, "unknown top-level key '\{key}'")
    }
  }
  match root.get("version") {
    Some(Json::Number(version, ..)) =>
      if version != 1.0 {
        config_fail(path, "'version' must be 1")
      }
    Some(_) => config_fail(path, "'version' must be the number 1")
    None => ()
  }
  let fail_on = match root.get("failOn") {
    Some(Json::String(value)) => Some(parse_fail_on(path, value))
    Some(_) => config_fail(path, "'failOn' must be a string")
    None => None
  }
  let excludes : Array[String] = []
  match root.get("exclude") {
    Some(Json::Array(items)) =>
      for item in items {
        match item {
          Json::String(value) => {
            if value.trim().is_empty() {
              config_fail(path, "'exclude' cannot contain empty values")
            }
            if !excludes.contains(value) {
              excludes.push(value)
            }
          }
          _ => config_fail(path, "'exclude' must contain only strings")
        }
      }
    Some(_) => config_fail(path, "'exclude' must be an array")
    None => ()
  }
  let overrides : Array[@lib.RuleOverride] = []
  match root.get("rules") {
    Some(Json::Object(rules)) =>
      for rule_id, value in rules {
        let policy = parse_rule_policy(path, rule_id, value)
        if overrides.any(existing => existing.rule == policy.rule) {
          config_fail(path, "rule '\{rule_id}' is configured more than once")
        }
        overrides.push(policy)
      }
    Some(_) => config_fail(path, "'rules' must be an object")
    None => ()
  }
  { fail_on, excludes, options: { overrides, }, }
}

///|
fn load_project_config(
  path : String?,
  disabled : Bool,
) -> ProjectConfig raise ConfigError {
  if disabled {
    return default_project_config()
  }
  let config_path = match path {
    Some(path) => path
    None => ".moonhermetic.json"
  }
  if !@fs.path_exists(config_path) {
    if path is Some(_) {
      raise ConfigError("config file not found: '\{config_path}'")
    }
    return default_project_config()
  }
  let text = @fs.read_file_to_string(config_path) catch {
    @fs.IOError(message) =>
      raise ConfigError("cannot read config '\{config_path}': \{message}")
  }
  parse_config(config_path, text)
}
