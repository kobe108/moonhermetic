///|
priv struct InitOptions {
  target : String
  config_path : String
  baseline_path : String?
  force : Bool
}

///|
let init_usage_text =
  #|Usage:
  #|  moonhermetic init [path] [options]
  #|
  #|Options:
  #|  --config <path>     Config destination (default: .moonhermetic.json)
  #|  --baseline <path>   Baseline destination (default: .moonhermetic-baseline.json)
  #|  --no-baseline       Only create configuration
  #|  --force             Overwrite existing generated files
  #|  -h, --help          Show this help

///|
fn init_error(message : String) -> Unit {
  print_error(message)
  @sys.exit(2)
}

///|
fn parse_init_options(args : Array[String]) -> InitOptions {
  let mut target : String? = None
  let mut config_path = ".moonhermetic.json"
  let mut baseline_path : String? = Some(".moonhermetic-baseline.json")
  let mut force = false
  let mut index = 2
  while index < args.length() {
    let arg = args[index]
    match arg {
      "-h" | "--help" => {
        println(init_usage_text)
        @sys.exit(0)
      }
      "--config" => {
        config_path = require_value(args, index, arg)
        if config_path.is_empty() {
          init_error("--config cannot be empty")
        }
        index = index + 1
      }
      "--baseline" => {
        baseline_path = Some(require_value(args, index, arg))
        if baseline_path is Some(path) && path.is_empty() {
          init_error("--baseline cannot be empty")
        }
        index = index + 1
      }
      "--no-baseline" => baseline_path = None
      "--force" => force = true
      _ => {
        if arg.has_prefix("-") {
          init_error("unknown init option '\{arg}'")
        }
        if target is Some(_) {
          init_error("init accepts at most one target path")
        }
        target = Some(arg)
      }
    }
    index = index + 1
  }
  if baseline_path is Some(path) && path == config_path {
    init_error("config and baseline destinations must be different")
  }
  {
    target: match target {
      Some(target) => target
      None => "."
    },
    config_path,
    baseline_path,
    force,
  }
}

///|
fn init_config_json() -> String {
  Json::object({
    "version": Json::number(1),
    "failOn": Json::string("error"),
    "exclude": Json::array([]),
    "rules": Json::object({
      "HERM-CLOCK": Json::string("warning"),
      "HERM-RAND": Json::string("warning"),
      "HERM-ENV": Json::string("warning"),
      "HERM-NET": Json::string("error"),
      "HERM-PROC": Json::string("warning"),
      "HERM-FS": Json::string("warning"),
      "HERM-SLEEP": Json::string("error"),
    }),
  }).stringify(indent=2) +
  "\n"
}

///|
fn prepare_init_destination(path : String, force : Bool) -> Unit {
  if @fs.path_exists(path) && !force {
    init_error("refusing to overwrite existing '\{path}'; use --force")
  }
}

///|
fn write_init_file(path : String, content : String) -> Unit {
  @fs.write_string_to_file(path, content) catch {
    @fs.IOError(message) => init_error("cannot write '\{path}': \{message}")
  }
}

///|
fn handle_init_args(args : Array[String]) -> Unit {
  if args.length() < 2 || args[1] != "init" {
    return
  }
  let options = parse_init_options(args)
  prepare_init_destination(options.config_path, options.force)
  match options.baseline_path {
    Some(path) => prepare_init_destination(path, options.force)
    None => ()
  }

  let baseline_content = match options.baseline_path {
    Some(path) => {
      let files = []
      let seen_directories = []
      discover(options.target, files, [], seen_directories, 0)
      files.sort()
      let findings = []
      let scan_date = current_utc_date()
      for file in files {
        let source = @fs.read_file_to_string(file) catch {
          @fs.IOError(message) => {
            init_error("cannot read file '\{file}': \{message}")
            abort("unreachable after I/O error")
          }
        }
        for
          finding in @lib.scan_source_with_options_and_date(
            file,
            source,
            @lib.default_scan_options(),
            scan_date,
          ) {
          findings.push(finding)
        }
      }
      let root = @path.Path(path).dirname().to_string()
      let baseline = @lib.create_baseline(findings, root, scan_date, "0.13.0")
      Some(
        (
          @lib.render_baseline_json(baseline),
          baseline.entries.length(),
          findings.length(),
        ),
      )
    }
    None => None
  }

  write_init_file(options.config_path, init_config_json())
  println("Created config: \{options.config_path}")

  match (options.baseline_path, baseline_content) {
    (Some(path), Some((content, fingerprint_count, finding_count))) => {
      write_init_file(path, content)
      println(
        "Created baseline: \{path} " +
        "(\{fingerprint_count} fingerprint(s), " +
        "\{finding_count} finding(s))",
      )
    }
    (None, None) => println("Skipped baseline (--no-baseline)")
    _ => init_error("internal init state is inconsistent")
  }
  println("Next: review the generated files and commit them.")
  @sys.exit(0)
}
