select party_name, 
    county_name,
    dec_seats, 
    cast(dec_seats as integer) as seats, 
    dec_seats - cast(dec_seats as integer) as remainder,
    sum(cast(dec_seats as integer)) over(partition by county_name) as total_seats,
    county_seats - sum(cast(dec_seats as integer)) over(partition by county_name) as remaining_seats
from (
    select distinct lvd.party_name, 
        ls.name as county_name, 
        lvd.votes_by_county,
        lvd.votes_by_party_by_county,
        ls.seats as county_seats, 
        lvd.votes_by_county / cast(ls.seats as float) as quota,
        lvd.votes_by_party_by_county / (lvd.votes_by_county / cast(ls.seats as float)) as dec_seats
    from location_vote_data lvd
    join loc_seats ls where ls.name = lvd.county_name
    order by ls.name
) 
group by county_name, party_name
order by county_name, remainder desc