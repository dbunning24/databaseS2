use crate::utils::*;
use sqlx::{FromRow, Pool, Row, Sqlite, SqlitePool, migrate::MigrateDatabase, sqlite::SqliteRow};
use std::{
    fs::{File, read},
    io::BufReader,
    process,
};

pub async fn calculate_dh_data(
    db: &Pool<Sqlite>,
    levels: &Vec<Vec<String>>,
    level_names: &Vec<String>,
) {
    for (i, level) in levels.iter().enumerate() {
        for loc in level {
            let level_name = level_names.get(i).unwrap();

            match sqlx::query(
                "select distinct loc_seats from dh_results where loc_name = $1 and level = $2",
            )
            .bind(loc)
            .bind(level_name)
            .fetch_one(db)
            .await
            {
                Ok(row) => {
                    let mut loc_seats: i32 = row.get("loc_seats");
                    while loc_seats > 0 {
                        sqlx::query(
                            "update dh_results as dhr
                                    set seats = dhr.seats + 1 
                                from dh_quot as dhq
                                where dhr.loc_name = $1
                                    and dhr.level = $2
                                    and dhq.loc_name = $1
                                    and dhq.level = $2
                                    and dhq.party_name = dhr.party_name",
                        )
                        .bind(loc)
                        .bind(level_name)
                        .execute(db)
                        .await
                        .unwrap();
                        loc_seats -= 1
                    }
                }
                Err(e) => {
                    eprintln!("[calculate dh data] ERROR: {e}");
                    process::exit(-1)
                }
            };
        }
    }
}

pub async fn calculate_lr_data(
    db: &Pool<Sqlite>,
    levels: &Vec<Vec<String>>,
    level_names: &Vec<String>,
) {
    // iterate over counties and perform calculations
    for (i, level) in levels.iter().enumerate() {
        for loc in level {
            let level_name = level_names.get(i).unwrap();
            match sqlx::query("select * from lr_results where loc_name = $1 and level = $2")
                .bind(loc)
                .bind(level_name)
                .fetch_all(db)
                .await
            {
                Ok(e) => {
                    let mut res: Vec<LrSetupRes> = Vec::new();
                    let mut remaining_seats = 0;
                    for row in &e {
                        res.push(LrSetupRes {
                            party_name: row.get::<&str, &str>("party_name").to_string(),
                            loc_name: row.get::<&str, &str>("loc_name").to_string(),
                            seats: row.get::<i32, &str>("seats"),
                        });
                        remaining_seats = row.get("remaining_seats");
                    }
                    let mut cursor = 0;
                    while remaining_seats > 0 {
                        if cursor >= res.len() {
                            cursor = 0
                        }
                        res.get_mut(cursor).unwrap().seats += 1;
                        cursor += 1;
                        remaining_seats -= 1;
                    }
                    for val in &res {
                        sqlx::query("
                            update lr_results set updated_seats = $1 where party_name = $2 and loc_name = $3 and level = $4;
                            update lr_results set seat_percentage = (updated_seats / cast(loc_seats as float)) * 100 where party_name = $2 and loc_name = $3 and level = $4;")
                            .bind(&val.seats)
                            .bind(&val.party_name)
                            .bind(&val.loc_name)
                            .bind(level_names.get(i).unwrap())
                            .execute(db).await.unwrap();
                    }
                }
                Err(e) => {
                    eprintln!("[calculate lr data] ERROR: {e}");
                    process::exit(-1)
                }
            }
        }
    }

    println!("[calculate lr data] largest remainder data calculated");
}
