use crate::plan;
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum Request {
    Analyze { lines: Vec<String> },
    Toggle { line: String },
    Continue { line: String, column: usize },
}

#[derive(Debug, Serialize)]
#[serde(untagged)]
pub enum Response {
    Analysis {
        items: Vec<plan::Item>,
        stats: plan::Stats,
    },
    Toggle {
        line: Option<String>,
    },
    Continue {
        prefix: Option<&'static str>,
        clear: bool,
    },
    Error {
        error: String,
    },
}

pub fn handle(input: &str) -> Response {
    match serde_json::from_str::<Request>(input) {
        Ok(Request::Analyze { lines }) => {
            let (items, stats) = plan::analyze(&lines);
            Response::Analysis { items, stats }
        }
        Ok(Request::Toggle { line }) => Response::Toggle {
            line: plan::toggle(&line),
        },
        Ok(Request::Continue { line, column }) => {
            let (prefix, clear) = plan::continuation(&line, column);
            Response::Continue { prefix, clear }
        }
        Err(error) => Response::Error {
            error: error.to_string(),
        },
    }
}
