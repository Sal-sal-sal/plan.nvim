use super::{parse_line, Kind};

pub fn toggle(line: &str) -> Option<String> {
    let item = parse_line(line, 0);
    let marker = match item.kind {
        Kind::Todo => "[x]",
        Kind::Done => "[]",
        _ => return None,
    };
    Some(format!("{marker}{}", &line[item.marker_end..]))
}

pub fn continuation(line: &str, column: usize) -> (Option<&'static str>, bool) {
    let item = parse_line(line, 0);
    if column < item.marker_end || column > line.len() || !line.is_char_boundary(column) {
        return (None, false);
    }
    let prefix = match item.kind {
        Kind::Todo | Kind::Done => "[] ",
        Kind::Pointer => "* ",
        _ => return (None, false),
    };
    let clear = line[item.marker_end..].trim().is_empty();
    (Some(prefix), clear)
}
