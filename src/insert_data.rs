use sqlx::{Pool, Sqlite};
use std::{fs::read_to_string, process};

pub async fn insert_data(db: &Pool<Sqlite>) {
    let files = [
        "fptp".to_string(),       // First Past the Post
        "pr".to_string(),         // Proportional Representation
        "pr_th".to_string(),      // Proportional Representation with 5% threshold
        "pr_county".to_string(),  // Proportioanl Representation by County
        "pr_region".to_string(),  // Proportioanl Representation by Region
        "pr_country".to_string(), // Proportional Representation by Country
        "lr_county".to_string(),  // Largest Remainder by County
        "lr_region".to_string(),  // Largest Remainder by Region
        "lr_country".to_string(), // Largest Remainder by Country
        "dh_county".to_string(),  // D'Hondt by County
        "dh_region".to_string(),  // D'Hondt by Region
        "dh_country".to_string(), // D'Hondt by Country
        "hybrid".to_string(),     // Hybrid system - uses average of seats from all previous systems
    ];

    for file in files {
        let file_name = format!("sql/{file}.sql");
        let query = read_to_string(file_name).expect("couldnt read file");
        match sqlx::query(&query).fetch_all(db).await {
            Ok(e) => {
                println!("[{file}.sql] completed");
            }
            Err(e) => {
                eprintln!("[{file}.sql] ERROR: {e:?}");
                process::exit(1)
            }
        }
    }
}
