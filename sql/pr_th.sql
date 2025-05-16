select "Proportional Representation with 5% threshold" as system, 
        p.party_name as party, 
        ps.seats,
        ps.seat_percentage,
        ps.vote_percentage,
        IIF(
            ps.seat_percentage < ps.vote_percentage, 
            "-" || round(ps.vote_percentage - ps.seat_percentage, 2),
            "+" || round(ps.seat_percentage - ps.vote_percentage, 2)
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
        where ps.system = "pr_th"
        order by ps.seats desc;