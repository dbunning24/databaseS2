use sqlx::prelude::FromRow;

#[derive(FromRow, Debug, Clone)]
pub struct PartyConstituency {
    pub votes: i32,
    #[sqlx(rename = "party_name")]
    pub party: String,
    #[sqlx(rename = "constituency_name")]
    pub con: String,
}
