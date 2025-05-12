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
        p.party_name, 
        con.constituency_name, 
        co.county_name, 
        r.region_name, 
        coun.country_name,
    (select count(*) from constituencies) as number_of_seats ,
    sum(votes) over(partition by p.party_id) as votes_by_party,
    sum(votes) over () as total_votes,
    sum(votes) over(partition by co.county_id) as votes_by_county,
    sum(votes) over(partition by p.party_id, co.county_id) as votes_by_party_by_county,
    sum(votes) over(partition by r.region_id) as votes_by_region,
    sum(votes) over(partition by p.party_id, co.region_id) as votes_by_party_by_region,
    sum(votes) over(partition by coun.country_id) as votes_by_country,
    sum(votes) over(partition by p.party_id, coun.country_id) as votes_by_party_by_country
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

CREATE VIEW IF NOT EXISTS county_winners AS 
    select max(votes) as votes, party_name, county_name
    from location_vote_data group by constituency_name;

CREATE VIEW IF NOT EXISTS party_seats as 
    select party_name, count(*) as seats 
    from con_winners
    group by party_name
    order by seats desc;

CREATE VIEW IF NOT EXISTS party_votes AS
    select party, sum(votes) as votes
    from candidates c
    group by c.party;

CREATE VIEW IF NOT EXISTS party_votes_threshold AS
    select party, votes from party_votes
    where votes > (
        select cast(sum(votes) / 100.0 as float) * 5.0 
    from party_votes)