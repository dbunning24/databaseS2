INSERT INTO results 
select "D'Hondt (country)" as system, 
        p.party_name as party, 
        ps.seats,
        ps.seat_percentage,
        ps.vote_percentage,
        IIF(
            ps.seat_percentage < ps.vote_percentage, 
            "-" || round(ps.vote_percentage - ps.seat_percentage, 2),
            "+" || round(ps.seat_percentage - ps.vote_percentage, 2)
        ) as [difference between percentage of votes and seats],
        (select party_name from party_seats where system = "dh_country" order by seats desc limit 1) as [winning party],
        max(ps.seats) over() - ps.seats as [seat difference from winner]
    from parties p
        join party_seats ps on ps.party_name = p.party_name
        where ps.system = "dh_country"
        and ps.seats > 0
        order by ps.seats desc;