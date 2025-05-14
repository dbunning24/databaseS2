---- tables setup and normalisation
-- location data - creates tables and inserts relevant data from raw results table

CREATE TABLE countries (
    country_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    country_name VARCHAR(100) NOT NULL
);
INSERT INTO countries (country_name)
    SELECT DISTINCT country_name FROM election_results_raw;

CREATE TABLE regions (
    region_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    region_name VARCHAR(100) NOT NULL,
    country_id INTEGER NOT NULL
);
INSERT INTO regions (region_name, country_id)
    SELECT DISTINCT e.region_name, c.country_id 
    FROM election_results_raw e 
    INNER JOIN countries c ON c.country_name = e.country_name;

CREATE TABLE counties (
    county_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    county_name VARCHAR(100) NOT NULL,
    region_id INTEGER NOT NULL
);
INSERT INTO counties (county_name, region_id)
    SELECT DISTINCT e.county_name, r.region_id 
    FROM election_results_raw e
    INNER JOIN regions r ON r.region_name = e.region_name;

CREATE TABLE constituencies (
    constituency_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    constituency_name VARCHAR(100) NOT NULL,
    county_id INTEGER NOT NULL
);
INSERT INTO constituencies (constituency_name, county_id)
    SELECT DISTINCT e.constituency_name, c.county_id 
    FROM election_results_raw e
    INNER JOIN counties c ON c.county_name = e.county_name;

-- party data
CREATE TABLE parties (
    party_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    party_name VARCHAR(100) NOT NULL,
    abbreviation VARCHAR(10) NOT NULL
);

INSERT INTO parties (party_name, abbreviation)
    SELECT DISTINCT party_name, party_abbreviation FROM election_results_raw;

-- candidate and vote data
CREATE TABLE candidates (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    firstname VARCHAR(100) NOT NULL, 
    surname VARCHAR(100) NOT NULL, 
    gender VARCHAR(10) NOT NULL, 
    constituency INTEGER NOT NULL, -- region, county, and country can all be inferred
    party INTEGER NOT NULL,
    votes INTEGER NOT NULL
);

INSERT INTO candidates (firstname, surname, gender, constituency, party, votes)
    SELECT r.firstname, r.surname, r.gender, con.constituency_id, p.party_id, r.votes
    FROM election_results_raw r
    INNER JOIN constituencies con ON r.constituency_name = con.constituency_name 
    INNER JOIN parties p ON r.party_name = p.party_name;

CREATE TABLE results (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    system INTEGER NOT NULL,
    party INTEGER NOT NULL,
    seats INTEGER NOT NULL,
    seats_percentage INTEGER NOT NULL,
    votes_percentage INTEGER NOT NULL,
    seats_votes_percentage_difference INTEGER NOT NULL,
    party_winner INTEGER NOT NULL,
    difference_from_winner INTEGER NOT NULL
);

-- views - store results of queries without creating real tables
CREATE VIEW IF NOT EXISTS location_vote_data AS
select c.votes, 
        p.party_name , 
        con.constituency_name, 
        co.county_name, 
        r.region_name, 
        coun.country_name,
    (select count(*) from constituencies) as total_seats ,
    sum(c.votes) over () as total_votes,
    sum(c.votes) over(partition by p.party_id) as votes_by_party,
    sum(c.votes) over(partition by co.county_id) as votes_by_county,
    sum(c.votes) over(partition by p.party_id, co.county_id) as votes_by_party_by_county,
    sum(c.votes) over(partition by r.region_id) as votes_by_region,
    sum(c.votes) over(partition by p.party_id, co.region_id) as votes_by_party_by_region,
    sum(c.votes) over(partition by coun.country_id) as votes_by_country,
    sum(c.votes) over(partition by p.party_id, coun.country_id) as votes_by_party_by_country
    from parties         p, 
        constituencies   con, 
        candidates       c, 
        counties         co, 
        regions          r, 
        countries        coun
    where p.party_id = c.party 
        and con.constituency_id = c.constituency
        and co.county_id = con.county_id
        and r.region_id = co.region_id
        and coun.country_id = r.country_id;

CREATE VIEW IF NOT EXISTS con_winners AS 
    select max(votes) as votes, party_name, constituency_name
    from location_vote_data group by constituency_name;

CREATE VIEW IF NOT EXISTS party_seats as 
  select "fptp" as system, party_name, count(*) as seats, round(count(*) / cast(sum(count(*)) over() as float) * 100.0, 2) as seat_percentage
    from con_winners
    group by party_name
    
union all

select "pr" as system, party_name, 
            cast((sp.seat_percentage / 100.0) * (select distinct total_seats from location_vote_data)
                as integer
            ) as seats,
            round(sp.seat_percentage, 2)
            from (select pv.party_name, pv.votes / cast(sum(pv.votes) over() as float) * 100.0 as seat_percentage from party_votes pv) sp
            where seats > 0
            and sp.party_name = party_name
union all

select "pr_th" as system, party_name, 
            cast((sp.seat_percentage / 100.0) * (select distinct total_seats from location_vote_data)
                as integer
            ) as seats,
            round(sp.seat_percentage, 2)
            from (select pv.party_name, pv.votes / cast(sum(pv.votes) over() as float) * 100.0 as seat_percentage from party_votes_threshold pv) sp
            where seats > 0
            and sp.party_name = party_name
            
union all
-- UNFINSIHED - calculate seat percentages for the rest of the systems
select "pr_county" as system, party_name, sum(party_seats_per_county) as seats, round(sum(party_seats_per_county) / cast((select distinct total_seats from location_vote_data) as float) * 100, 2) as seat_percentage
 from (
    select distinct
        lvd.party_name, 
        lvd.county_name,
        cast((votes_by_party_by_county / cast(votes_by_county as float)) * total.seats as integer) as party_seats_per_county
        from location_vote_data lvd
        join (select distinct county_name, 
            count(distinct constituency_name) as seats
            from location_vote_data 
            group by county_name
        ) total ON total.county_name = lvd.county_name
)
group by party_name
having seats > 0 and seat_percentage > 0

union all

select "pr_region" as system, party_name, sum(party_seats_per_region) as seats, round(sum(party_seats_per_region) / cast((select distinct total_seats from location_vote_data) as float) * 100) as seat_percentage 
from (
    select distinct
        lvd.party_name, 
        lvd.region_name,
        cast((votes_by_party_by_region / cast(votes_by_region as float)) * total.seats as integer) as party_seats_per_region
        from location_vote_data lvd
        join (select distinct region_name, 
            count(distinct constituency_name) as seats
            from location_vote_data 
            group by region_name
        ) total ON total.region_name = lvd.region_name
)
group by party_name
having seats > 0 and seat_percentage > 0

union all

select "pr_country" as system, party_name, sum(party_seats_per_country) as seats, round(sum(party_seats_per_country) / cast((select distinct total_seats from location_vote_data) as float) * 100, 2) as seat_percentage
from (
    select distinct
        lvd.party_name, 
        lvd.country_name,
        cast((votes_by_party_by_country / cast(votes_by_country as float)) * total.seats as integer) as party_seats_per_country
        from location_vote_data lvd
        join (select distinct country_name, 
            count(distinct constituency_name) as seats
            from location_vote_data 
            group by country_name
        ) total ON total.country_name = lvd.country_name
)
group by party_name
having seats > 0 and seat_percentage > 0
order by seats desc;


CREATE VIEW IF NOT EXISTS party_votes AS
    select p.party_name , sum(c.votes) as votes
    from candidates c, parties p
    where c.party = p.party_id
    group by party_name;

CREATE VIEW IF NOT EXISTS party_votes_threshold AS
    select party_name, votes from party_votes
    where votes > (
        select cast(sum(votes) / 100.0 as float) * 5.0 
    from party_votes);


CREATE VIEW IF NOT EXISTS vp_pr AS
   select pv.party_name, pv.votes / cast(sum(pv.votes) over() as float) * 100.0 
            as vote_percentage from party_votes pv;

CREATE VIEW IF NOT EXISTS vp_threshold AS
    select pv.party_name, pv.votes / cast(sum(pv.votes) over() as float) * 100.0
            as vote_percentage from party_votes_threshold pv;
        