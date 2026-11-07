///|
priv enum DoctorStatus {
  Pass
  Warn
  Error
}

///|
impl Eq for DoctorStatus with fn equal(self, other) {
  match (self, other) {
    (Pass, Pass) | (Warn, Warn) | (Error, Error) => true
    _ => false
  }
}

///|
fn DoctorStatus::to_string(self : DoctorStatus) -> String {
  match self {
    Pass => "pass"
    Warn => "warning"
    Error => "error"
  }
}

///|
priv struct DoctorCheck {
  name : String
  status : DoctorStatus
  message : String
  remediation : String?
}

///|
priv struct DoctorReport {
  strict : Bool
  checks : Array[DoctorCheck]
}

///|
priv struct DoctorOptions {
  target : String
  config_path : String?
  config_disabled : Bool
  baseline_path : String?
  baseline_disabled : Bool
  format : String
  strict : Bool
}

///|
let doctor_usage_text =
  #|Usage:
  #|  moonhermetic doctor [path] [options]
  #|
  #|Options:
  #|  --config <path>     Config to validate (default: .moonhermetic.json)
  #|  --no-config         Ignore project configuration
  #|  --baseline <path>   Explicit baseline to validate
  #|  --no-baseline       Ignore a baseline
  #|  --format <text|json>
  #|  --strict            Exit non-zero for warnings as well as errors
  #|  -h, --help          Show this help

///|
fn doctor_check(
  name : String,
  status : DoctorStatus,
  message : String,
  remediation : String?,
) -> DoctorCheck {
  { name, status, message, remediation, }
}

///|
fn parse_doctor_options(args : Array[String]) -> DoctorOptions {
  let mut target : String? = None
  let mut config_path : String? = None
  let mut config_disabled = false
  let mut baseline_path : String? = None
  let mut baseline_disabled = false
  let mut format = "text"
  let mut strict = false
  let mut index = 2
  while index < args.length() {
    let arg = args[index]
    match arg {
      "-h" | "--help" => {
        println(doctor_usage_text)
        @sys.exit(0)
      }
      "--config" => {
        config_path = Some(require_value(args, index, arg))
        index = index + 1
      }
      "--no-config" => config_disabled = true
      "--baseline" => {
        baseline_path = Some(require_value(args, index, arg))
        index = index + 1
      }
      "--no-baseline" => baseline_disabled = true
      "--format" => {
        let value = require_value(args, index, arg)
        match value {
          "text" | "json" => format = value
          _ => init_error("doctor format must be text or json")
        }
        index = index + 1
      }
      "--strict" => strict = true
      _ => {
        if arg.has_prefix("-") {
          init_error("unknown doctor option '\{arg}'")
        }
        if target is Some(_) {
          init_error("doctor accepts at most one target path")
        }
        target = Some(arg)
      }
    }
    index = index + 1
  }
  if config_disabled && config_path is Some(_) {
    init_error("--config cannot be combined with --no-config")
  }
  if baseline_disabled && baseline_path is Some(_) {
    init_error("--baseline cannot be combined with --no-baseline")
  }
  {
    target: match target {
      Some(value) => value
      None => "."
    },
    config_path,
    config_disabled,
    baseline_path,
    baseline_disabled,
    format,
    strict,
  }
}

///|
fn doctor_status_count(report : DoctorReport, status : DoctorStatus) -> Int {
  report.checks.iter().filter(check => check.status == status).count()
}

///|
fn doctor_should_fail(report : DoctorReport) -> Bool {
  doctor_status_count(report, Error) > 0 ||
  (report.strict && doctor_status_count(report, Warn) > 0)
}

///|
fn doctor_check_to_json(check : DoctorCheck) -> Json {
  Json::object({
    "name": Json::string(check.name),
    "status": Json::string(check.status.to_string()),
    "message": Json::string(check.message),
    "remediation": match check.remediation {
      Some(value) => Json::string(value)
      None => Json::null()
    },
  })
}

///|
fn render_doctor_text(report : DoctorReport) -> String {
  let out = StringBuilder()
  out.write_string("MoonHermetic doctor\n\n")
  for check in report.checks {
    out.write_string(
      "\{check.status.to_string().to_upper()}: \{check.name}: " +
      "\{check.message}\n",
    )
    if check.remediation is Some(value) {
      out.write_string("  next: \{value}\n")
    }
  }
  out.write_string(
    "\nSummary: \{doctor_status_count(report, Pass)} passed, " +
    "\{doctor_status_count(report, Warn)} warning(s), " +
    "\{doctor_status_count(report, Error)} error(s).\n",
  )
  out.to_string()
}

///|
fn render_doctor_json(report : DoctorReport) -> String {
  Json::object({
    "schema": Json::string("moonhermetic/doctor-v1"),
    "tool": Json::object({
      "name": Json::string("MoonHermetic"),
      "version": Json::string("0.14.0"),
    }),
    "summary": Json::object({
      "passed": Json::number(doctor_status_count(report, Pass).to_double()),
      "warnings": Json::number(doctor_status_count(report, Warn).to_double()),
      "errors": Json::number(doctor_status_count(report, Error).to_double()),
      "strict": Json::boolean(report.strict),
    }),
    "checks": Json::array(report.checks.map(doctor_check_to_json)),
  }).stringify(indent=2)
}

///|
fn doctor_load_config(
  options : DoctorOptions,
  checks : Array[DoctorCheck],
) -> ProjectConfig {
  if options.config_disabled {
    checks.push(
      doctor_check(
        "config",
        Warn,
        "Project configuration discovery is disabled.",
        Some("Remove --no-config to validate project policy."),
      ),
    )
    return default_project_config()
  }
  let path = match options.config_path {
    Some(path) => path
    None => ".moonhermetic.json"
  }
  let explicit = options.config_path is Some(_)
  if !@fs.path_exists(path) {
    if explicit {
      checks.push(
        doctor_check(
          "config",
          Error,
          "Configured file '\{path}' does not exist.",
          Some("Create it with 'moonhermetic init --config \{path}'."),
        ),
      )
    } else {
      checks.push(
        doctor_check(
          "config",
          Warn,
          "No project configuration found.",
          Some("Create one with 'moonhermetic init --no-baseline'."),
        ),
      )
    }
    return default_project_config()
  }
  let text = @fs.read_file_to_string(path) catch {
    @fs.IOError(message) => {
      checks.push(
        doctor_check("config", Error, "Cannot read '\{path}': \{message}", None),
      )
      return default_project_config()
    }
  }
  let config = parse_config(path, text) catch {
    ConfigError(message) => {
      checks.push(doctor_check("config", Error, message, None))
      return default_project_config()
    }
  }
  checks.push(
    doctor_check("config", Pass, "Configuration '\{path}' is valid.", None),
  )
  config
}

///|
fn doctor_check_baseline(
  path : String,
  findings : Array[@lib.Finding],
  checks : Array[DoctorCheck],
) -> Unit {
  if !@fs.path_exists(path) {
    checks.push(
      doctor_check(
        "baseline",
        Error,
        "Configured baseline '\{path}' does not exist.",
        Some("Create it with 'moonhermetic init --force'."),
      ),
    )
    return
  }
  let text = @fs.read_file_to_string(path) catch {
    @fs.IOError(message) => {
      checks.push(
        doctor_check(
          "baseline",
          Error,
          "Cannot read baseline '\{path}': \{message}",
          None,
        ),
      )
      return
    }
  }
  let baseline = @lib.parse_baseline(text) catch {
    @lib.BaselineError(message) => {
      checks.push(
        doctor_check(
          "baseline",
          Error,
          "Baseline '\{path}' is invalid: \{message}",
          Some("Regenerate it with 'moonhermetic init --force'."),
        ),
      )
      return
    }
  }
  let root = @path.Path(path).dirname().to_string()
  let result = @lib.filter_with_baseline(findings, baseline, root)
  if result.findings.length() > 0 {
    checks.push(
      doctor_check(
        "baseline",
        Warn,
        "\{result.findings.length()} new finding(s) are outside the baseline.",
        Some("Fix them or intentionally refresh the baseline."),
      ),
    )
  } else if result.stale_count > 0 {
    checks.push(
      doctor_check(
        "baseline",
        Warn,
        "Baseline is valid but contains \{result.stale_count} stale count(s).",
        Some("Refresh it with 'moonhermetic init --force'."),
      ),
    )
  } else {
    checks.push(
      doctor_check(
        "baseline",
        Pass,
        "Baseline is valid and current; " +
        "\{result.suppressed_count} finding(s) are accepted.",
        None,
      ),
    )
  }
}

///|
fn handle_doctor_args(args : Array[String]) -> Unit {
  if args.length() < 2 || args[1] != "doctor" {
    return
  }
  let options = parse_doctor_options(args)
  let checks : Array[DoctorCheck] = [
    doctor_check("tool", Pass, "MoonHermetic 0.14.0 is running.", None),
  ]
  if inspect_kind(options.target) == 0 {
    checks.push(
      doctor_check(
        "target",
        Error,
        "Target '\{options.target}' does not exist or cannot be inspected.",
        Some("Pass an existing file or directory."),
      ),
    )
    let report = { strict: options.strict, checks, }
    println(
      match options.format {
        "json" => render_doctor_json(report)
        _ => render_doctor_text(report)
      },
    )
    @sys.exit(1)
  }

  let config = doctor_load_config(options, checks)
  let files = []
  let seen_directories = []
  discover(options.target, files, config.excludes, seen_directories, 0)
  files.sort()
  if files.is_empty() {
    checks.push(
      doctor_check(
        "tests",
        Warn,
        "No MoonBit test files were found.",
        Some("Check the target path or add *_test.mbt / *_wbtest.mbt files."),
      ),
    )
  } else {
    checks.push(
      doctor_check(
        "tests",
        Pass,
        "Discovered \{files.length()} test file(s).",
        None,
      ),
    )
  }

  let scan_date = current_utc_date()
  let findings = []
  let audits = []
  for file in files {
    let source = @fs.read_file_to_string(file) catch {
      @fs.IOError(message) => {
        checks.push(
          doctor_check(
            "source",
            Error,
            "Cannot read '\{file}': \{message}",
            None,
          ),
        )
        continue
      }
    }
    for audit in @lib.audit_suppressions(file, source, scan_date) {
      audits.push(audit)
    }
    for
      finding in @lib.scan_source_with_options_and_date(
        file,
        source,
        config.options,
        scan_date,
      ) {
      findings.push(finding)
    }
  }

  let audit_report = @lib.make_suppression_audit_report(
    files.length(),
    scan_date,
    audits,
  )
  let expired = @lib.count_suppression_status(audit_report, @lib.Expired)
  let invalid = @lib.count_suppression_status(audit_report, @lib.Invalid)
  if expired > 0 || invalid > 0 {
    checks.push(
      doctor_check(
        "suppressions",
        Warn,
        "\{expired} expired and \{invalid} invalid suppression directive(s).",
        Some("Update ownership, expiry, or rule IDs before enabling the gate."),
      ),
    )
  } else {
    checks.push(
      doctor_check(
        "suppressions",
        Pass,
        "\{audits.length()} suppression directive(s) are structurally valid.",
        None,
      ),
    )
  }

  if options.baseline_disabled {
    checks.push(
      doctor_check(
        "baseline",
        Warn,
        "Baseline validation is disabled.",
        Some("Remove --no-baseline to check incremental-adoption state."),
      ),
    )
  } else {
    let baseline_path = match options.baseline_path {
      Some(path) => Some(path)
      None =>
        if @fs.path_exists(".moonhermetic-baseline.json") {
          Some(".moonhermetic-baseline.json")
        } else {
          None
        }
    }
    match baseline_path {
      None =>
        checks.push(
          doctor_check(
            "baseline",
            Warn,
            "No baseline was found; every finding counts as new.",
            Some("Create one with 'moonhermetic init'."),
          ),
        )
      Some(path) => doctor_check_baseline(path, findings, checks)
    }
  }

  if !files.is_empty() && options.baseline_disabled && findings.length() > 0 {
    checks.push(
      doctor_check(
        "findings",
        Warn,
        "\{findings.length()} finding(s) would be reported.",
        Some("Review them or use a baseline for incremental adoption."),
      ),
    )
  }
  let report = { strict: options.strict, checks, }
  println(
    match options.format {
      "json" => render_doctor_json(report)
      _ => render_doctor_text(report)
    },
  )
  if doctor_should_fail(report) {
    @sys.exit(1)
  }
  @sys.exit(0)
}
