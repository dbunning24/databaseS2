use core::panic;
use csv::ReaderBuilder;
use sqlx::{FromRow, Pool, Row, Sqlite, SqlitePool, migrate::MigrateDatabase, sqlite::SqliteRow};
use std::{
    fs::{File, read},
    io::BufReader,
    process,
};

use crate::calculate::*;

#[derive(FromRow, Debug, Clone)]
pub struct Results {
    pub system: String,
    pub party: String,
    pub seats: i32,
    pub seat_percentage: f32,
    pub vote_percentage: f32,
    pub difference_between_percentage_of_votes_and_seats: f32,
    pub winning_party: String,
    pub seat_difference_from_winner: i32,
}

#[derive(FromRow, Debug, Clone)]
pub struct LrSetupRes {
    pub party_name: String,
    pub loc_name: String,
    pub seats: i32,
}

#[derive(FromRow, Debug, Clone)]
pub struct DhSetupRes {
    pub level: String,
    pub party_name: String,
    pub loc_name: String,
    pub votes: i32,
    pub seats: i32,
    pub loc_seats: i32,
}

const DB_URL: &'static str = "sqlite://sqlite.db";

pub async fn setup() -> Pool<Sqlite> {
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
        println!("[+] found database, no reconstruction needed");
        println!(
            "[MESSAGE] if `election_results_raw` is malformed, please delete `sqlite.db` and restart the application"
        )
    }

    let db = SqlitePool::connect(DB_URL).await.unwrap();
    // get all counties, regions, and countries
    let mut counties: Vec<String> = sqlx::query("select county_name from counties")
        .fetch_all(&db)
        .await
        .unwrap()
        .iter()
        .map(|row| row.get::<String, &str>("county_name"))
        .collect();
    let mut regions: Vec<String> = sqlx::query("select region_name from regions")
        .fetch_all(&db)
        .await
        .unwrap()
        .iter()
        .map(|row| row.get::<String, &str>("region_name"))
        .collect();
    let mut countries: Vec<String> = sqlx::query("select country_name from countries")
        .fetch_all(&db)
        .await
        .unwrap()
        .iter()
        .map(|row| row.get::<String, &str>("country_name"))
        .collect();
    let mut levels: Vec<Vec<String>> = vec![counties, regions, countries];
    let mut level_names: Vec<String> = vec!["county".into(), "region".into(), "country".into()];

    match sqlx::query("SELECT name FROM sqlite_master;")
        .fetch_all(&db)
        .await
    {
        Ok(r) => {
            let names: Vec<&str> = r.iter().map(|r| r.get("name")).collect();
            if !names.contains(&"election_results_raw") {
                println!("[!] raw data table not found. reconstruction neeeded.");
                raw_data_present = false;
            }
        }
        Err(_) => (),
    }

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
    }

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
                    Ok(_) => (),
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

    println!("[#] dropped all tables and views");

    match sqlx::query(include_str!("../sql/create_tables_1.sql"))
        .execute(&db)
        .await
    {
        Ok(_) => println!("[+] rebuilt first half of tables/views"),
        Err(e) => {
            eprintln!("[create_tables_1.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };

    calculate_lr_data(&db, &levels, &level_names).await;
    calculate_dh_data(&db, &levels, &level_names).await;

    match sqlx::query(include_str!("../sql/create_tables_2.sql"))
        .execute(&db)
        .await
    {
        Ok(_) => println!("[+] rebuilt second half of tables/views"),
        Err(e) => {
            eprintln!("[create_tables_2.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };
    db
}
