#![allow(unused, for_loops_over_fallibles)]
use axum::{
    Router, debug_handler,
    extract::{Query, State},
    routing::get,
};
use core::panic;
use csv::ReaderBuilder;
use maud::{DOCTYPE, Markup, html};
use serde::Deserialize;
use sqlx::{Pool, Row, Sqlite, SqlitePool, migrate::MigrateDatabase, sqlite::SqliteRow};
use std::{
    fs::{File, read},
    io::BufReader,
    process,
};
use tower_http::services::ServeFile;

mod utils;
use utils::*;

mod insert_data;
use insert_data::*;

mod calculate;

const DB_URL: &'static str = "sqlite://sqlite.db";

#[tokio::main]
async fn main() {
    // db setup and data calculation
    let db = setup().await;
    insert_data(&db).await;

    // webserver setup
    let app = Router::new()
        .route("/", get(home))
        .route("/results", get(results))
        .with_state(db)
        .nest_service("/style", ServeFile::new("static/style.css"));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    println!("listening on 0.0.0.0:3000");

    axum::serve(listener, app).await.unwrap();
}

#[derive(Deserialize)]
struct SystemQuery {
    system: Option<String>,
}

async fn home() -> Markup {
    html! {
        (DOCTYPE)
        head {
            meta charset="utf-8";
            meta name="viewport" content="width=device-width, initial-scale=1.0";
            link rel="stylesheet" href="/style" {}
            title { "UK Electoral Systems - Database Assignment"}
            script src="https://unpkg.com/htmx.org@2.0.4" {}
        }
        body {
            section {
                h1 {
                    "UK Electoral Systems"
                }
                div id="select" {
                    h2 { "Choose a system" }
                    select autocomplete="off" name="system" hx-get="/results" hx-target="#target" hx-indicator="#indicator" hx-trigger="submit, change" {
                        option value="First Past the Post" selected { "First Past the Post" }

                        option value="Proportional Representation" { "Proportional Representation" }
                        option value="Proportional Representation with 5% threshold" { "Proportional Representation with 5% threshold" }
                        option value="Proportional Representation (county)" { "Proportional Representation (county)" }
                        option value="Proportional Representation (region)" { "Proportional Representation (region)" }
                        option value="Proportional Representation (country)" { "Proportional Representation (country)" }

                        option value="Largest Remainder (county)" { "Largest Remainder (county)" }
                        option value="Largest Remainder (region)" { "Largest Remainder (region)" }
                        option value="Largest Remainder (country)" { "Largest Remainder (country)" }

                        option value="D'Hondt (county)" { "D'Hondt (county)" }
                        option value="D'Hondt (region)" { "D'Hondt (region)" }
                        option value="D'Hondt (country)" { "D'Hondt (country)" }

                        option value="Hybrid" { "Hybrid" }
                    }
                    p id="indicator" .htmx-indicator {"Loading..."}
                    div id="target" hx-get="/results?system=First Past the Post" hx-trigger="load" {}
                }
            }
        }
    }
}

#[axum::debug_handler]
async fn results(systemquery: Query<SystemQuery>, State(db): State<Pool<Sqlite>>) -> Markup {
    let system = systemquery.system.clone().unwrap();
    match sqlx::query_as::<_, Results>("select * from results where system = $1;")
        .bind(&system)
        .fetch_all(&db)
        .await
    {
        Ok(e) => {
            html! {
                head {
                    link rel="stylesheet" href="/style" {}
                }
                h2 {(system)}
                table {
                    tr {
                        th {"System"}
                        th {"Party"}
                        th {"Seats"}
                        th {"Seat Percentage"}
                        th {"Vote Percentage"}
                        th {"Difference between percentage of votes and seats"}
                        th {"Winning party"}
                        th {"Seat difference from winner"}
                    }
                    @for row in e {
                        tr {
                            td {(row.system)}
                            td {(row.party)}
                            td {(row.seats)}
                            td {(row.seat_percentage)}
                            td {(row.vote_percentage)}
                            td {(row.difference_between_percentage_of_votes_and_seats)}
                            td {(row.winning_party)}
                            td {(row.seat_difference_from_winner)}
                        }
                    }
                }
            }
        }
        Err(e) => {
            eprintln!("ERR: {e}");
            panic!();
        }
    }
}
