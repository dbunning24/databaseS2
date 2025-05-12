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

    // drop all tables and views automatically to save me doing it myself
    let r = match sqlx::query("SELECT name, type FROM sqlite_master WHERE (type='table' OR type='view') AND name != 'election_results_raw' AND name NOT LIKE 'sqlite_%';").fetch_all(&db).await {
        Ok(res) => {
           for row in res {
               let (name, r#type) = (row.get::<&str, &str>("name"),row.get::<&str, &str>("type"));
               let mut query = "";
               
                let _ = match sqlx::query(format!("drop {type} if exists {name}").as_str()).execute(&db).await {
                    Ok(_) => println!("[+] dropped {} {}", r#type, name),
                    Err(e) => {
                        eprintln!("[-] ERROR: {e:?}"); process::exit(1)
                    }
                };
            }
        }
        Err(e) => {
            eprintln!("[-] ERROR: {e:?}");
            process::exit(1)
        }
    };

    println!("[#] dropped tables and views");


    let _ = match sqlx::query(include_str!("../sql/create_tables.sql"))
        .execute(&db)
        .await
    {
        Ok(_) => println!("[+] rebuilt all tables and views"),
        Err(e) => {
            eprintln!("[-] ERROR: {e:?}");
            process::exit(1)
        }
    };

    // FPTP by Constituency
    let first_past_post =
        match sqlx::query(include_str!("../sql/fetch.sql"))
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
