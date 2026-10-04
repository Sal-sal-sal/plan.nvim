use super::{Item, Kind, Stats};

pub fn parse_line(line: &str, row: usize) -> Item {
    let (kind, marker_end) = if line.starts_with("[]") {
        (Kind::Todo, 2)
    } else if line.starts_with("[ ]") {
        (Kind::Todo, 3)
    } else if line.starts_with("[x]") || line.starts_with("[X]") {
        (Kind::Done, 3)
    } else if line.starts_with('*') {
        (Kind::Pointer, 1)
    } else {
        let level = line.bytes().take_while(|byte| *byte == b'#').count();
        if (1..=6).contains(&level) && line.as_bytes().get(level) == Some(&b' ') {
            (Kind::Heading, level)
        } else {
            (Kind::Text, 0)
        }
    };
    Item {
        row,
        kind,
        marker_end,
        length: line.len(),
    }
}

pub fn analyze(lines: &[String]) -> (Vec<Item>, Stats) {
    let mut stats = Stats::default();
    let items = lines
        .iter()
        .enumerate()
        .map(|(row, line)| {
            let item = parse_line(line, row);
            match item.kind {
                Kind::Todo => stats.pending += 1,
                Kind::Done => stats.done += 1,
                Kind::Pointer => stats.pointers += 1,
                _ => {}
            }
            item
        })
        .collect();
    stats.total = stats.pending + stats.done;
    stats.percent = (stats.done * 100).checked_div(stats.total).unwrap_or(0);
    (items, stats)
}
