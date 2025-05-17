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

mod insert_data;
use insert_data::*;

mod calculate;

const DB_URL: &'static str = "sqlite://sqlite.db";

#[tokio::main]
async fn main() {
    // db setup
    let db = setup().await;
    insert_data(&db).await;
}
