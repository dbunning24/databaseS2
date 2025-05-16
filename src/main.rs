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

    /*
    // FPTP 
    let fptp = match sqlx::query(include_str!("../sql/fptp.sql"))
    .fetch_all(&db)
    .await
    {
        Ok(e) => {
                println!("[fptp.sql] completed");
                e
            },
        Err(e) => {
            eprintln!("[fptp.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };
    
     // Proportional Representation
    let pr = match sqlx::query(include_str!("../sql/pr.sql"))
    .fetch_all(&db)
    .await
    {
        Ok(e) => {
            println!("[pr.sql] completed");
            e
        },
        Err(e) => {
            eprintln!("[pr.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };

     // Proportional Representation with 5% threshold
    let pr_th = match sqlx::query(include_str!("../sql/pr_th.sql"))
    .fetch_all(&db)
    .await
    {
        Ok(e) => {
            println!("[pr_th.sql] completed");
            e
        },
        Err(e) => {
            eprintln!("[pr_th.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };

     // Proportional Representation by county
    let pr_county= match sqlx::query(include_str!("../sql/pr_county.sql"))
    .fetch_all(&db)
    .await
    {
        Ok(e) => {
            println!("[pr_county.sql] completed");
            e
        },
        Err(e) => {
            eprintln!("[pr_county.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };
    
     // Proportional Representation by region
    let pr_region = match sqlx::query(include_str!("../sql/pr_region.sql"))
    .fetch_all(&db)
    .await
    {
        Ok(e) => {
            println!("[pr_region.sql] completed");
            e
        },
        Err(e) => {
            eprintln!("[pr_region.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };

     // Proportional Representation by country
    let pr_country = match sqlx::query(include_str!("../sql/pr_country.sql"))
    .fetch_all(&db)
    .await
    {
        Ok(e) => {
            println!("[pr_county.sql] completed");
            e
        },
        Err(e) => {
            eprintln!("[pr_country.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };*/

     /* Largest Remainder
    let lr = match sqlx::query(include_str!("../sql/lr.sql"))
    .fetch_all(&db)
    .await
    {
        Ok(e) => {
            for row in sqlx::query("select county_name from counties").fetch_all(&db).await.unwrap() {
                let county: &str = row.get("county_name");
            };
            //println!("{} {} {}", row.get::<&str, &str>("party_name"), row.get::<&str, &str>("county_name"), row.get::<i32, &str>("seats"))
            println!("[lr.sql] setup completed");
            e
        },
        Err(e) => {
            eprintln!("[lr.sql] ERROR: {e:?}");
            process::exit(1)
        }
    };*/

    match sqlx::query(format!("select * from ({}) where county_name = 'Avon';", include_str!("../sql/lr.sql")).as_str()).fetch_all(&db).await {
        Ok(e) => {
            let mut res: Vec<LrSetupRes> = Vec::new();
            for row in e {
                let remaining_seats: i32 = row.get("remaining_seats");
                res.push( 
                    LrSetupRes { 
                        party_name: row.get::<&str, &str>("party_name").to_string(),
                        county_name: row.get::<&str, &str>("county_name").to_string(), 
                        seats: row.get::<i32, &str>("seats")
                    }
                );
            }
            println!("{res:?}");
        }
        Err(_) => ()
    }


}
