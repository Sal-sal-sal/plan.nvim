use plan_nvim::plan::{analyze, continuation, parse_line, toggle, Kind};
use serde_json::Value;
use std::io::Write;
use std::process::{Command, Stdio};

#[test]
fn markers_only_have_meaning_at_column_zero() {
    let cases = [
        ("[] learn", Kind::Todo, 2),
        ("[]learn", Kind::Todo, 2),
        ("[ ] learn", Kind::Todo, 3),
        ("[x] finished", Kind::Done, 3),
        ("[X] finished", Kind::Done, 3),
        ("* remember", Kind::Pointer, 1),
        ("*remember", Kind::Pointer, 1),
        ("# Today", Kind::Heading, 1),
        ("## Later", Kind::Heading, 2),
        (" [] literal", Kind::Text, 0),
        ("\t* literal", Kind::Text, 0),
        ("a [] b", Kind::Text, 0),
        ("a * b", Kind::Text, 0),
        ("[maybe] literal", Kind::Text, 0),
        ("#hashtag", Kind::Text, 0),
        ("####### too deep", Kind::Text, 0),
        ("", Kind::Text, 0),
    ];
    for (line, kind, marker_end) in cases {
        let item = parse_line(line, 7);
        assert_eq!(
            (item.kind, item.marker_end, item.row),
            (kind, marker_end, 7)
        );
    }
}

#[test]
fn completion_preserves_unicode_spacing_and_inline_markers() {
    for line in [
        "[] Қазақша русский 🚀",
        "[]  two spaces",
        "[]",
        "[]* inline",
    ] {
        let done = toggle(line).unwrap();
        assert!(done.starts_with("[x]"));
        assert_eq!(toggle(&done).as_deref(), Some(line));
    }
    assert_eq!(toggle("[ ] task").as_deref(), Some("[x] task"));
    assert_eq!(toggle("[X] task").as_deref(), Some("[] task"));
    assert_eq!(toggle("* pointer"), None);
    assert_eq!(toggle("literal []"), None);
}

#[test]
fn empty_plans_and_mixed_tasks_have_correct_statistics() {
    assert_eq!(analyze(&[]).1.percent, 0);
    let lines = ["[] next", "[x] done", "[X] done too", "* note", "inline []"].map(String::from);
    let (items, stats) = analyze(&lines);
    assert_eq!(items.len(), 5);
    assert_eq!(
        (
            stats.total,
            stats.done,
            stats.pending,
            stats.pointers,
            stats.percent
        ),
        (3, 2, 1, 1, 66)
    );
}

#[test]
fn continuation_handles_empty_items_and_byte_boundaries() {
    assert_eq!(continuation("[] Learn", 8), (Some("[] "), false));
    assert_eq!(continuation("[x] Done", 8), (Some("[] "), false));
    assert_eq!(continuation("* Note", 6), (Some("* "), false));
    assert_eq!(continuation("[]  ", 4), (Some("[] "), true));
    assert_eq!(continuation("* ", 2), (Some("* "), true));
    assert_eq!(continuation("[] Learn", 1), (None, false));
    assert_eq!(continuation("[] Learn", 100), (None, false));
    assert_eq!(continuation("[] 🚀", 4), (None, false));
    assert_eq!(continuation("plain", 5), (None, false));
}

#[test]
fn real_engine_recovers_after_invalid_requests_and_flushes_responses() {
    let mut child = Command::new(env!("CARGO_BIN_EXE_plan-nvim"))
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();
    let mut stdin = child.stdin.take().unwrap();
    writeln!(stdin, "not json").unwrap();
    writeln!(stdin, r#"{{"action":"toggle","line":"[] Қазақша 🚀"}}"#).unwrap();
    writeln!(
        stdin,
        r#"{{"action":"analyze","lines":["[] next","[x] done","* pointer"]}}"#
    )
    .unwrap();
    writeln!(stdin, r#"{{"action":"unknown"}}"#).unwrap();
    drop(stdin);
    let output = child.wait_with_output().unwrap();
    assert!(output.status.success());
    let responses: Vec<Value> = String::from_utf8(output.stdout)
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    assert_eq!(responses.len(), 4);
    assert!(responses[0]["error"].is_string());
    assert_eq!(responses[1]["line"], "[x] Қазақша 🚀");
    assert_eq!(responses[2]["stats"]["percent"], 50);
    assert!(responses[3]["error"].is_string());
}
