#![allow(unused)]
use sqlx::{Row, Sqlite, SqlitePool, migrate::MigrateDatabase, sqlite::SqliteRow};
use std::process;

mod utils;
use utils::*;

const DB_URL: &'static str = "sqlite://sqlite.db";

#[tokio::main]
async fn main() {
    // create database file if it isn't present
    println!("[+] searching for database at {}", DB_URL);
    if !Sqlite::database_exists(DB_URL).await.unwrap_or(false) {
        println!("[#] creating database at {}", DB_URL);
        match Sqlite::create_database(DB_URL).await {
            Ok(_) => println!("[+] database created"),
            Err(error) => panic!("[-] error: {}", error),
        }
    } else {
        println!("[+] found database");
    }

    // connect to the database and run table creation script
    let db = SqlitePool::connect(DB_URL).await.unwrap();
    let _ = match sqlx::query(include_str!("../sql/create_tables.sql"))
        .execute(&db)
        .await
    {
        Ok(_) => (),
        Err(e) => {
            eprintln!("[-] ERROR: {e:?}");
            process::exit(1)
        }
    };

    // FPTP by Constituency
    let first_past_post =
        match sqlx::query_as::<_, Results>
        ("select * from party_seats order by seats;")
        .fetch_all(&db).await {
            Ok(e) => {
                e
            }
            Err(e) => {
                eprintln!("[-] ERROR: {e:?}");
                process::exit(1)
            }
        };
}
