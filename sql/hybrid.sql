with w as (
    select party_name, cast(sum(seats) / 12.0 as integer) as seats from party_seats group by party_name order by seats desc
),
ps as (
    select w.party_name, 
        sum(seats) as seats, 
        round(sum(seats) / cast((select distinct total_seats from location_vote_data) as float) * 100, 2) as seat_percentage,
        vp.vote_percentage 
    from w    
    join vp on vp.party_name = w.party_name
    group by w.party_name
)
INSERT INTO results 
select "Hybrid" as system, 
        p.party_name as party, 
        ps.seats,
        ps.seat_percentage,
        ps.vote_percentage,
        IIF(
            ps.seat_percentage < ps.vote_percentage, 
            "-" || round(ps.vote_percentage - ps.seat_percentage, 2),
            "+" || round(ps.seat_percentage - ps.vote_percentage, 2)
        ) as [difference between percentage of votes and seats],
        (select party_name from (select party_name, max(seats) from ps)) as [winning party],
        max(ps.seats) over() - ps.seats as [seat difference from winner]
    from parties p
        join ps on ps.party_name = p.party_name
        and ps.seats > 0
        order by ps.seats desc;
        