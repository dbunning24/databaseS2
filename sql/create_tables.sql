---- tables setup and normalisation
-- drop all tables to ensure everything is built correctly

drop table if exists candidates; 
drop table if exists constituencies; 
drop table if exists counties; 
drop table if exists regions; 
drop table if exists countries;
drop table if exists parties;

-- location data - creates tables and inserts relevant data from raw results table
CREATE TABLE counties (
    county_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    county_name VARCHAR(100) NOT NULL
);
INSERT INTO counties (county_name)
    SELECT DISTINCT county_name FROM election_results_raw;

CREATE TABLE countries (
    country_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    country_name VARCHAR(100) NOT NULL
);
INSERT INTO countries (country_name)
    SELECT DISTINCT country_name FROM election_results_raw;

CREATE TABLE regions (
    region_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    region_name VARCHAR(100) NOT NULL
);
INSERT INTO regions (region_name)
    SELECT DISTINCT region_name FROM election_results_raw;

CREATE TABLE constituencies (
    constituency_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    constituency_name VARCHAR(100) NOT NULL
);
INSERT INTO constituencies (constituency_name)
    SELECT DISTINCT constituency_name FROM election_results_raw;

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
