#![allow(unused, for_loops_over_fallibles)]
use core::panic;
use csv::ReaderBuilder;
use sqlx::{Row, Sqlite, SqlitePool, migrate::MigrateDatabase, sqlite::SqliteRow};
use std::{
    fs::{File, read},
    io::BufReader,
    process,
};

mod utils;
use utils::*;

const DB_URL: &'static str = "sqlite://sqlite.db";

#[tokio::main]
async fn main() {
    // db setup
    let db = setup().await;

    match sqlx::query(include_str!("../sql/create_tables.sql"))
        .execute(&db)
        .await
    {
        Ok(_) => println!("[+] rebuilt all tables and views"),
        Err(e) => {
            eprintln!("[create_tables.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };

    // FPTP by Constituency
    let first_past_post = match sqlx::query(include_str!("../sql/fetch.sql"))
        .fetch_all(&db)
        .await
    {
        Ok(e) => e,
        Err(e) => {
            eprintln!("[fetch.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };
}
