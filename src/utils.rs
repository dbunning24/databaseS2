use sqlx::prelude::FromRow;

#[derive(FromRow, Debug, Clone)]
pub struct PartyConstituency {
    pub votes: i32,
    #[sqlx(rename = "party_name")]
    pub party: String,
    #[sqlx(rename = "constituency_name")]
    pub con: String,
}

pub struct Results {
    pub system: String,
    pub party: String,
    pub seats: i32,
    pub seats_percentage: i8,
    pub seats_votes_percentage_difference: i16,
    pub party_winner: String,
    pub difference_from_winner: i32,
}
