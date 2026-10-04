use serde::Serialize;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Kind {
    Todo,
    Done,
    Pointer,
    Heading,
    Text,
}

#[derive(Debug, PartialEq, Eq, Serialize)]
pub struct Item {
    pub row: usize,
    pub kind: Kind,
    pub marker_end: usize,
    pub length: usize,
}

#[derive(Debug, Default, PartialEq, Eq, Serialize)]
pub struct Stats {
    pub total: usize,
    pub done: usize,
    pub pending: usize,
    pub pointers: usize,
    pub percent: usize,
}
