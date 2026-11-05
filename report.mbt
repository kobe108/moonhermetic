///|
fn finding_to_json(finding : Finding) -> Json {
  Json::object({
    "path": Json::string(finding.path),
    "line": Json::number(finding.line.to_double()),
    "column": Json::number(finding.column.to_double()),
    "ruleId": Json::string(finding.rule.code()),
    "title": Json::string(finding.rule.title()),
    "severity": Json::string(finding.severity.to_string()),
    "message": Json::string(finding.rule.message()),
    "remediation": Json::string(finding.rule.remediation()),
    "evidence": Json::string(finding.evidence),
  })
}

///|
/// Render a stable, line-oriented report suitable for terminals and CI logs.
pub fn render_text(report : ScanReport) -> String {
  let out = StringBuilder()
  for finding in report.findings {
    out.write_string(
      "\{finding.path}:\{finding.line}:\{finding.column}: " +
      "\{finding.severity.to_string()} [\{finding.rule.code()}] " +
      "\{finding.rule.title()}\n",
    )
    out.write_string("  evidence: \{finding.evidence}\n")
    out.write_string("  fix: \{finding.rule.remediation()}\n")
  }
  if report.findings.length() > 0 {
    out.write_string("\n")
  }
  let warnings = count_by_severity(report, Warning)
  let errors = count_by_severity(report, Error)
  out.write_string(
    "MoonHermetic scanned \{report.scanned_files} test file(s): " +
    "\{report.findings.length()} finding(s), \{errors} error(s), \{warnings} warning(s).\n",
  )
  if report.filtered_out > 0 {
    out.write_string(
      "Diff filter ignored \{report.filtered_out} finding(s) outside changed lines.\n",
    )
  }
  out.to_string()
}

///|
/// Render machine-readable JSON.
pub fn render_json(report : ScanReport) -> String {
  Json::object({
    "schema": Json::string("moonhermetic/v1"),
    "tool": Json::object({
      "name": Json::string("MoonHermetic"),
      "version": Json::string("0.5.0"),
    }),
    "summary": Json::object({
      "scannedFiles": Json::number(report.scanned_files.to_double()),
      "findings": Json::number(report.findings.length().to_double()),
      "errors": Json::number(count_by_severity(report, Error).to_double()),
      "warnings": Json::number(count_by_severity(report, Warning).to_double()),
      "filteredOut": Json::number(report.filtered_out.to_double()),
    }),
    "findings": Json::array(report.findings.map(finding_to_json)),
  }).stringify(indent=2)
}

///|
fn markdown_escape(value : String) -> String {
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="|", new="\\|")
  .replace_all(old="`", new="\\`")
}

///|
/// Render a Markdown report intended for PR comments and project dashboards.
pub fn render_markdown(report : ScanReport) -> String {
  let out = StringBuilder()
  out.write_string("# MoonHermetic report\n\n")
  out.write_string(
    "Scanned **\{report.scanned_files}** test file(s); found " +
    "**\{report.findings.length()}** implicit dependency finding(s).\n\n",
  )
  if report.filtered_out > 0 {
    out.write_string(
      "\{report.filtered_out} finding(s) outside changed lines were filtered out.\n\n",
    )
  }
  if report.findings.length() == 0 {
    out.write_string("No hermeticity risks detected.\n")
    return out.to_string()
  }
  out.write_string(
    "| Location | Severity | Rule | Evidence | Suggested fix |\n",
  )
  out.write_string("|---|---|---|---|---|\n")
  for finding in report.findings {
    out.write_string(
      "| `\{finding.path}:\{finding.line}:\{finding.column}` " +
      "| \{finding.severity.to_string()} " +
      "| `\{finding.rule.code()}` \{finding.rule.title()} " +
      "| `\{markdown_escape(finding.evidence)}` " +
      "| \{markdown_escape(finding.rule.remediation())} |\n",
    )
  }
  out.to_string()
}

///|
fn sarif_rule(rule : RuleKind) -> Json {
  Json::object({
    "id": Json::string(rule.code()),
    "name": Json::string(rule.title()),
    "shortDescription": Json::object({ "text": Json::string(rule.title()) }),
    "fullDescription": Json::object({ "text": Json::string(rule.message()) }),
    "help": Json::object({ "text": Json::string(rule.remediation()) }),
    "defaultConfiguration": Json::object({
      "level": Json::string(
        match default_severity(rule) {
          Warning => "warning"
          Error => "error"
        },
      ),
    }),
  })
}

///|
fn sarif_result(finding : Finding) -> Json {
  Json::object({
    "ruleId": Json::string(finding.rule.code()),
    "level": Json::string(finding.severity.to_string()),
    "message": Json::object({ "text": Json::string(finding.rule.message()) }),
    "locations": Json::array([
      Json::object({
        "physicalLocation": Json::object({
          "artifactLocation": Json::object({
            "uri": Json::string(finding.path.replace_all(old="\\", new="/")),
          }),
          "region": Json::object({
            "startLine": Json::number(finding.line.to_double()),
            "startColumn": Json::number(finding.column.to_double()),
          }),
        }),
      }),
    ]),
  })
}

///|
/// Render SARIF 2.1.0 for GitHub code scanning and other CI consumers.
pub fn render_sarif(report : ScanReport) -> String {
  Json::object({
    "$schema": Json::string("https://json.schemastore.org/sarif-2.1.0.json"),
    "version": Json::string("2.1.0"),
    "runs": Json::array([
      Json::object({
        "tool": Json::object({
          "driver": Json::object({
            "name": Json::string("MoonHermetic"),
            "version": Json::string("0.5.0"),
            "informationUri": Json::string(
              "https://github.com/kobe108/moonhermetic",
            ),
            "rules": Json::array(rule_catalog().map(sarif_rule)),
          }),
        }),
        "results": Json::array(report.findings.map(sarif_result)),
      }),
    ]),
  }).stringify(indent=2)
}
