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
  if report.baseline_suppressed > 0 {
    out.write_string(
      "Baseline accepted \{report.baseline_suppressed} existing finding(s).\n",
    )
  }
  if report.baseline_stale > 0 {
    out.write_string(
      "Baseline contains \{report.baseline_stale} stale count(s); " +
      "regenerate it to keep the file current.\n",
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
      "version": Json::string("0.14.0"),
    }),
    "summary": Json::object({
      "scannedFiles": Json::number(report.scanned_files.to_double()),
      "findings": Json::number(report.findings.length().to_double()),
      "errors": Json::number(count_by_severity(report, Error).to_double()),
      "warnings": Json::number(count_by_severity(report, Warning).to_double()),
      "filteredOut": Json::number(report.filtered_out.to_double()),
      "baselineSuppressed": Json::number(report.baseline_suppressed.to_double()),
      "baselineStale": Json::number(report.baseline_stale.to_double()),
      "baselinePath": match report.baseline_path {
        Some(path) => Json::string(path)
        None => Json::null()
      },
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
  if report.baseline_suppressed > 0 {
    out.write_string(
      "\{report.baseline_suppressed} existing finding(s) were accepted by " +
      "the baseline.\n\n",
    )
  }
  if report.baseline_stale > 0 {
    out.write_string(
      "\{report.baseline_stale} stale baseline count(s) can be removed by " +
      "regenerating the baseline.\n\n",
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
fn summary_short(value : String, limit : Int) -> String {
  let trimmed = value.trim()
  if trimmed.char_length() <= limit {
    trimmed.to_owned()
  } else {
    "\{trimmed.exact_view(end=limit).to_owned()}..."
  }
}

///|
/// Render a compact Markdown report for GitHub job summaries and PR comments.
///
/// At most 20 findings are shown to keep CI reports readable and within API
/// limits. The complete report remains available through the selected format.
pub fn render_ci_summary(report : ScanReport) -> String {
  let out = StringBuilder()
  let errors = count_by_severity(report, Error)
  let warnings = count_by_severity(report, Warning)
  out.write_string("# MoonHermetic report\n\n")
  out.write_string("| Scanned files | Findings | Errors | Warnings |\n")
  out.write_string("|---:|---:|---:|---:|\n")
  out.write_string(
    "| \{report.scanned_files} | \{report.findings.length()} | " +
    "\{errors} | \{warnings} |\n\n",
  )
  if report.filtered_out > 0 {
    out.write_string(
      "\{report.filtered_out} finding(s) outside changed lines were filtered " +
      "out.\n\n",
    )
  }
  if report.baseline_suppressed > 0 {
    out.write_string(
      "\{report.baseline_suppressed} existing finding(s) were accepted by " +
      "the baseline.\n\n",
    )
  }
  if report.baseline_stale > 0 {
    out.write_string(
      "\{report.baseline_stale} stale baseline count(s) remain.\n\n",
    )
  }
  if report.findings.length() == 0 {
    out.write_string("No hermeticity risks detected.\n")
    return out.to_string()
  }
  let shown = if report.findings.length() < 20 {
    report.findings.length()
  } else {
    20
  }
  out.write_string("| Location | Severity | Rule | Evidence |\n")
  out.write_string("|---|---|---|---|\n")
  for index = 0; index < shown; index = index + 1 {
    let finding = report.findings[index]
    out.write_string(
      "| `\{markdown_escape(finding.path.replace_all(old="\\", new="/"))}:" +
      "\{finding.line}:\{finding.column}` " +
      "| \{finding.severity.to_string()} " +
      "| `\{finding.rule.code()}` \{finding.rule.title()} " +
      "| `\{markdown_escape(summary_short(finding.evidence, 160))}` |\n",
    )
  }
  if report.findings.length() > shown {
    out.write_string(
      "\n_\{report.findings.length() - shown} additional finding(s) are " +
      "available in the full report._\n",
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
            "version": Json::string("0.14.0"),
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
