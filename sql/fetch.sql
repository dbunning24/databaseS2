select s.system_name, v.party_name, v.seats, 
        round(v.seats / cast(sum(v.seats) over() as float) * 100.0, 2),
        (select party_name from party_seats limit 1),
        ((select seats from party_seats limit 1) - v.seats)
    from systems s, party_seats v where s.id = 1
    group by system_name, party_name;   