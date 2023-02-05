USE portfolio_project;

-- Examine Columns in the Data
SELECT 
	location Location, 
    date Date, 
    CAST(total_cases AS UNSIGNED) TotalCases, 
    CAST(new_cases AS UNSIGNED) NewCases, 
    CAST(total_deaths AS UNSIGNED) TotalDeaths, 
    CAST(population AS UNSIGNED) Population
FROM coviddeaths
WHERE continent != ""
ORDER BY 1, 2;

-- Total Cases vs. Total Deaths
SELECT 
	location Location, 
	date Date, 
    CAST(total_cases AS UNSIGNED) TotalCases, 
    CAST(total_deaths AS UNSIGNED) TotalDeaths, 
    (CAST(total_deaths AS UNSIGNED)/CAST(total_cases AS UNSIGNED))*100 AS DeathPercentage
FROM coviddeaths
ORDER BY 1, 2;

-- Total Cases vs. Total Deaths in United States
SELECT 
	location Location, 
	date Date, 
    CAST(total_cases AS UNSIGNED) TotalCases, 
    CAST(total_deaths AS UNSIGNED) TotalDeaths, 
    (CAST(total_deaths AS UNSIGNED)/CAST(total_cases AS UNSIGNED))*100 DeathPercentage
FROM coviddeaths
WHERE location LIKE '%states'
ORDER BY 1,2;

-- Total Cases vs. Population in United States
SELECT 
	location Location, 
	date Date, 
    population Population, 
    (CAST(total_cases AS UNSIGNED)/CAST(population AS UNSIGNED))*100 InfectionPercentage
FROM coviddeaths
WHERE location LIKE '%states'
ORDER BY 1,2;




-- GLOBAL NUMBERS

-- Countries with highest infection percentage per population
SELECT 
	location Location, 
    population Population,
    MAX(CAST(total_cases AS UNSIGNED)) AS InfectionCount,
	MAX(CAST(total_cases AS UNSIGNED)/CAST(population AS UNSIGNED))*100 AS InfectionPercentage
FROM coviddeaths
WHERE continent != ""
GROUP BY location, population
ORDER BY CAST(InfectionPercentage AS DOUBLE) DESC;

-- Countries with highest death count
SELECT 
	location Location, 
    MAX(CAST(total_deaths AS UNSIGNED)) AS DeathCount
FROM coviddeaths
WHERE continent != ""
GROUP BY location
ORDER BY CAST(DeathCount AS UNSIGNED) DESC;

-- Countries with highest death percentage of population from COVID-19
SELECT 
	location Location, 
    population Population,
    MAX(CAST(total_deaths AS UNSIGNED)) AS DeathCount,
	MAX(CAST(total_deaths AS UNSIGNED)/CAST(population AS UNSIGNED))*100 AS PopulationDeathPercentage
FROM coviddeaths
WHERE continent != ""
GROUP BY location, population
ORDER BY CAST(PopulationDeathPercentage AS DOUBLE) DESC;

-- Continents with highest death count
SELECT 
	location Location, 
    MAX(CAST(total_deaths AS UNSIGNED)) AS DeathCount
FROM coviddeaths
WHERE continent = "" AND location NOT LIKE '%income%'
GROUP BY location
ORDER BY CAST(DeathCount AS UNSIGNED) DESC;

-- Data Check: Checking that death count per continent by calculations is consistent with the given numbers 
-- Continents with highest death count - USING CALCULATIONS 
SELECT Continent, SUM(DeathCount) DeathCountContinent FROM
(SELECT 
	continent Continent,
	location Location, 
    MAX(CAST(total_deaths AS UNSIGNED)) AS DeathCount
FROM coviddeaths
WHERE continent != ""
GROUP BY location, continent
ORDER BY CAST(DeathCount AS UNSIGNED) DESC)
AS DeathCountsTable
GROUP BY Continent
ORDER BY DeathCountContinent DESC;

-- Continents with highest death percentage of population from COVID-19
SELECT 
	location Location, 
    population Population,
    MAX(CAST(total_deaths AS UNSIGNED)) AS DeathCount,
	MAX(CAST(total_deaths AS UNSIGNED)/CAST(population AS UNSIGNED))*100 AS PopulationDeathPercentage
FROM coviddeaths
WHERE continent = "" AND location NOT LIKE '%income%' AND location NOT LIKE '%international%' AND location NOT LIKE '%union%'
GROUP BY location, population
ORDER BY CAST(PopulationDeathPercentage AS DOUBLE) DESC;


-- Infection count, death count and death percentage by day
SELECT 
	date Date,
    SUM(CAST(new_cases AS UNSIGNED)) NewCases,
    SUM(CAST(new_deaths AS UNSIGNED)) NewDeaths,
    (SUM(CAST(new_deaths AS UNSIGNED))/SUM(CAST(new_cases AS UNSIGNED)))*100 AS DeathPercentage
FROM coviddeaths
WHERE continent != ""
GROUP BY date
ORDER BY 1;

-- Total infection count, death count and death percentage
SELECT
    SUM(CAST(new_cases AS UNSIGNED)) NewCases,
    SUM(CAST(new_deaths AS UNSIGNED)) NewDeaths,
    (SUM(CAST(new_deaths AS UNSIGNED))/SUM(CAST(new_cases AS UNSIGNED)))*100 AS DeathPercentage
FROM coviddeaths
WHERE continent != "";




-- TOTAL POPULATION VS VACCINATIONS

-- Number of Vaccine Doses Administered as a Ratio of Population 
-- Method 1: with CTE 
With PopVacTable (Continent, Location, Date, Population, NewVaccinations, RollingDosesGiven)
AS
(SELECT 
	dea.continent Continent, 
	dea.location Location, 
	dea.date Date,
    CAST(dea.population AS UNSIGNED) Population, 
    (CAST(vac.new_vaccinations AS DOUBLE)) NewVaccinations,
    SUM(CAST(vac.new_vaccinations AS DOUBLE)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) RollingDosesGiven
FROM coviddeaths dea
JOIN covidvaccines vac
	ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent != "")

SELECT *, (RollingDosesGiven/Population) AS DosesPerPopulation
FROM PopVacTable;

-- Temp Table for Population vs. Vaccinations
DROP TABLE IF EXISTS PopVsVac;

CREATE TEMPORARY TABLE PopVsVac (
	Continent VARCHAR(255), 
    Location VARCHAR(255),
    Date DATE,
    Population DOUBLE,
    NewVaccinations DOUBLE,
    RollingDosesGiven DOUBLE,
	TotalVaccinations DOUBLE,
    PeopleVaccinated DOUBLE,
    PeopleFullyVaccinated DOUBLE
    );

INSERT INTO PopVsVac
SELECT 
	dea.continent Continent, 
	dea.location Location,
    dea.date Date,
    CAST(dea.population AS DOUBLE) Population,
    CAST(vac.new_vaccinations AS DOUBLE) NewVaccinations,
    SUM(CAST(vac.new_vaccinations AS DOUBLE)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) RollingDosesGiven,
    CAST(vac.total_vaccinations AS DOUBLE) TotalVaccinations,
    CAST(vac.people_vaccinated AS DOUBLE) PeopleVaccinated,
    CAST(vac.people_fully_vaccinated AS DOUBLE) PeopleFullyVaccinated
FROM coviddeaths dea
JOIN covidvaccines vac
	ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent != "";

-- Number of Vaccine Doses Administered as a Ratio of Population 
-- Method 2: with temp table
SELECT *, (RollingDosesGiven/Population) AS DosesPerPopulation 
FROM PopVsVac;

-- Current DosePerPopulation Ratio Per Location
SELECT Location, MAX(RollingDosesGiven/Population) AS TotalDosesPerPopulation 
FROM PopVsVac
GROUP BY Location
ORDER BY TotalDosesPerPopulation DESC;

-- Data Check: Checking that NewVaccinations and TotalVaccinations columns are consistent
-- CalcTotVac values column must equal values in TotalVaccinations column
SELECT *,
       NewVaccinations + COALESCE(LAG(TotalVaccinations) OVER (ORDER BY Date), 0) AS CalcTotVac
FROM PopVsVac;

-- Data Check: Checking that RollingDosesGiven and TotalVaccinations columns are consistent
-- Expecting: Final_cell(RollingDosesGiven) + Initial_cell(TotalVaccinations) = Final_cell(TotalVaccinations)
SELECT 
	Location, 
    MAX(RollingDosesGiven) RollingDosesGiven, -- Final_cell(RollingDosesGiven)
    MAX(TotalVaccinations) TotalVaccinations, -- Final_cell(TotalVaccinations),
    MAX(RollingDosesGiven) + 42672 AS CalulatedTotalVaccines -- Initial_cell(TotalVaccinations) = 42672
FROM PopVsVac
GROUP BY location;

-- Percentage of People Vaccinated
-- Method 1: with temp table
SELECT *, 
	(PeopleVaccinated/Population)*100 AS PercentVacc, 
    (PeopleFullyVaccinated/Population)*100 AS PercentFullVacc
FROM PopVsVac;

-- Percentage of People Vaccinated
-- Method 2: with CTE
With PercentVaccinatedTable (Continent, Location, Date, Population, PeopleVaccinated, PeopleFullyVaccinated) 
AS
(SELECT 
	dea.continent Continent, 
	dea.location Location,
    dea.date Date,
    CAST(dea.population AS DOUBLE) Population,
    CAST(vac.people_vaccinated AS DOUBLE) PeopleVaccinated,
    CAST(vac.people_fully_vaccinated AS DOUBLE) PeopleFullyVaccinated
FROM coviddeaths dea
JOIN covidvaccines vac
	ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent != "")

SELECT *, 
	(PeopleVaccinated/Population)*100 AS PercentVacc, 
    (PeopleFullyVaccinated/Population)*100 AS PercentFullVacc;




-- CREATING VISUALIZATIONS

-- Total Cases vs. Total Deaths Visual
CREATE VIEW Global_Death_Percentage AS
SELECT 
	location Location, 
	date Date, 
    CAST(total_cases AS UNSIGNED) TotalCases, 
    CAST(total_deaths AS UNSIGNED) TotalDeaths, 
    (CAST(total_deaths AS UNSIGNED)/CAST(total_cases AS UNSIGNED))*100 AS DeathPercentage
FROM coviddeaths
WHERE continent != ""
ORDER BY 1, 2;

-- Total Cases vs. Total Deaths in United States Visual
CREATE VIEW US_Death_Percentage AS
SELECT 
	location Location, 
	date Date, 
    CAST(total_cases AS UNSIGNED) TotalCases, 
    CAST(total_deaths AS UNSIGNED) TotalDeaths, 
    (CAST(total_deaths AS UNSIGNED)/CAST(total_cases AS UNSIGNED))*100 DeathPercentage
FROM coviddeaths
WHERE location LIKE '%states'
ORDER BY 1,2;

-- Total Cases vs. Population in United States Visual
CREATE VIEW US_Infection_Percentage AS
SELECT 
	location Location, 
	date Date, 
    population Population, 
    (CAST(total_cases AS UNSIGNED)/CAST(population AS UNSIGNED))*100 InfectionPercentage
FROM coviddeaths
WHERE location LIKE '%states'
ORDER BY 1,2;

-- Countries with highest infection percentage per population Visual
CREATE VIEW Global_Infection_Percentage AS
SELECT 
	location Location, 
    population Population,
    MAX(CAST(total_cases AS UNSIGNED)) AS InfectionCount,
	MAX(CAST(total_cases AS UNSIGNED)/CAST(population AS UNSIGNED))*100 AS InfectionPercentage
FROM coviddeaths
WHERE continent != ""
GROUP BY location, population
ORDER BY CAST(InfectionPercentage AS DOUBLE) DESC;

-- Countries with highest death count Visual
CREATE VIEW Global_Death_Count AS
SELECT 
	location Location, 
    MAX(CAST(total_deaths AS UNSIGNED)) AS DeathCount
FROM coviddeaths
WHERE continent != ""
GROUP BY location
ORDER BY CAST(DeathCount AS UNSIGNED) DESC;

-- Countries with highest death percentage of population from COVID-19 Visual
CREATE VIEW Global_DeathPercent_ofPopulation AS
SELECT 
	location Location, 
    population Population,
    MAX(CAST(total_deaths AS UNSIGNED)) AS DeathCount,
	MAX(CAST(total_deaths AS UNSIGNED)/CAST(population AS UNSIGNED))*100 AS PopulationDeathPercentage
FROM coviddeaths
WHERE continent != ""
GROUP BY location, population
ORDER BY CAST(PopulationDeathPercentage AS DOUBLE) DESC;

-- Continents with highest death count Visual - FROM GIVEN NUMBERS
CREATE VIEW Death_Count_Continents AS
SELECT 
	location Location, 
    MAX(CAST(total_deaths AS UNSIGNED)) AS DeathCount
FROM coviddeaths
WHERE continent = "" AND location NOT LIKE '%income%'
GROUP BY location
ORDER BY CAST(DeathCount AS UNSIGNED) DESC;

-- Continents with highest death count Visual - FROM CALCULATIONS 
-- Note: A visual will better demonstrate consistensies with given numbers 
CREATE VIEW Death_Count_Continents_byCalc AS
SELECT Continent, SUM(DeathCount) DeathCountContinent FROM
(SELECT 
	continent Continent,
	location Location, 
    MAX(CAST(total_deaths AS UNSIGNED)) AS DeathCount
FROM coviddeaths
WHERE continent != ""
GROUP BY location, continent
ORDER BY CAST(DeathCount AS UNSIGNED) DESC)
AS DeathCountsTable
GROUP BY Continent
ORDER BY DeathCountContinent DESC;

-- Population vs Vaccination Visual
CREATE VIEW Population_vs_Vaccination AS
SELECT 
	dea.continent Continent, 
	dea.location Location,
    dea.date Date,
    CAST(dea.population AS DOUBLE) Population,
    CAST(vac.new_vaccinations AS DOUBLE) NewVaccinations,
    SUM(CAST(vac.new_vaccinations AS DOUBLE)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) RollingDosesGiven,
    CAST(vac.total_vaccinations AS DOUBLE) TotalVaccinations,
    CAST(vac.people_vaccinated AS DOUBLE) PeopleVaccinated,
    CAST(vac.people_fully_vaccinated AS DOUBLE) PeopleFullyVaccinated
FROM coviddeaths dea
JOIN covidvaccines vac
	ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent != ""; 










