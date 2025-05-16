use core::panic;
use csv::ReaderBuilder;
use sqlx::{FromRow, Pool, Row, Sqlite, SqlitePool, migrate::MigrateDatabase, sqlite::SqliteRow};
use std::{
    fs::{File, read},
    io::BufReader,
    process,
};
#[derive(FromRow, Debug, Clone)]
pub struct Results {
    pub system: String,
    pub party: String,
    pub seats: i32,
    pub seats_percentage: i8,
    pub vote_percentage: i8,
    pub seats_votes_percentage_difference: i16,
    pub party_winner: String,
    pub difference_from_winner: i32,
}

#[derive(FromRow, Debug, Clone)]
pub struct LrSetupRes {
    pub party_name: String,
    pub county_name: String,
    pub seats: i32
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
    }

    match sqlx::query(include_str!("../sql/create_tables_1.sql"))
        .execute(&db)
        .await
    {
        Ok(_) => println!("[+] rebuilt all tables"),
        Err(e) => {
            eprintln!("[create_tables.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };

    calculate_lr_data(&db).await;

    match sqlx::query(include_str!("../sql/create_tables_2.sql"))
        .execute(&db)
        .await
    {
        Ok(_) => println!("[+] rebuilt all views"),
        Err(e) => {
            eprintln!("[create_views.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };

    db
}

async fn calculate_lr_data(db: &Pool<Sqlite>) {

    // get all counties
    let mut counties: Vec<String> = Vec::new();
    match sqlx::query("select county_name from counties").fetch_all(db).await {
        Ok(e) => {
            for row in &e {
                let county: &str = row.get("county_name");
                counties.push(county.to_string());
            }
        }
        Err(_) => ()
    }

    // iterate over counties and perform calculations
    for county in counties {
        match sqlx::query("select * from lr_results where county_name = $1").bind(&county).fetch_all(db).await {
            Ok(e) => {
                let mut res: Vec<LrSetupRes> = Vec::new();
                let mut remaining_seats = 0;
                for row in &e {
                    res.push( 
                        LrSetupRes { 
                            party_name: row.get::<&str, &str>("party_name").to_string(),
                            county_name: row.get::<&str, &str>("county_name").to_string(), 
                            seats: row.get::<i32, &str>("seats")
                        }
                    );
                    remaining_seats = row.get("remaining_seats");
                }
                //println!("{res:#?}");
                let mut cursor = 0;
                while remaining_seats > 0 {
                    if cursor >= res.len() {cursor = 0}
                    res.get_mut(cursor).unwrap().seats += 1;
                    cursor += 1;
                    remaining_seats -= 1;
                }
                for val in &res {
                    sqlx::query("
                        update lr_results set updated_seats = $1 where party_name = $2 and county_name = $3;
                        update lr_results set seat_percentage = (updated_seats / cast(county_seats as float)) * 100 where party_name = $2 and county_name = $3;")
                        .bind(&val.seats)
                        .bind(&val.party_name)
                        .bind(&val.county_name)
                        .execute(db).await.unwrap();
                }

            } 
            Err(_) => ()
        }
    }

    println!("[calculate lr data] largest remainder data calculated")

}