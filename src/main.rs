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
    // check for database - should be present
    let mut raw_data_present: bool = true;
    println!("[+] searching for database at {}", DB_URL);
    if !Sqlite::database_exists(DB_URL).await.unwrap_or(false) {
        println!("[#] creating database at {}", DB_URL);
        match Sqlite::create_database(DB_URL).await {
            Ok(_) => {
                println!("[+] database created");
                raw_data_present = false
            }
            Err(error) => panic!(
                "[database creation] ERROR, couldn't create database: {}",
                error
            ),
        }
    } else {
        println!("[+] found database");
    }
    // connect to the database and run table creation script
    let db = SqlitePool::connect(DB_URL).await.unwrap();

    // if the raw data table is gone for some reason, reconstruct using csv data
    if (!raw_data_present) {
        match sqlx::query(
            "CREATE TABLE election_results_raw (
            constituency_name TEXT,
            county_name TEXT,
            region_name TEXT,
            country_name TEXT,
            party_name TEXT,
            party_abbreviation TEXT,
            firstname TEXT,
            surname TEXT,
            gender TEXT,
            votes TEXT
        )",
        )
        .execute(&db)
        .await
        {
            Ok(_) => {
                println!("[+] raw data table created. inserting data...");
                let file = File::open("./data/data.csv").unwrap();
                let mut reader = ReaderBuilder::new().from_reader(file);
                for res in reader.records() {
                    for r in res {
                        match sqlx::query(
                            "INSERT INTO election_results_raw VALUES
                        ( $1, $2, $3, $4, $5, $6, $7, $8, $9, $10);",
                        )
                        .bind(&r[0])
                        .bind(&r[1])
                        .bind(&r[2])
                        .bind(&r[3])
                        .bind(&r[4])
                        .bind(&r[5])
                        .bind(&r[6])
                        .bind(&r[7])
                        .bind(&r[8])
                        .bind(&r[9])
                        .execute(&db)
                        .await
                        {
                            Ok(_) => (),
                            Err(_) => (),
                        }
                    }
                }
                println!("[+] inserted values.")
            }
            Err(e) => {
                println!("[raw data creation] ERROR: {e}");
                panic!("couldnt create raw data. exiting...");
            }
        }
    } else {
        // drop all tables and views automatically to save me doing it myself
        match sqlx::query(
            "SELECT name, type
            FROM sqlite_master WHERE (type='table' OR type='view') 
            AND name != 'election_results_raw' 
            AND name NOT LIKE 'sqlite_%';",
        )
        .fetch_all(&db)
        .await
        {
            Ok(res) => {
                for row in res {
                    let (name, r#type): (&str, &str) = (row.get("name"), row.get("type"));

                    let _ = match sqlx::query(format!("drop {type} if exists {name}").as_str())
                        .execute(&db)
                        .await
                    {
                        Ok(_) => println!("[+] dropped {} {}", r#type, name),
                        Err(e) => {
                            eprintln!("[table/view dropping] ERROR: {e:?}");
                            process::exit(1)
                        }
                    };
                }
            }
            Err(e) => {
                eprintln!("[database cleanup] ERROR: {e:?}");
                process::exit(1)
            }
        };

        println!("[#] dropped tables and views");
    }
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
