///|
let sample_diff =
  #|diff --git a/src/checkout_test.mbt b/src/checkout_test.mbt
  #|--- a/src/checkout_test.mbt
  #|+++ b/src/checkout_test.mbt
  #|@@ -1,0 +2,2 @@
  #|+let response = fetch("https://example.test")
  #|+sleep(10)
  #|@@ -10,2 +12,1 @@
  #|-let old = 1
  #|+let now = @env.now()
  #|diff --git a/src/safe_test.mbt b/src/safe_test.mbt
  #|--- a/src/safe_test.mbt
  #|+++ b/src/safe_test.mbt
  #|@@ -5,1 +5,2 @@
  #| let value = 1
  #|+assert_eq(value, 1)

///|
test "parses added line numbers from unified diff" {
  let filter = @moonhermetic.parse_unified_diff(sample_diff)
  assert_eq(filter.files.length(), 2)
  assert_true(filter.includes("src/checkout_test.mbt", 2))
  assert_true(filter.includes("src/checkout_test.mbt", 3))
  assert_true(filter.includes("src/checkout_test.mbt", 12))
  assert_true(!filter.includes("src/checkout_test.mbt", 4))
  assert_true(filter.includes("src/safe_test.mbt", 6))
}

///|
test "matches absolute scanner paths by diff suffix" {
  let filter = @moonhermetic.parse_unified_diff(sample_diff)
  assert_true(filter.includes("C:\\repo\\src\\checkout_test.mbt", 2))
  assert_true(filter.includes("/home/runner/repo/src/safe_test.mbt", 6))
}

///|
test "filters findings to changed lines" {
  let filter = @moonhermetic.parse_unified_diff(sample_diff)
  let findings : Array[@moonhermetic.Finding] = [
    {
      path: "src/checkout_test.mbt",
      line: 2,
      column: 1,
      rule: @moonhermetic.Network,
      severity: @moonhermetic.Error,
      evidence: "fetch",
    },
    {
      path: "src/checkout_test.mbt",
      line: 4,
      column: 1,
      rule: @moonhermetic.Sleep,
      severity: @moonhermetic.Error,
      evidence: "sleep",
    },
  ]
  let filtered = @moonhermetic.filter_findings(findings, filter)
  assert_eq(filtered.length(), 1)
  assert_true(filtered[0].rule == @moonhermetic.Network)
}

///|
test "rejects non-diff input" {
  let result = try {
    ignore(@moonhermetic.parse_unified_diff("this is not a diff\n"))
    false
  } catch {
    DiffParseError(_) => true
  }
  assert_true(result)
}

///|
test "supports quoted paths with spaces and deleted files" {
  let patch =
    #|diff --git a/src/space test.mbt b/src/space test.mbt
    #|--- a/src/space test.mbt
    #|+++ "b/src/space test.mbt"
    #|@@ -0,0 +1,1 @@
    #|+sleep(1)
    #|diff --git a/src/old_test.mbt b/src/old_test.mbt
    #|--- a/src/old_test.mbt
    #|+++ /dev/null
    #|@@ -1,1 +0,0 @@
    #|-sleep(1)
  let filter = @moonhermetic.parse_unified_diff(patch)
  assert_true(filter.includes("src/space test.mbt", 1))
  assert_true(!filter.includes("src/old_test.mbt", 1))
}

///|
test "rejects malformed hunk headers" {
  let result = try {
    ignore(
      @moonhermetic.parse_unified_diff(
        (
          #|diff --git a/a_test.mbt b/a_test.mbt
          #|--- a/a_test.mbt
          #|+++ b/a_test.mbt
          #|@@ invalid @@
          #|+sleep(1)
        ),
      ),
    )
    false
  } catch {
    DiffParseError(_) => true
  }
  assert_true(result)
}
