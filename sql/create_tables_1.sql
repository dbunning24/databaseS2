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
    sum(c.votes) over(partition by p.party_id) / cast(sum(c.votes) over() as float) as total_vote_percentage,
    
    sum(c.votes) over(partition by co.county_id) as votes_by_county,
    sum(c.votes) over(partition by p.party_id, co.county_id) as votes_by_party_by_county,
    
    sum(c.votes) over(partition by r.region_id) as votes_by_region,
    sum(c.votes) over(partition by p.party_id, r.region_id) as votes_by_party_by_region,
    
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

CREATE VIEW IF NOT EXISTS loc_seats AS
    select distinct county_name as name, "county" as level,
        count(distinct constituency_name) as seats 
        from location_vote_data 
        group by county_name

    union all

    select distinct region_name as name, "region" as level,
        count(distinct constituency_name) as seats 
        from location_vote_data 
        group by region_name
        
    union all
        
    select distinct country_name as name, "country" as level,
        count(distinct constituency_name) as seats 
        from location_vote_data 
        group by country_name;

-- calculate largest remainder results
CREATE TABLE IF NOT EXISTS lr_results AS
    select "county" as level,
        party_name, 
        loc_name,
        dec_seats, 
        cast(dec_seats as integer) as seats, 
        dec_seats - cast(dec_seats as integer) as remainder,
        sum(cast(dec_seats as integer)) over(partition by loc_name) as allocated_seats,
        loc_seats - sum(cast(dec_seats as integer)) over(partition by loc_name) as remaining_seats,
        loc_seats,
        0 as updated_seats,
        0 as seat_percentage,
        (votes_by_party_by_county / cast(votes_by_county as float)) *  100 as vote_percentage
    from (
        select distinct lvd.party_name, 
            ls.name as loc_name, 
            lvd.votes_by_county,
            lvd.votes_by_party_by_county,
            ls.seats as loc_seats, 
            lvd.votes_by_county / cast(ls.seats as float) as quota,
            lvd.votes_by_party_by_county / (lvd.votes_by_county / cast(ls.seats as float)) as dec_seats
        from location_vote_data lvd
        join loc_seats ls where ls.name = lvd.county_name
        order by ls.name
    )
group by loc_name, party_name

union all

select "region" as level,
        party_name, 
        loc_name,
        dec_seats, 
        cast(dec_seats as integer) as seats, 
        dec_seats - cast(dec_seats as integer) as remainder,
        sum(cast(dec_seats as integer)) over(partition by loc_name) as allocated_seats,
        loc_seats - sum(cast(dec_seats as integer)) over(partition by loc_name) as remaining_seats,
        loc_seats,
        0 as updated_seats,
        0 as seat_percentage,
        (votes_by_party_by_region / cast(votes_by_region as float)) *  100 as vote_percentage
    from (
        select distinct lvd.party_name, 
            ls.name as loc_name, 
            lvd.votes_by_region,
            lvd.votes_by_party_by_region,
            ls.seats as loc_seats, 
            lvd.votes_by_region / cast(ls.seats as float) as quota,
            lvd.votes_by_party_by_region / (lvd.votes_by_region / cast(ls.seats as float)) as dec_seats
        from location_vote_data lvd
        join loc_seats ls where ls.name = lvd.region_name
        order by ls.name
    )
group by loc_name, party_name

union all

select "country" as level,
        party_name, 
        loc_name,
        dec_seats, 
        cast(dec_seats as integer) as seats, 
        dec_seats - cast(dec_seats as integer) as remainder,
        sum(cast(dec_seats as integer)) over(partition by loc_name) as allocated_seats,
        loc_seats - sum(cast(dec_seats as integer)) over(partition by loc_name) as remaining_seats,
        loc_seats,
        0 as updated_seats,
        0 as seat_percentage,
        (votes_by_party_by_country / cast(votes_by_country as float)) *  100 as vote_percentage
    from (
        select distinct lvd.party_name, 
            ls.name as loc_name, 
            lvd.votes_by_country,
            lvd.votes_by_party_by_country,
            ls.seats as loc_seats, 
            lvd.votes_by_country / cast(ls.seats as float) as quota,
            lvd.votes_by_party_by_country / (lvd.votes_by_country / cast(ls.seats as float)) as dec_seats
        from location_vote_data lvd
        join loc_seats ls where ls.name = lvd.country_name
        order by ls.name
    )
group by loc_name, party_name
order by loc_name, remainder desc;

CREATE TABLE IF NOT EXISTS dh_results AS
    select "county" as level, w.*, ls.seats as loc_seats from (
        select distinct 
            party_name, 
            county_name as loc_name, 
            votes_by_party_by_county as votes,
            0 as seats
        from location_vote_data 
    ) w
    join loc_seats ls on ls.name = loc_name

union all 

    select "region" as level, w.*, ls.seats as loc_seats from (
        select distinct 
            party_name, 
            region_name as loc_name, 
            votes_by_party_by_region as votes,
            0 as seats
        from location_vote_data 
    ) w
    join loc_seats ls on ls.name = loc_name

union all 

    select "country" as level, w.*, ls.seats as loc_seats from (
        select distinct 
            party_name, 
            country_name as loc_name, 
            votes_by_party_by_country as votes,
            0 as seats
        from location_vote_data 
    ) w
    join loc_seats ls on ls.name = loc_name

    order by loc_name desc;

CREATE VIEW IF NOT EXISTS dh_quot AS
    select level, 
    party_name, 
    loc_name, 
    max(votes / cast(seats + 1 as float)) as quot 
    from dh_results group by loc_name, level;

CREATE TABLE IF NOT EXISTS results (
    system VARCHAR(100) NOT NULL,
    party VARCHAR(100) NOT NULL,
    seats INTEGER NOT NULL,
    seat_percentage FLOAT NOT NULL,
    vote_percentage FLOAT NOT NULL,
    difference_between_percentage_of_votes_and_seats FLOAT NOT NULL,
    winning_party VARCHAR(100) NOT NULL,
    seat_difference_from_winner INTEGER NOT NULL
);