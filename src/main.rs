use sqlx::{error::DatabaseError, migrate::MigrateDatabase, Sqlite, SqlitePool};
use std::error::Error;
mod utils;

const DB_URL: &'static str = "sqlite://sqlite.db";

#[tokio::main]
async fn main(){
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
    let db = SqlitePool::connect(DB_URL).await.unwrap();
    let res = match sqlx::query(include_str!("../sql/create_tables.sql")).execute(&db).await {
        Ok(e) => {
            println!("{e:?}");
            e
        },
        Err(e) => {
            eprintln!("{e:?}");
            panic!();
        }
    };
}