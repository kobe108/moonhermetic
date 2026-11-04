///|
/// Severity assigned to a finding.
pub(all) enum Severity {
  Warning
  Error
}

///|
pub impl Eq for Severity with fn equal(self, other) {
  match (self, other) {
    (Warning, Warning) | (Error, Error) => true
    _ => false
  }
}

///|
pub extend Severity with Eq::{equal, not_equal}

///|
/// The category of implicit dependency found in a test.
pub(all) enum RuleKind {
  Clock
  Random
  Environment
  Network
  Process
  Filesystem
  Sleep
}

///|
pub impl Eq for RuleKind with fn equal(self, other) {
  match (self, other) {
    (Clock, Clock)
    | (Random, Random)
    | (Environment, Environment)
    | (Network, Network)
    | (Process, Process)
    | (Filesystem, Filesystem)
    | (Sleep, Sleep) => true
    _ => false
  }
}

///|
pub extend RuleKind with Eq::{equal, not_equal}

///|
/// One source location and its explanation.
pub(all) struct Finding {
  path : String
  line : Int
  column : Int
  rule : RuleKind
  severity : Severity
  evidence : String
}

///|
/// Findings produced by one scan invocation.
pub(all) struct ScanReport {
  scanned_files : Int
  findings : Array[Finding]
}

///|
pub fn Severity::to_string(self : Severity) -> String {
  match self {
    Warning => "warning"
    Error => "error"
  }
}

///|
pub fn RuleKind::code(self : RuleKind) -> String {
  match self {
    Clock => "HERM-CLOCK"
    Random => "HERM-RAND"
    Environment => "HERM-ENV"
    Network => "HERM-NET"
    Process => "HERM-PROC"
    Filesystem => "HERM-FS"
    Sleep => "HERM-SLEEP"
  }
}

///|
pub fn RuleKind::title(self : RuleKind) -> String {
  match self {
    Clock => "Wall-clock dependency"
    Random => "Unseeded randomness"
    Environment => "Process environment dependency"
    Network => "External network dependency"
    Process => "Child-process dependency"
    Filesystem => "External filesystem dependency"
    Sleep => "Timing dependency"
  }
}

///|
pub fn RuleKind::message(self : RuleKind) -> String {
  match self {
    Clock =>
      "The test reads the current wall clock, so its result can change over time."
    Random => "The test uses randomness without an explicit deterministic seed."
    Environment =>
      "The test reads process environment state that differs between machines."
    Network =>
      "The test depends on a network endpoint that may be unavailable in CI."
    Process =>
      "The test starts an external process whose presence and version vary."
    Filesystem => "The test reads or writes external filesystem state."
    Sleep =>
      "The test depends on elapsed time, which can make it flaky under load."
  }
}

///|
pub fn RuleKind::remediation(self : RuleKind) -> String {
  match self {
    Clock =>
      "Inject a clock or pass a fixed timestamp into the code under test."
    Random =>
      "Inject a seeded random generator and record the seed in the test."
    Environment =>
      "Pass configuration explicitly or set and restore environment variables in the fixture."
    Network =>
      "Use a fake transport or a deterministic local fixture instead of a live service."
    Process =>
      "Replace the subprocess with a trait implementation or an in-process test double."
    Filesystem =>
      "Use a temporary directory owned by the fixture and clean it up with defer."
    Sleep =>
      "Wait on an observable condition, virtual time, or an explicit synchronization primitive."
  }
}

///|
pub fn default_severity(rule : RuleKind) -> Severity {
  match rule {
    Clock | Random | Environment | Process | Filesystem => Warning
    Network | Sleep => Error
  }
}

///|
pub fn Finding::to_text(self : Finding) -> String {
  "\{self.path}:\{self.line}:\{self.column}: \{self.severity.to_string()} [\{self.rule.code()}] \{self.rule.title()}"
}
