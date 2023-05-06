-- 1. 
SELECT COUNT(DISTINCT year)
FROM homegames;

--2. 
SELECT namefirst, namelast, height, weight, g_all, teamID
FROM people
LEFT JOIN appearances
USING(playerid)
WHERE height = (SELECT MIN(height)
			   	FROM people)

-- 3.
WITH dupedrop AS (
	SELECT namefirst, namelast, schoolid, min(yearid), people.playerid
	FROM people
	LEFT JOIN collegeplaying
	USING(playerid)
	WHERE schoolid = 'vandy'
	GROUP BY namefirst, namelast, schoolid, people.playerid
)

SELECT namefirst, namelast, SUM(salary) AS total_salary
FROM dupedrop
LEFT JOIN salaries
USING(playerid)
WHERE salary IS NOT NULL
GROUP BY namefirst, namelast
ORDER BY total_salary DESC

-- 4.
SELECT 
	CASE WHEN pos = 'OF' THEN 'Outfield'
	WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
	WHEN pos IN ('P', 'C') THEN 'Battery'
	END AS position,
	SUM(PO)
FROM fielding
WHERE yearid = 2016
GROUP BY position




-- 5.
SELECT CASE WHEN yearid BETWEEN 1920 AND 1929 THEN '1920s'
	WHEN yearid BETWEEN 1930 AND 1939 THEN '1930s'
	WHEN yearid BETWEEN 1940 AND 1949 THEN '1940s'
	WHEN yearid BETWEEN 1950 AND 1959 THEN '1950s'
	WHEN yearid BETWEEN 1960 AND 1969 THEN '1960s'
	WHEN yearid BETWEEN 1970 AND 1979 THEN '1970s'
	WHEN yearid BETWEEN 1980 AND 1989 THEN '1980s'
	WHEN yearid BETWEEN 1990 AND 1999 THEN '1990s'
	WHEN yearid BETWEEN 2000 AND 2009 THEN '2000s'
	WHEN yearid BETWEEN 2010 AND 2020 THEN '2010s'
	END AS decade,
	SUM(so) as so_batter, 
	(ROUND(CAST(SUM(SO) AS numeric)/CAST(SUM(g/2) AS numeric), 2)) AS avg_so_per_game,
	(ROUND(CAST(SUM(HR) AS numeric)/CAST(SUM(g/2) AS numeric), 2)) AS avg_hr_per_game
FROM teams
WHERE yearid >=1920
GROUP BY decade
ORDER BY decade;

-- 6.
SELECT playerid, 
	nameFirst AS first_name, 
	nameLast AS last_name,
	ROUND(CAST(SUM(SB) AS numeric)/CAST((SUM(SB)+SUM(CS)) AS numeric), 2) AS perc_steal_success,
	SUM(SB) AS steal_success, 
	SUM(CS) AS steal_failure
FROM people
LEFT JOIN batting
USING(playerid)
WHERE yearID = 2016
GROUP BY playerid, first_name, last_name
HAVING (SUM(SB)+SUM(CS)) >= 20
ORDER BY perc_steal_success DESC;

-- 7.
-- A
SELECT yearid, teamid, w, wswin
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
	AND wswin = 'N'
ORDER BY w DESC;

-- B
SELECT yearid, teamid, w, wswin
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
	AND wswin = 'Y'
ORDER BY w;

-- C
WITH winnies AS (
	SELECT yearid, teamid, w, wswin,
	MAX(w) OVER(PARTITION BY yearid) AS most_wins,
	CASE WHEN wswin = 'Y' THEN CAST(1 AS numeric)
		ELSE CAST(0 AS numeric) END AS ynbin
	FROM teams
	WHERE yearid BETWEEN 1970 AND 2016
)

SELECT SUM(ynbin) AS most_wins_wswin, COUNT(DISTINCT yearid) AS all_years, ROUND(SUM(ynbin)/COUNT(DISTINCT yearid)*100,2) AS perc_most_wins_wswin
FROM winnies
WHERE w = most_wins;

-- 8.
--Looking at top:
SELECT park_name, teams.name AS team, SUM(h.attendance)/SUM(h.games) AS avg_attendance
FROM homegames AS h
LEFT JOIN parks
USING(park)
LEFT JOIN teams
ON h.team = teams.teamid AND h.year = teams.yearid
WHERE year = 2016
GROUP BY park_name, teams.name
HAVING SUM(games) >= 10
ORDER BY avg_attendance DESC

--Looking at bottom:
SELECT park_name, teams.name AS team, SUM(h.attendance)/SUM(h.games) AS avg_attendance
FROM homegames AS h
LEFT JOIN parks
USING(park)
LEFT JOIN teams
ON h.team = teams.teamid AND h.year = teams.yearid
WHERE year = 2016
GROUP BY park_name, teams.name
HAVING SUM(games) >= 10
ORDER BY avg_attendance

-- 9.
WITH tsn_nl AS
(SELECT playerid, awardid, yearid, lgid
FROM awardsmanagers
WHERE awardid = 'TSN Manager of the Year'
	AND lgid = 'NL'),

tsn_al AS
(SELECT playerid, awardid, yearid, lgid
FROM awardsmanagers
WHERE awardid = 'TSN Manager of the Year'
	AND lgid = 'AL'),
	
winners_only AS
(SELECT tsn_nl.playerid, namefirst, namelast,
	tsn_nl.awardid, 
	tsn_nl.yearid AS nl_year, 
	tsn_al.yearid AS al_year
FROM tsn_nl
INNER JOIN tsn_al
USING(playerid)
LEFT JOIN people
USING(playerid))

SELECT subq.playerid, namefirst, namelast, team, awardid, year, league
FROM(SELECT nl_year AS year, playerid, namefirst, namelast, awardid
	 FROM winners_only
	 UNION
	 SELECT al_year, playerid, namefirst, namelast, awardid
	 FROM winners_only) AS subq
LEFT JOIN
(SELECT nl_year AS year, 'nl' AS league
	 FROM winners_only
	 UNION
	 SELECT al_year AS year, 'al'
	 FROM winners_only) AS subq2
USING(year)
LEFT JOIN 
(SELECT playerid, yearid, teamid, name AS team
FROM managers
LEFT JOIN teams
USING(teamid, yearid)) AS subq3
ON subq.playerid = subq3.playerid AND subq.year = subq3.yearid
ORDER BY year;

-- 10.

WITH hr_sixteen AS
(SELECT playerid, yearid, SUM(hr) as player_hr_sixteen
FROM batting
WHERE yearid = 2016
GROUP by playerid, yearid
ORDER BY player_hr_sixteen DESC),

yearly_hr AS
(SELECT playerid, yearid, SUM(hr) AS hr_yearly,
 	MAX(SUM(hr)) OVER(PARTITION BY playerid) AS best_year_hrs
FROM batting
GROUP BY playerid, yearid),

yp AS
(SELECT COUNT(DISTINCT yearid) AS years_played, playerid
FROM batting
GROUP BY playerid)

SELECT playerid, namefirst, namelast, hr_yearly AS total_hr_2016, years_played
FROM yearly_hr
INNER JOIN hr_sixteen
USING(playerid)
INNER JOIN yp
USING(playerid)
INNER JOIN people
USING(playerid)
WHERE best_year_hrs = player_hr_sixteen
	AND hr_yearly > 0
	AND yearly_hr.yearid = 2016
	AND years_played >= 10
ORDER BY playerid

--11.
SELECT
    s.yearID AS Year,
    SUM(salary) AS TotalSalary,
    SUM(w.W) AS TotalWins
FROM
    salaries s
    INNER JOIN teams t ON s.teamID = t.teamID AND s.yearID = t.yearID
    INNER JOIN (
        SELECT yearID, teamID, MAX(W) AS W
        FROM teams
        GROUP BY yearID, teamID
    ) w ON t.yearID = w.yearID AND t.teamID = w.teamID
WHERE
    s.yearID >= 2000
GROUP BY
    s.yearID
ORDER BY
    s.yearID;

--12
--I
SELECT
    t.yearID AS Year,
    t.teamID AS TeamID,
    t.name AS TeamName,
    t.W AS Wins,
    a.attendance AS Attendance
FROM
    teams t
    INNER JOIN (
        SELECT
            yearID,
            teamID,
            SUM(attendance) AS attendance
        FROM
            games
        WHERE
            home_team = 1
        GROUP BY
            yearID,
            teamID
    ) a ON t.yearID = a.yearID AND t.teamID = a.teamID
ORDER BY
    t.yearID,
    t.teamID;

-- II
SELECT
    t1.yearID AS Year,
    t1.teamID AS TeamID,
    t1.name AS TeamName,
    t1.WSWin AS WorldSeriesWin,
    t2.attendance AS Attendance,
    t2.postseason AS MadePlayoffs
FROM
    teams t1
    INNER JOIN (
        SELECT
            yearID + 1 AS nextYear,
            teamID,
            attendance,
            CASE WHEN WSWin = 'Y' THEN 1 ELSE 0 END AS postseason
        FROM
            teams
    ) t2 ON t1.yearID = t2.nextYear AND t1.teamID = t2.teamID
WHERE
    t1.yearID >= 1903 -- Assuming World Series started in 1903
ORDER BY
    t1.yearID;

