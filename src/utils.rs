use sqlx::prelude::FromRow;


#[derive(FromRow, Debug, Clone)]
pub struct Results {
    pub system: String,
    pub party: String,
    pub seats: i32,
    pub seats_percentage: i8,
    pub seats_votes_percentage_difference: i16,
    pub party_winner: String,
    pub difference_from_winner: i32,
}
