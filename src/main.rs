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

    // First past the post by Constituency
    let firstPastPost =
        match sqlx::query_as::<_, PartyConstituency>
        ("select max(votes) as votes, party_name, constituency_name 
            from (
                select c.votes, p.party_name, con.constituency_name from parties p, constituencies con, candidates c  
                where p.party_id = c.party and con.constituency_id = c.constituency
            ) group by constituency_name;
        ").fetch_all(&db).await {
            
            Ok(e) => {
                for row in &e {
                    println!("[{} VOTES] -  {} - {}", row.votes, row.party, row.con);
                }
                e
            }
            Err(e) => {
                eprintln!("[-] ERROR: {e:?}");
                process::exit(1)
            }
        };
}
