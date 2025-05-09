select s.system_name as system, 
        p.party_name as party, 
        v.seats, 
        sp.[%seats],
        vp.[%votes],
        IIF(
            sp.[%seats] < vp.[%votes], 
            "-"||(select vp.[%votes] - sp.[%seats]),
            "+" || (select sp.[%seats] - vp.[%votes])
        ) as [difference between percentage of votes and seats],
        (select p.party_name from 
            parties p, 
            (select party_id, max(seats) 
                from party_seats
            ) w 
            where p.party_id = w.party_id
        ) as [winning party],
        ((select max(seats) from party_seats) - v.seats) as [seat difference from winner]
    from systems s, 
        party_seats v, 
        parties p, 
        party_votes pv,
        (select v.party_id, round(v.seats / cast(sum(v.seats) over() as float) * 100.0, 2) 
            as [%seats] from party_seats v
        ) sp, 
        (select pv.party, round(pv.votes / cast(sum(pv.votes) over() as float) * 100.0, 2) 
            as [%votes] from party_votes pv
        ) vp
    where s.id = 1 
        and p.party_id = v.party_id
        and pv.party = p.party_id 
        and sp.party_id = pv.party 
        and vp.party = sp.party_id;
        
