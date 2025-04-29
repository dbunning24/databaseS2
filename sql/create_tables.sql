---- tables setup and normalisation
drop table if exists election_results; 
drop table if exists constituencies; 
drop table if exists counties; 
drop table if exists regions; 
drop table if exists countries;
drop table if exists parties;
drop table if exists parties_short; 
drop table if exists candidates; 
drop table if exists candidate_genders; 
drop table if exists candidate_votes;

-- election results table
create table election_results (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    constituency_name VARCHAR(150) NOT NULL,
    county_name VARCHAR(100) NOT NULL,
    region_name VARCHAR(100) NOT NULL, 
    country_name VARCHAR(100) NOT NULL, 
    party_name VARCHAR(100) NOT NULL,
    party_abbreviation VARCHAR(100) NOT NULL,
    firstname VARCHAR(100) NOT NULL,
    surname VARCHAR(100) NOT NULL,
    gender VARCHAR(10) NOT NULL,
    votes INTEGER NOT NULL
);

insert into election_results (
    constituency_name,county_name,region_name,country_name,party_name,party_abbreviation,firstname,surname,gender,votes
) select * from election_results_raw;

-- location tables
create table constituencies as 
    select id, constituency_name from election_results;

create table counties as 
    select id, county_name from election_results;

create table regions as
    select id, region_name from election_results;

create table countries as 
    select id, country_name from election_results;

-- party tables
create table parties as 
    select id, party_name from election_results;

create table parties_short as 
    select id, party_abbreviation from election_results;

-- candidate tables
create table candidates as 
    select id, firstname, surname from election_results;

create table candidate_genders as 
    select id, gender from election_results;

create table candidate_votes as 
    select id, votes from election_results;

