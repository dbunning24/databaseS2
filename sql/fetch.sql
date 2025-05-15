-- first past the post by constituency
select "First Past the Post" as system, 
        p.party_name as party, 
        ps.seats,
        ps.seat_percentage,
        vp.vote_percentage,
        IIF(
            ps.seat_percentage < vp.vote_percentage, 
            "-"|| round(vp.vote_percentage - ps.seat_percentage, 2), 
            "+" || round(ps.seat_percentage - vp.vote_percentage,2)
        ) as [difference between percentage of votes and seats],
        (select p.party_name from 
            parties p, 
            (select party_name, max(seats) 
                from party_seats where system = "fptp"
            ) w 
            where p.party_name = w.party_name
        ) as [winning party],
        max(ps.seats) over() - ps.seats as [seat difference from winner]
    from parties p
    join party_seats ps on ps.party_name = p.party_name
    join vp on vp.party_name = p.party_name
    where ps.system = "fptp"
    order by seats desc;
    
-- Proportional Representation
select "Proportional Representation" as system, 
        p.party_name as party, 
        ps.seats,
        ps.seat_percentage,
        vp.vote_percentage,
        IIF(
            ps.seat_percentage < vp.vote_percentage, 
            "-" || round(vp.vote_percentage - ps.seat_percentage, 2),
            "+" || round(ps.seat_percentage - vp.vote_percentage, 2)
        ) as [difference between percentage of votes and seats],
        (select p.party_name from 
            parties p, 
            (select party_name, max(seats) 
                from party_seats where system = "pr"
            ) w 
            where p.party_name = w.party_name
        ) as [winning party],
        max(ps.seats) over() - ps.seats as [seat difference from winner]
    from parties p
        join party_seats ps on ps.party_name = p.party_name
        join vp on vp.party_name = p.party_name
        where ps.system = "pr"
        and ps.seats > 0
        order by ps.seats desc;

-- proportional representation with 5% threshold
select "Proportional Representation with 5% threshold" as system, 
        p.party_name as party, 
        ps.seats,
        ps.seat_percentage,
        vp.vote_percentage,
        IIF(
            ps.seat_percentage < vp.vote_percentage, 
            "-" || round(vp.vote_percentage - ps.seat_percentage, 2),
            "+" || round(ps.seat_percentage - vp.vote_percentage, 2)
        ) as [difference between percentage of votes and seats],
        (select p.party_name from 
            parties p, 
            (select party_name, max(seats) 
                from party_seats where system = "pr_th"
            ) w 
            where p.party_name = w.party_name
        ) as [winning party],
        max(ps.seats) over() - ps.seats as [seat difference from winner]
    from parties p
        join party_seats ps on ps.party_name = p.party_name
        join (
            select pv.party_name, pv.votes / cast(sum(pv.votes) over() as float) * 100.0 as vote_percentage from party_votes_threshold pv
        ) vp on vp.party_name = p.party_name
        where ps.system = "pr_th"
        order by ps.seats desc;

select "Proportional Representation (county)" as system, 
        p.party_name as party, 
        ps.seats,
        ps.seat_percentage,
        vp.vote_percentage,
        IIF(
            ps.seat_percentage < vp.vote_percentage, 
            "-" || round(vp.vote_percentage - ps.seat_percentage, 2),
            "+" || round(ps.seat_percentage - vp.vote_percentage, 2)
        ) as [difference between percentage of votes and seats],
        (select p.party_name from 
            parties p, 
            (select party_name, max(seats) 
                from party_seats where system = "pr_county"
            ) w 
            where p.party_name = w.party_name
        ) as [winning party],
        max(ps.seats) over() - ps.seats as [seat difference from winner] 
    from parties p
        join party_seats ps on ps.party_name = p.party_name
        join (select party_name, 
            round(county_vote_percentage * 100, 2) as vote_percentage 
            from location_vote_data 
            group by party_name 
        ) vp on vp.party_name = p.party_name
        where ps.system = "pr_county"
        and ps.seats > 0
        order by ps.seats desc;

select "Proportional Representation (region)" as system, 
        p.party_name as party, 
        ps.seats,
        ps.seat_percentage,
        vp.vote_percentage,
        IIF(
            ps.seat_percentage < vp.vote_percentage, 
            "-" || round(vp.vote_percentage - ps.seat_percentage, 2),
            "+" || round(ps.seat_percentage - vp.vote_percentage, 2)
        ) as [difference between percentage of votes and seats],
        (select p.party_name from 
            parties p, 
            (select party_name, max(seats) 
                from party_seats where system = "pr_region"
            ) w 
            where p.party_name = w.party_name
        ) as [winning party],
        max(ps.seats) over() - ps.seats as [seat difference from winner]
    from parties p
        join party_seats ps on ps.party_name = p.party_name
        join vp_pr vp on vp.party_name = p.party_name
        where ps.system = "pr_region"
        and ps.seats > 0
        order by ps.seats desc;

select "Proportional Representation (country)" as system, 
        p.party_name as party, 
        ps.seats,
        ps.seat_percentage,
        vp.vote_percentage,
        IIF(
            ps.seat_percentage < vp.vote_percentage, 
            "-" || round(vp.vote_percentage - ps.seat_percentage, 2),
            "+" || round(ps.seat_percentage - vp.vote_percentage, 2)
        ) as [difference between percentage of votes and seats],
        (select p.party_name from 
            parties p, 
            (select party_name, max(seats) 
                from party_seats where system = "pr_country"
            ) w 
            where p.party_name = w.party_name
        ) as [winning party],
        max(ps.seats) over() - ps.seats as [seat difference from winner]
    from parties p
        join party_seats ps on ps.party_name = p.party_name
        join vp_pr vp on vp.party_name = p.party_name
        where ps.system = "pr_country"
        and ps.seats > 0
        order by ps.seats desc;
