-- views - store results of queries without creating real tables

CREATE VIEW IF NOT EXISTS party_seats as 
  select "fptp" as system, 
    sp.party_name, sp.seats, 
    sp.seat_percentage,
    vp.vote_percentage
    from (
        select party_name, count(*) as seats,round(count(*) / cast(sum(count(*)) over() as float) * 100.0, 2) as seat_percentage
        from (
            select max(votes) as votes, party_name, constituency_name
            from location_vote_data group by constituency_name
        ) 
        group by party_name
    ) sp
    join vp on vp.party_name = sp.party_name
    
union all

select "pr" as system, 
    sp.party_name, 
    cast((sp.seat_percentage / 100.0) * (select distinct total_seats from location_vote_data)
        as integer
    ) as seats,
    round(sp.seat_percentage, 2),
    vp.vote_percentage
    from (select pv.party_name, pv.votes / cast(sum(pv.votes) over() as float) * 100.0 as seat_percentage from party_votes pv) sp
    join vp on vp.party_name = sp.party_name
    where seats > 0
    
union all

select "pr_th" as system, sp.party_name, 
    cast((sp.seat_percentage / 100.0) * (select distinct total_seats from location_vote_data)
        as integer
    ) as seats,
    round(sp.seat_percentage, 2),
    round(sp.seat_percentage, 2) as vote_percentage
    from (select pv.party_name, pv.votes / cast(sum(pv.votes) over() as float) * 100.0 as seat_percentage from ( 
        select party_name, votes_by_party as votes
            from location_vote_data
            where total_vote_percentage > 0.05
        group by party_name) pv
    ) sp
    where seats > 0
            
union all

select "pr_county" as system, party_name, sum(party_seats_per_county) as seats,
 round(sum(party_seats_per_county) / cast((select distinct total_seats from location_vote_data) as float) * 100, 2) as seat_percentage,
 vote_percentage
 from (
    select distinct
        lvd.party_name, 
        lvd.county_name,
        cast((votes_by_party_by_county / cast(votes_by_county as float)) * total.seats as integer) as party_seats_per_county,
        vp.vote_percentage
        from location_vote_data lvd
        join (select distinct county_name, 
            count(distinct constituency_name) as seats
            from location_vote_data 
            group by county_name
        ) total ON total.county_name = lvd.county_name
        join vp on vp.party_name = lvd.party_name
)
group by party_name
having seats > 0 and seat_percentage > 0

union all

select "pr_region" as system, party_name, sum(party_seats_per_region) as seats, 
round(sum(party_seats_per_region) / cast((select distinct total_seats from location_vote_data) as float) * 100) as seat_percentage,
vote_percentage
from (
    select distinct
        lvd.party_name, 
        lvd.region_name,
        cast((votes_by_party_by_region / cast(votes_by_region as float)) * total.seats as integer) as party_seats_per_region,
        vp.vote_percentage
        from location_vote_data lvd
        join (select distinct region_name, 
            count(distinct constituency_name) as seats
            from location_vote_data 
            group by region_name
        ) total ON total.region_name = lvd.region_name
        join vp on vp.party_name = lvd.party_name
)
group by party_name
having seats > 0 and seat_percentage > 0

union all

select "pr_country" as system, party_name, sum(party_seats_per_country) as seats,
round(sum(party_seats_per_country) / cast((select distinct total_seats from location_vote_data) as float) * 100, 2) as seat_percentage,
vote_percentage
from (
    select distinct
        lvd.party_name, 
        lvd.country_name,
        cast((votes_by_party_by_country / cast(votes_by_country as float)) * total.seats as integer) as party_seats_per_country,
        vp.vote_percentage
        from location_vote_data lvd
        join (select distinct country_name, 
            count(distinct constituency_name) as seats
            from location_vote_data 
            group by country_name
        ) total ON total.country_name = lvd.country_name
        join vp on vp.party_name = lvd.party_name
)
group by party_name
having seats > 0 and seat_percentage > 0


union all

select "lr_county" as system, party_name, sum(updated_seats) as seats, round(seat_percentage, 2), round(vote_percentage, 2)
from lr_results
where level = "county"
group by party_name
having seats > 0 and seat_percentage > 0

union all 

select "lr_region" as system, party_name, sum(updated_seats) as seats,  round(seat_percentage, 2), round(vote_percentage, 2)
from lr_results
where level = "region"
group by party_name
having seats > 0 and seat_percentage > 0

union all 

select "lr_country" as system, party_name, sum(updated_seats) as seats, round(seat_percentage, 2), round(vote_percentage, 2)
from lr_results
where level = "country"
group by party_name
having seats > 0 and seat_percentage > 0

union all 

select "dh_county" as system, dhr.party_name, sum(seats) as seats, round(sum(seats) / cast((select distinct total_seats from location_vote_data) as float) * 100, 2) as seat_percentage, vp.vote_percentage
from dh_results dhr
join vp on vp.party_name = dhr.party_name
where level = "county"
group by dhr.party_name
having seats > 0 and seat_percentage > 0

union all 

select "dh_region" as system, dhr.party_name, sum(seats) as seats, round(sum(seats) / cast((select distinct total_seats from location_vote_data) as float) * 100, 2) as seat_percentage, vp.vote_percentage
from dh_results dhr
join vp on vp.party_name = dhr.party_name
where level = "region"
group by dhr.party_name
having seats > 0 and seat_percentage > 0

union all 

select "dh_country" as system, dhr.party_name, sum(seats) as seats, round(sum(seats) / cast((select distinct total_seats from location_vote_data) as float) * 100, 2) as seat_percentage, vp.vote_percentage
from dh_results dhr
join vp on vp.party_name = dhr.party_name
where level = "country"
group by dhr.party_name
having seats > 0 and seat_percentage > 0

order by seats desc;

CREATE VIEW IF NOT EXISTS party_votes AS
    select party_name, votes_by_party as votes
    from location_vote_data
    group by party_name;


CREATE VIEW IF NOT EXISTS vp AS
    select party_name, 
        round(total_vote_percentage * 100, 2) as vote_percentage 
        from location_vote_data 
        where vote_percentage > 0
        group by party_name;

