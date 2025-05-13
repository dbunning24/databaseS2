-- first past the post by constituency
select "First Past the Post" as system, 
        p.party_name as party, 
        ps.seats,
        sp.seat_percentage,
        vp.vote_percentage,
        IIF(
            sp.seat_percentage < vp.vote_percentage, 
            "-"|| round(vp.vote_percentage - sp.seat_percentage, 2),
            "+" || round(sp.seat_percentage - vp.vote_percentage, 2)
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
    join party_votes pv on pv.party_name = p.party_name
    join party_seats ps on ps.party_name = p.party_name
    join (select 
                ps.party_name,
                round(ps.seats / cast(sum(ps.seats) over() as float) * 100.0, 2) as seat_percentage 
            from party_seats ps where ps.system = "fptp"
        ) sp on sp.party_name = p.party_name 
    join (select pv.party_name, 
            round(pv.votes / cast(sum(pv.votes) over() as float) * 100.0, 2) as vote_percentage 
        from party_votes pv
        ) vp on vp.party_name = p.party_name
        
    where ps.system = "fptp"
    order by seats desc;

-- Proportional Representation
select "Proportional Representation" as system, 
        p.party_name as party, 
        ps.seats,
        sum(ps.seats) over() as total_seats,
        sp.seat_percentage,
        vp.vote_percentage,
        IIF(
            sp.seat_percentage < vp.vote_percentage, 
            "-" || round(vp.vote_percentage - sp.seat_percentage, 2),
            "+" || round(sp.seat_percentage - vp.vote_percentage, 2)
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
        join party_votes pv on pv.party_name = p.party_name
        join party_seats ps on ps.party_name = p.party_name
        join sp_pr sp on sp.party_name = p.party_name
        join vp_pr vp on vp.party_name = p.party_name
        where ps.system = "pr"
        and ps.seats > 0
        order by ps.seats desc;

-- proportional representation with 5% threshold
select "Proportional Representation with 5% threshold" as system, 
        p.party_name as party, 
        ps.seats,
        sp.seat_percentage,
        vp.vote_percentage,
        IIF(
            sp.seat_percentage < vp.vote_percentage, 
            "-" || round(vp.vote_percentage - sp.seat_percentage, 2),
            "+" || round(sp.seat_percentage - vp.vote_percentage, 2)
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
        join party_votes pv on pv.party_name = p.party_name
        join party_seats ps on ps.party_name = p.party_name
        join sp_threshold sp on sp.party_name = p.party_name
        join vp_threshold vp on vp.party_name = p.party_name
        where system = "pr_th"
        order by ps.seats desc;
        
