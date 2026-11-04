///|
let usage_text =
  #|MoonHermetic - static hermeticity checks for MoonBit tests
  #|
  #|Usage:
  #|  moonhermetic [options] [file-or-directory ...]
  #|
  #|Options:
  #|  -f, --format <text|json|markdown|sarif>
  #|                                      Output format (default: text)
  #|      --fail-on <never|warning|error>
  #|                                      Exit non-zero at this severity (default: error)
  #|      --exclude <text>                Skip paths or directory names containing text
  #|      --rules                         Print the rule catalog as Markdown
  #|  -h, --help                          Show this help
  #|  -V, --version                       Show the version
  #|
  #|Files ending in _test.mbt or _wbtest.mbt are scanned by default.
  #|Suppress a finding with // hermetic:ignore on its line.
  #|Use // hermetic:ignore-next on the preceding line to suppress one line.
  #|
  #|Exit codes:
  #|  0  Scan completed without reaching the fail threshold
  #|  1  A finding reached the fail threshold
  #|  2  Invalid arguments or file I/O failure

///|
fn print_error(message : String) -> Unit {
  eprintln("error: \{message}")
}

///|
fn require_value(args : Array[String], index : Int, option : String) -> String {
  if index + 1 >= args.length() {
    print_error("missing value for \{option}")
    @sys.exit(2)
  }
  args[index + 1]
}

///|
fn is_test_file(path : String) -> Bool {
  path.has_suffix("_test.mbt") || path.has_suffix("_wbtest.mbt")
}

///|
fn is_user_excluded(value : String, excludes : Array[String]) -> Bool {
  let normalized = value.replace_all(old="\\", new="/")
  for excluded in excludes {
    if normalized.contains(excluded.replace_all(old="\\", new="/")) {
      return true
    }
  }
  false
}

///|
fn is_builtin_excluded(name : String) -> Bool {
  if ["_build", ".git", ".mooncakes", ".moonagent", "target", "node_modules"].contains(
      name,
    ) {
    return true
  }
  false
}

///|
fn inspect_kind(path : String) -> Int {
  if !@fs.path_exists(path) {
    return 0
  }
  let is_directory = @fs.is_dir(path) catch { @fs.IOError(_) => return 0 }
  if is_directory {
    return 1
  }
  let is_file = @fs.is_file(path) catch { @fs.IOError(_) => return 0 }
  if is_file {
    return 2
  }
  0
}

///|
fn discover(
  path : String,
  files : Array[String],
  excludes : Array[String],
) -> Unit {
  if is_user_excluded(path, excludes) {
    return
  }
  match inspect_kind(path) {
    1 => {
      let entries = @fs.read_dir(path) catch {
        @fs.IOError(message) => {
          print_error("cannot read directory '\{path}': \{message}")
          @sys.exit(2)
          abort("unreachable after I/O error")
        }
      }
      for entry in entries {
        if !is_builtin_excluded(entry) {
          let child = @path.Path(path).join(@path.Path(entry)).to_string()
          discover(child, files, excludes)
        }
      }
    }
    2 => if is_test_file(path) && !files.contains(path) { files.push(path) }
    _ => {
      print_error("path does not exist or is not a file/directory: \{path}")
      @sys.exit(2)
    }
  }
}

///|
fn main {
  let args = @env.args()
  let inputs = []
  let excludes = []
  let mut format = "text"
  let mut fail_on = "error"
  let mut index = 1
  while index < args.length() {
    let arg = args[index]
    match arg {
      "-h" | "--help" => {
        println(usage_text)
        @sys.exit(0)
      }
      "-V" | "--version" => {
        println("moonhermetic 0.1.0")
        @sys.exit(0)
      }
      "--rules" => {
        println(@lib.rule_catalog_markdown())
        @sys.exit(0)
      }
      "-f" | "--format" => {
        let value = require_value(args, index, arg)
        match value {
          "text" | "json" | "markdown" | "md" | "sarif" => format = value
          _ => {
            print_error(
              "unknown format '\{value}'; expected text, json, markdown, or sarif",
            )
            @sys.exit(2)
          }
        }
        index = index + 1
      }
      "--fail-on" => {
        let value = require_value(args, index, arg)
        match value {
          "never" | "warning" | "error" => fail_on = value
          _ => {
            print_error(
              "unknown fail threshold '\{value}'; expected never, warning, or error",
            )
            @sys.exit(2)
          }
        }
        index = index + 1
      }
      "--exclude" => {
        let value = require_value(args, index, arg)
        if value.is_empty() {
          print_error("--exclude cannot be empty")
          @sys.exit(2)
        }
        excludes.push(value)
        index = index + 1
      }
      _ => {
        if arg.has_prefix("-") {
          print_error("unknown option '\{arg}'")
          @sys.exit(2)
        }
        inputs.push(arg)
      }
    }
    index = index + 1
  }

  if inputs.is_empty() {
    inputs.push(".")
  }

  let files = []
  for input in inputs {
    discover(input, files, excludes)
  }
  files.sort()

  let findings = []
  for file in files {
    let source = @fs.read_file_to_string(file) catch {
      @fs.IOError(message) => {
        print_error("cannot read file '\{file}': \{message}")
        @sys.exit(2)
        abort("unreachable after I/O error")
      }
    }
    for finding in @lib.scan_source(file, source) {
      findings.push(finding)
    }
  }

  let report = @lib.make_report(files.length(), findings)
  let output = match format {
    "json" => @lib.render_json(report)
    "markdown" | "md" => @lib.render_markdown(report)
    "sarif" => @lib.render_sarif(report)
    _ => @lib.render_text(report)
  }
  println(output)

  let failed = match fail_on {
    "never" => false
    "warning" => @lib.should_fail(report, @lib.Warning)
    _ => @lib.should_fail(report, @lib.Error)
  }
  if failed {
    @sys.exit(1)
  }
}
