///|
pub(all) enum SuppressionStatus {
  Active
  ExpiringSoon
  Expired
  Legacy
  Invalid
}

///|
pub impl Eq for SuppressionStatus with fn equal(self, other) {
  match (self, other) {
    (Active, Active)
    | (ExpiringSoon, ExpiringSoon)
    | (Expired, Expired)
    | (Legacy, Legacy)
    | (Invalid, Invalid) => true
    _ => false
  }
}

///|
pub extend SuppressionStatus with Eq::{equal, not_equal}

///|
pub(all) struct SuppressionAudit {
  path : String
  line : Int
  column : Int
  directive : String
  rules : Array[String]
  owner : String?
  expires : String?
  reason : String?
  status : SuppressionStatus
  message : String
}

///|
pub(all) struct SuppressionAuditReport {
  scanned_files : Int
  today : String
  audits : Array[SuppressionAudit]
}

///|
priv struct SuppressionAuditDraft {
  column : Int
  directive : String
  rules : Array[String]
  owner : String?
  expires : String?
  reason : String?
  status : SuppressionStatus
  message : String
}

///|
priv struct LineCommentScan {
  comment : String?
  comment_column : Int
  block_depth : Int
}

///|
fn scan_line_comment(
  raw_line : String,
  starting_block_depth : Int,
) -> LineCommentScan {
  let chars = raw_line.to_array()
  let mut i = 0
  let mut block_depth = starting_block_depth
  while i < chars.length() {
    if block_depth > 0 {
      if chars[i] == '/' && i + 1 < chars.length() && chars[i + 1] == '*' {
        block_depth = block_depth + 1
        i = i + 2
      } else if chars[i] == '*' && i + 1 < chars.length() && chars[i + 1] == '/' {
        block_depth = block_depth - 1
        i = i + 2
      } else {
        i = i + 1
      }
      continue
    }
    if chars[i] == '#' && i + 1 < chars.length() && chars[i + 1] == '|' {
      return { comment: None, comment_column: 0, block_depth, }
    }
    if chars[i] == '/' && i + 1 < chars.length() && chars[i + 1] == '*' {
      block_depth = 1
      i = i + 2
      continue
    }
    if chars[i] == '/' && i + 1 < chars.length() && chars[i + 1] == '/' {
      return {
        comment: Some(raw_line.exact_view(start=i + 2).to_owned()),
        comment_column: i + 2,
        block_depth,
      }
    }
    if chars[i] == '"' || chars[i] == '\'' {
      let quote = chars[i]
      let mut escaped = false
      i = i + 1
      while i < chars.length() {
        let current = chars[i]
        i = i + 1
        if escaped {
          escaped = false
        } else if current == '\\' {
          escaped = true
        } else if current == quote {
          break
        }
      }
      continue
    }
    i = i + 1
  }
  { comment: None, comment_column: 0, block_depth, }
}

///|
pub fn SuppressionStatus::to_string(self : SuppressionStatus) -> String {
  match self {
    Active => "active"
    ExpiringSoon => "expiring-soon"
    Expired => "expired"
    Legacy => "legacy"
    Invalid => "invalid"
  }
}

///|
fn invalid_audit(
  column : Int,
  directive : String,
  rules : Array[String],
  owner : String?,
  expires : String?,
  reason : String?,
  message : String,
) -> SuppressionAuditDraft {
  {
    column,
    directive,
    rules,
    owner,
    expires,
    reason,
    status: Invalid,
    message,
  }
}

///|
fn suppression_days_remaining(expires : String, today : String) -> Int? {
  if !valid_iso_date(expires) || !valid_iso_date(today) {
    return None
  }
  let expires_date = @time.PlainDate::of(
    date_digit(expires, 0).unwrap() * 1000 +
    date_digit(expires, 1).unwrap() * 100 +
    date_digit(expires, 2).unwrap() * 10 +
    date_digit(expires, 3).unwrap(),
    date_digit(expires, 5).unwrap() * 10 + date_digit(expires, 6).unwrap(),
    date_digit(expires, 8).unwrap() * 10 + date_digit(expires, 9).unwrap(),
  ) catch {
    _ => return None
  }
  let today_date = @time.PlainDate::of(
    date_digit(today, 0).unwrap() * 1000 +
    date_digit(today, 1).unwrap() * 100 +
    date_digit(today, 2).unwrap() * 10 +
    date_digit(today, 3).unwrap(),
    date_digit(today, 5).unwrap() * 10 + date_digit(today, 6).unwrap(),
    date_digit(today, 8).unwrap() * 10 + date_digit(today, 9).unwrap(),
  ) catch {
    _ => return None
  }
  Some((expires_date.to_unix_day() - today_date.to_unix_day()).to_int())
}

///|
fn parse_suppression_audit(
  comment_text : String,
  comment_column : Int,
  today : String,
) -> SuppressionAuditDraft? {
  let comment = comment_text.trim()
  let leading_whitespace = comment_text.char_length() -
    comment_text.trim_start().char_length()
  let (directive, after_marker) = if comment.strip_prefix(
      "hermetic:ignore-next",
    )
    is Some(rest) {
    ("hermetic:ignore-next", rest)
  } else if comment.strip_prefix("hermetic:ignore") is Some(rest) {
    ("hermetic:ignore", rest)
  } else {
    return None
  }
  let column = comment_column + leading_whitespace + 1
  let mut rest = after_marker.trim_start()
  if rest.has_prefix(":") {
    return Some({
      column,
      directive,
      rules: [],
      owner: None,
      expires: None,
      reason: Some(rest.exact_view(start=1).trim().to_owned()),
      status: Legacy,
      message: "Legacy suppression has no owner or expiry.",
    })
  }

  let rules : Array[String] = []
  let mut owner : String? = None
  let mut expires : String? = None
  let mut reason : String? = None
  while !rest.is_empty() {
    let token = match rest.find_by(c => c == ' ' || c == '\t') {
      Some(index) => {
        let token = rest.exact_view(end=index).to_owned()
        rest = rest.exact_view(start=index + 1).trim_start()
        token
      }
      None => {
        let token = rest.to_owned()
        rest = ""
        token
      }
    }
    if token.has_prefix("owner=") {
      let value = token.exact_view(start=6).trim().to_owned()
      if value.is_empty() {
        return Some(
          invalid_audit(
            column, directive, rules, owner, expires, reason, "Suppression owner cannot be empty.",
          ),
        )
      }
      owner = Some(value)
    } else if token.has_prefix("expires=") {
      let value = token.exact_view(start=8).trim().to_owned()
      if !valid_iso_date(value) {
        return Some(
          invalid_audit(
            column,
            directive,
            rules,
            owner,
            Some(value),
            reason,
            "Suppression expiry must be a valid YYYY-MM-DD date.",
          ),
        )
      }
      expires = Some(value)
    } else if token.has_prefix("reason=") {
      let value = token.exact_view(start=7).to_owned()
      reason = Some(if rest.is_empty() { value } else { "\{value} \{rest}" })
      rest = ""
    } else {
      for rule_id in token.split(",") {
        let rule_id = rule_id.trim()
        if rule_id.is_empty() {
          continue
        }
        match RuleKind::from_code(rule_id.to_owned()) {
          Some(rule) => {
            let code = rule.code()
            if !rules.contains(code) {
              rules.push(code)
            }
          }
          None =>
            return Some(
              invalid_audit(
                column,
                directive,
                rules,
                owner,
                expires,
                reason,
                "Unknown suppression rule ID '\{rule_id}'.",
              ),
            )
        }
      }
    }
  }

  if rules.is_empty() && owner is None && expires is None {
    return Some({
      column,
      directive,
      rules,
      owner,
      expires,
      reason,
      status: Legacy,
      message: "Legacy suppression has no owner or expiry.",
    })
  }
  let owner_value = match owner {
    Some(owner) => owner
    None =>
      return Some(
        invalid_audit(
          column,
          directive,
          rules,
          None,
          expires,
          reason,
          "Scoped suppression is missing owner=.",
        ),
      )
  }
  let expires_value = match expires {
    Some(expires) => expires
    None =>
      return Some(
        invalid_audit(
          column,
          directive,
          rules,
          Some(owner_value),
          None,
          reason,
          "Scoped suppression is missing expires=.",
        ),
      )
  }
  let remaining = match suppression_days_remaining(expires_value, today) {
    Some(days) => days
    None =>
      return Some(
        invalid_audit(
          column,
          directive,
          rules,
          Some(owner_value),
          Some(expires_value),
          reason,
          "Suppression expiry could not be evaluated.",
        ),
      )
  }
  if remaining < 0 {
    Some({
      column,
      directive,
      rules,
      owner: Some(owner_value),
      expires: Some(expires_value),
      reason,
      status: Expired,
      message: "Suppression expired \{-remaining} day(s) ago.",
    })
  } else if remaining <= 30 {
    Some({
      column,
      directive,
      rules,
      owner: Some(owner_value),
      expires: Some(expires_value),
      reason,
      status: ExpiringSoon,
      message: "Suppression expires in \{remaining} day(s).",
    })
  } else {
    Some({
      column,
      directive,
      rules,
      owner: Some(owner_value),
      expires: Some(expires_value),
      reason,
      status: Active,
      message: "Suppression is active for another \{remaining} day(s).",
    })
  }
}

///|
pub fn audit_suppressions(
  path : String,
  source : String,
  today : String,
) -> Array[SuppressionAudit] {
  let audits : Array[SuppressionAudit] = []
  let lines = source.split("\n").to_array()
  let mut block_depth = 0
  for index = 0; index < lines.length(); index = index + 1 {
    let raw_line = lines[index].to_owned()
    let scanned = scan_line_comment(raw_line, block_depth)
    block_depth = scanned.block_depth
    if scanned.comment is Some(comment) &&
      parse_suppression_audit(comment, scanned.comment_column, today)
      is Some(draft) {
      audits.push({
        path,
        line: index + 1,
        column: draft.column,
        directive: draft.directive,
        rules: draft.rules,
        owner: draft.owner,
        expires: draft.expires,
        reason: draft.reason,
        status: draft.status,
        message: draft.message,
      })
    }
  }
  audits
}

///|
pub fn make_suppression_audit_report(
  scanned_files : Int,
  today : String,
  audits : Array[SuppressionAudit],
) -> SuppressionAuditReport {
  { scanned_files, today, audits, }
}

///|
pub fn count_suppression_status(
  report : SuppressionAuditReport,
  status : SuppressionStatus,
) -> Int {
  report.audits.iter().filter(audit => audit.status == status).count()
}

///|
/// Expired and malformed directives fail the governance gate.
pub fn has_suppression_errors(report : SuppressionAuditReport) -> Bool {
  report.audits.any(audit => audit.status == Expired || audit.status == Invalid)
}

///|
fn audit_to_json(audit : SuppressionAudit) -> Json {
  Json::object({
    "path": Json::string(audit.path),
    "line": Json::number(audit.line.to_double()),
    "column": Json::number(audit.column.to_double()),
    "directive": Json::string(audit.directive),
    "rules": Json::array(audit.rules.map(Json::string)),
    "owner": match audit.owner {
      Some(owner) => Json::string(owner)
      None => Json::null()
    },
    "expires": match audit.expires {
      Some(expires) => Json::string(expires)
      None => Json::null()
    },
    "reason": match audit.reason {
      Some(reason) => Json::string(reason)
      None => Json::null()
    },
    "status": Json::string(audit.status.to_string()),
    "message": Json::string(audit.message),
  })
}

///|
fn audit_rules_label(audit : SuppressionAudit) -> String {
  if audit.rules.is_empty() {
    return "all-rules"
  }
  let out = StringBuilder()
  for index, rule in audit.rules {
    if index > 0 {
      out.write_string(",")
    }
    out.write_string(rule)
  }
  out.to_string()
}

///|
/// Render a line-oriented governance report for terminals and CI logs.
pub fn render_suppression_audit_text(report : SuppressionAuditReport) -> String {
  let out = StringBuilder()
  for audit in report.audits {
    out.write_string(
      "\{audit.path}:\{audit.line}:\{audit.column}: " +
      "\{audit.status.to_string()} [\{audit_rules_label(audit)}] " +
      "\{audit.message}\n",
    )
    match audit.owner {
      Some(owner) => out.write_string("  owner: \{owner}\n")
      None => ()
    }
    match audit.expires {
      Some(expires) => out.write_string("  expires: \{expires}\n")
      None => ()
    }
    match audit.reason {
      Some(reason) => out.write_string("  reason: \{reason}\n")
      None => ()
    }
  }
  if report.audits.length() > 0 {
    out.write_string("\n")
  }
  out.write_string(
    "MoonHermetic audited \{report.scanned_files} test file(s) on " +
    "\{report.today}: \{report.audits.length()} suppression(s); " +
    "\{count_suppression_status(report, Active)} active, " +
    "\{count_suppression_status(report, ExpiringSoon)} expiring soon, " +
    "\{count_suppression_status(report, Expired)} expired, " +
    "\{count_suppression_status(report, Legacy)} legacy, " +
    "\{count_suppression_status(report, Invalid)} invalid.\n",
  )
  out.to_string()
}

///|
/// Render a compact suppression governance summary for GitHub CI surfaces.
pub fn render_suppression_audit_markdown(
  report : SuppressionAuditReport,
) -> String {
  let out = StringBuilder()
  out.write_string("# MoonHermetic suppression audit\n\n")
  out.write_string(
    "Scanned **\{report.scanned_files}** test file(s) on " +
    "**\{report.today}**.\n\n",
  )
  out.write_string("| Active | Expiring soon | Expired | Legacy | Invalid |\n")
  out.write_string("|---:|---:|---:|---:|---:|\n")
  out.write_string(
    "| \{count_suppression_status(report, Active)} " +
    "| \{count_suppression_status(report, ExpiringSoon)} " +
    "| \{count_suppression_status(report, Expired)} " +
    "| \{count_suppression_status(report, Legacy)} " +
    "| \{count_suppression_status(report, Invalid)} |\n\n",
  )
  if report.audits.length() == 0 {
    out.write_string("No suppression directives found.\n")
    return out.to_string()
  }
  let shown = if report.audits.length() < 20 {
    report.audits.length()
  } else {
    20
  }
  out.write_string("| Location | Status | Rules | Owner | Expires | Reason |\n")
  out.write_string("|---|---|---|---|---|---|\n")
  for index = 0; index < shown; index = index + 1 {
    let audit = report.audits[index]
    out.write_string(
      "| `\{markdown_escape(audit.path.replace_all(old="\\", new="/"))}:" +
      "\{audit.line}:\{audit.column}` " +
      "| \{audit.status.to_string()} " +
      "| `\{markdown_escape(audit_rules_label(audit))}` " +
      "| \{match audit.owner { Some(owner) => markdown_escape(owner); None => "-" }} " +
      "| \{match audit.expires { Some(expires) => expires; None => "-" }} " +
      "| \{match audit.reason { Some(reason) => markdown_escape(reason); None => "-" }} |\n",
    )
  }
  if report.audits.length() > shown {
    out.write_string(
      "\n_\{report.audits.length() - shown} additional suppression(s) are " +
      "available in the full report._\n",
    )
  }
  out.to_string()
}

///|
pub fn render_suppression_audit_json(report : SuppressionAuditReport) -> String {
  Json::object({
    "schema": Json::string("moonhermetic/suppression-audit-v1"),
    "tool": Json::object({
      "name": Json::string("MoonHermetic"),
      "version": Json::string("0.13.0"),
    }),
    "today": Json::string(report.today),
    "summary": Json::object({
      "scannedFiles": Json::number(report.scanned_files.to_double()),
      "total": Json::number(report.audits.length().to_double()),
      "active": Json::number(
        count_suppression_status(report, Active).to_double(),
      ),
      "expiringSoon": Json::number(
        count_suppression_status(report, ExpiringSoon).to_double(),
      ),
      "expired": Json::number(
        count_suppression_status(report, Expired).to_double(),
      ),
      "legacy": Json::number(
        count_suppression_status(report, Legacy).to_double(),
      ),
      "invalid": Json::number(
        count_suppression_status(report, Invalid).to_double(),
      ),
    }),
    "audits": Json::array(report.audits.map(audit_to_json)),
  }).stringify(indent=2)
}
