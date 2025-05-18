INSERT INTO results 
select "Largest Remainder (county)" as system, 
        p.party_name as party, 
        ps.seats,
        ps.seat_percentage,
        ps.vote_percentage,
        IIF(
            ps.seat_percentage < ps.vote_percentage, 
            "-" || round(ps.vote_percentage - ps.seat_percentage, 2),
            "+" || round(ps.seat_percentage - ps.vote_percentage, 2)
        ) as difference_between_percentage_of_votes_of_and_seats,
        (select party_name from party_seats where system = "lr_county" order by seats desc limit 1) as winning_party,
        max(ps.seats) over() - ps.seats as seat_difference_from_winner
    from parties p
        join party_seats ps on ps.party_name = p.party_name
        where ps.system = "lr_county"
        and ps.seats > 0
        order by ps.seats desc;