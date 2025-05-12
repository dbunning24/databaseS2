-- first past the post by constituency
with sp (party, seat_percentage) as (
    select 
        v.party,
        round(v.seats / cast(sum(v.seats) over() as float) * 100.0, 2) as seat_percentage 
    from party_seats v
    ), 
    vp (party, vote_percentage) as(
        select pv.party, 
            round(pv.votes / cast(sum(pv.votes) over() as float) * 100.0, 2) as vote_percentage 
        from party_votes pv
    )
select "First Past the post" as system, 
        p.party_name as party, 
        v.seats, 
        sp.seat_percentage,
        vp.vote_percentage,
        IIF(
            sp.seat_percentage < vp.vote_percentage, 
            "-"|| (select round(vp.vote_percentage - sp.seat_percentage, 2)),
            "+" || (select round(sp.seat_percentage - vp.vote_percentage, 2))
        ) as [difference between percentage of votes and seats],
        (select p.party_name from 
            parties p, 
            (select party_id, max(seats) 
                from party_seats
            ) w 
            where p.party_id = w.party_id
        ) as [winning party],
        ((select max(seats) from party_seats) - v.seats) as [seat difference from winner]
    from party_seats v, 
        parties p, 
        party_votes pv,
        sp, vp
    where p.party_name = v.party
        and pv.party = p.party_name
        and sp.party = pv.party 
        and vp.party = sp.party;

-- Proportional Representation
with sp (party, seat_percentage) as (
        select pv.party, 
            round(pv.votes / cast(sum(pv.votes) over() as float) * 100.0, 0) as seat_percentage 
        from party_votes pv
    ), 
    vp (party, vote_percentage) as(
        select pv.party, 
            round(pv.votes / cast(sum(pv.votes) over() as float) * 100.0, 2) as vote_percentage 
        from party_votes pv
    )
select "First Past the post" as system, 
        p.party_name as party, 
        v.seats, 
        sp.seat_percentage,
        vp.vote_percentage,
        IIF(
            sp.seat_percentage < vp.vote_percentage, 
            "-"|| (select round(vp.vote_percentage - sp.seat_percentage, 2)),
            "+" || (select round(sp.seat_percentage - vp.vote_percentage, 2))
        ) as [difference between percentage of votes and seats],
        (select p.party_name from 
            parties p, 
            (select party_id, max(seats) 
                from party_seats
            ) w 
            where p.party_id = w.party_id
        ) as [winning party],
        ((select max(seats) from party_seats) - v.seats) as [seat difference from winner]
    from party_seats v, 
        parties p, 
        party_votes pv,
        sp, vp
    where p.party_name = v.party_name
        and pv.party = p.party_name
        and sp.party = pv.party 
        and vp.party = sp.party;
 
-- proportional representation with 5% threshold
select "Proportional Representation with 5% threshold" as system, 
        p.party_name as party, 
        v.seats, 
        sp.seat_percentage,
        vp.vote_percentage,
        IIF(
            sp.seat_percentage < vp.vote_percentage, 
            "-"|| (select round(vp.vote_percentage - sp.seat_percentage, 2)),
            "+" || (select round(sp.seat_percentage - vp.vote_percentage, 2))
        ) as [difference between percentage of votes and seats],
        (select p.party_name from 
            parties p, 
            (select party_id, max(seats) 
                from party_seats
            ) w 
            where p.party_id = w.party_id
        ) as [winning party],
        ((select max(seats) from party_seats) - v.seats) as [seat difference from winner]
    from party_seats v, 
        parties p, 
        party_votes_threshold pv,
        (select pv.party, round(pv.votes / cast(sum(pv.votes) over() as float) * 100.0, 0) 
            as seat_percentage from party_votes_threshold pv
        ) sp, 
        (select pv.party, round(pv.votes / cast(sum(pv.votes) over() as float) * 100.0, 2) 
            as vote_percentage from party_votes_threshold pv
        ) vp
    where p.party_id = v.party_id
        and pv.party = p.party_id 
        and sp.party = pv.party 
        and vp.party = sp.party;