/**********************************************
	Script Name: B320_Team_08_Queries.sql
	Course: ISAT/CSCI B320
	Developers: Jonathan Garcia & Jason Garcia
	Last Updated: 2024.10.12

	Purpose: Create queries from the Populate table 
	using inserts in order to execute queries.
*******************************************************/

-- Query A --
-- The Registrar's office has to generate student transcripts
SELECT DISTINCT Students.StudentID, StudentFName, StudentMName, StudentLName, Semester, Year, Program, Subject, CourseNumber, 
StudentLevel, CourseTitle, Grade, QualityPoint, StartDate, EndDate, EmployeeFName, EmployeeLName, ActualCredits
FROM StudentEnrollments
INNER JOIN Grades
	ON StudentEnrollments.GradeID = Grades.GradeID
INNER JOIN Students
	ON StudentEnrollments.StudentID = Students.StudentID 
INNER JOIN StudentLevels
	ON Students.StudentLevelID = StudentLevels.StudentLevelID
INNER JOIN Programs
	ON Students.ProgramID = Programs.ProgramID
INNER JOIN CourseOfferings
	ON StudentEnrollments.CourseOfferingID = CourseOfferings.CourseOfferingID 
INNER JOIN Terms
	ON CourseOfferings.TermID = Terms.TermID
INNER JOIN Courses
	ON CourseOfferings.CourseID = Courses.CourseID
INNER JOIN Subjects
	ON Courses.SubjectID = Subjects.SubjectID 
INNER JOIN Employees
	ON CourseOfferings.EmployeeID = Employees.EmployeeID
	WHERE Students.StudentID IN ('111')
--StudentFName IN ('Owen') AND StudentLName IN ('Scott')
--AND CourseTitle IN ('Intro to Probability and Stats')
GROUP BY StudentFName, StudentMName, StudentLName, Semester, Year, Program, Subject, CourseNumber, 
StudentLevel, CourseTitle, Grade, QualityPoint, StartDate, EndDate, EmployeeLName, EmployeeFName, ActualCredits, Terms.TermID, Students.StudentID
ORDER BY StartDate, EndDate




-- Query B --  
-- At the beginning of each year, Dr. Canada has to report the number of Computer Science students by student classification 
-- (i.e., 1st year CSCI, 2nd year CSCI, 3rd year CSCI, 4th year CSCI, 1st year ISAT, etc).

DROP FUNCTION GET_Classification 
GO
CREATE FUNCTION GET_Classification(@Credits FLOAT)
RETURNS VARCHAR(50) 
AS 
BEGIN
	DECLARE @MyClassDescription VARCHAR(50)

	SET @MyClassDescription = (
	SELECT ClassDescription
	FROM StudentClassifications
	WHERE @Credits >= MinCreditHours AND @Credits <= MaxCreditHours
	)

	RETURN @MyClassDescription
END 
GO

SELECT DISTINCT 
COUNT(dbo.GET_Classification(SUM(QualityPoint))) OVER() AS Classification
From Students
INNER JOIN StudentEnrollments
	ON Students.StudentID = StudentEnrollments.StudentID 
INNER JOIN Grades
	ON StudentEnrollments.GradeID = Grades.GradeID
INNER JOIN Programs
	ON Students.ProgramID = Programs.ProgramID
WHERE 
Program IN ('Information Science & Technology') -- (*) 
GROUP BY StudentEnrollments.StudentID, Programs.ProgramID
HAVING dbo.GET_Classification(SUM(QualityPoint)) IN ('Alumni') -- (*) 

/* (*): You MUST adjust the Program from the WHERE Clause and the dbo.GET_Classification(SUM(QualityPoint)) in
the HAVING clause to not only find out how many students are from the specified Program (Major), but also how many students
are from a specific grade year (i.e. 1st Year, 2nd Year, 3rd Year, etc.) within that Major. For example,
setting Program in Psychology and setting dbo.GET_Classification(SUM(QualityPoint)) IN 'Alumni' should result in 5 students. */

-- Query C --
-- Each semester, Dr. Canada has to report the number of Computer Science students who successfully completed all courses with a grade of C or better. 
-- This information typically has to be broken out by student classification 
-- (i.e., 1st year CSCI, 2nd year CSCI, 3rd year CSCI, 4th year CSCI, 1st year ISAT, etc) and semester (Spring 2021, Fall 2021, etc.)
SELECT DISTINCT 
	Semester, 
	Year, 
	StartDate,
	EndDate,
	dbo.GET_Classification(SUM(QualityPoint)) AS Classification,
	COUNT(DISTINCT Students.StudentID) AS NumberOfStudents
From Students
INNER JOIN StudentEnrollments
	ON Students.StudentID = StudentEnrollments.StudentID 
INNER JOIN Grades
	ON StudentEnrollments.GradeID = Grades.GradeID
INNER JOIN Programs
	ON Students.ProgramID = Programs.ProgramID
INNER JOIN CourseOfferings
	ON StudentEnrollments.CourseOfferingID = CourseOfferings.CourseOfferingID
INNER JOIN Terms
	ON CourseOfferings.TermID = Terms.TermID
WHERE Program IN ('Computational Science')
	AND Grades.GradeID IN (
		SELECT GradeID 
		FROM Grades
		WHERE Grade IN ('A', 'B+', 'B', 'C+', 'C') 
		AND Grades.GradeID != 9
		AND QualityPoint >= 2.0
	)
GROUP BY Year, Semester, StartDate, EndDate
ORDER BY StartDate, EndDate

-- Query D --
-- Each semester, Dr. Canada has to report all classes offered by the Department of Computer Science and Mathematics. 
-- For each of these courses, the number and percentage of computer science students who successfully 
-- complete the course with a grade of C or better must be listed. 
-- Also required is the number and percentage of computer science students who do NOT successfully complete the course with a grade of C or better. 
SELECT DISTINCT 
	Courses.CourseTitle,
	SubjectName,
	Year, 
	Semester,
	StartDate,
	EndDate,
	COUNT(CASE WHEN QualityPoint >= 2.0 THEN 1 END) AS [Pass],
	COUNT(CASE WHEN QualityPoint < 2.0 THEN 1 END) AS [Fail],
	COUNT(CASE WHEN QualityPoint >= 2.0 THEN 1 END) * 100.0 / COUNT(StudentEnrollments.StudentID) AS [Pass Percent],
	COUNT(CASE WHEN QualityPoint < 2.0 THEN 1 END) * 100.0 / COUNT (StudentEnrollments.StudentID) AS [Fail Percent]
FROM 
	Courses
INNER JOIN CourseOfferings 
	ON Courses.CourseID = CourseOfferings.CourseID
INNER JOIN StudentEnrollments
	ON StudentEnrollments.CourseOfferingID = CourseOfferings.CourseOfferingID
INNER JOIN Students
	ON StudentEnrollments.StudentID = Students.StudentID 
INNER JOIN Grades
	ON StudentEnrollments.GradeID = Grades.GradeID 
INNER JOIN Subjects
	ON Courses.SubjectID = Subjects.SubjectID
INNER JOIN Departments 
	ON Subjects.DepartmentID = Departments.DepartmentID
INNER JOIN Programs
	ON Students.ProgramID = Programs.ProgramID
INNER JOIN Terms
	ON CourseOfferings.TermID = Terms.TermID
WHERE DepartmentDescription IN ('USC-B Math & Comp Sci') AND 
Program IN ('Computational Science', 'Information Science & Technology') 
AND Grades.GradeID != 9
GROUP BY Courses.CourseID, Courses.CourseTitle, SubjectName, Semester, Year, StartDate, EndDate
ORDER BY StartDate, EndDate

-- Query E -- 
-- In order for a course offering to financially "break even", it requires a minimum of 10 students to enroll in it. 
-- So far, the Department of Computer Science has been able to offer courses that have less than 10 students enrolled as CS is a "new program" here at USCB. 
-- However, this situation won't last long. Moving forward, 
-- Dr. Canada will have to be able to identify and then justify having NOT cancelled any and all course offerings that have less than 10 students. 

SELECT DISTINCT
	Courses.CourseTitle,
	COUNT(Students.StudentID) AS [StudentCount],
	Year,
	Semester,
	StartDate,
	EndDate
FROM 
	Courses
INNER JOIN CourseOfferings	
	ON Courses.CourseID = CourseOfferings.CourseID 
INNER JOIN Subjects
	ON Courses.SubjectID = Subjects.SubjectID
INNER JOIN StudentEnrollments
	ON CourseOfferings.CourseOfferingID = StudentEnrollments.CourseOfferingID 
INNER JOIN Grades
	ON StudentEnrollments.GradeID = Grades.GradeID
INNER JOIN Departments 
	ON Subjects.DepartmentID = Departments.DepartmentID 
INNER JOIN Students
	ON StudentEnrollments.StudentID = Students.StudentID
INNER JOIN Programs	
	ON Students.ProgramID = Programs.ProgramID
INNER JOIN Terms
	ON CourseOfferings.TermID = Terms.TermID
WHERE DepartmentDescription IN ('USC-B Math & Comp Sci') AND
Program IN ('Computational Science', 'Information Science & Technology') 
GROUP BY
	Courses.CourseID, CourseTitle, Year, Semester, StartDate, EndDate
HAVING 
	COUNT(Students.StudentID) < 10
ORDER BY 
	StartDate, EndDate

-- Query F --
-- Each semester, Dr. Canada has to be able to report the number of Computer Science students by "GPA range". 
-- That is, the number with a GPA in the A range, the number with a GPA in the B+ range, the number with a GPA in the B range, etc.
SELECT DISTINCT
	Year, Semester,
	COUNT(CASE WHEN AVG(QualityPoint) >= 4.0 THEN 1 END) OVER() AS 'A',
	COUNT(CASE WHEN AVG(QualityPoint) BETWEEN 3.5 AND 3.99 THEN 1 END) OVER() AS 'B+',
	COUNT(CASE WHEN AVG(QualityPoint) BETWEEN 3.0 AND 3.49 THEN 1 END) OVER() AS 'B',
	COUNT(CASE WHEN AVG(QualityPoint) BETWEEN 2.5 AND 2.99 THEN 1 END) OVER() AS 'C+',
	COUNT(CASE WHEN AVG(QualityPoint) BETWEEN 2.0 AND 2.49 THEN 1 END) OVER() AS 'C',
	COUNT(CASE WHEN AVG(QualityPoint) BETWEEN 1.5 AND 1.99 THEN 1 END) OVER() AS 'D+',
	COUNT(CASE WHEN AVG(QualityPoint) BETWEEN 1.0 AND 1.49 THEN 1 END) OVER() AS 'D',
	COUNT(CASE WHEN AVG(QualityPoint) BETWEEN 0 AND 0.99 THEN 1 END) OVER() AS 'F'
FROM Courses
INNER JOIN CourseOfferings	
	ON Courses.CourseID = CourseOfferings.CourseID 
INNER JOIN Subjects
	ON Courses.SubjectID = Subjects.SubjectID
INNER JOIN StudentEnrollments
	ON CourseOfferings.CourseOfferingID = StudentEnrollments.CourseOfferingID 
INNER JOIN Grades
	ON StudentEnrollments.GradeID = Grades.GradeID
INNER JOIN Departments 
	ON Subjects.DepartmentID = Departments.DepartmentID 
INNER JOIN Students
	ON StudentEnrollments.StudentID = Students.StudentID
INNER JOIN Programs	
	ON Students.ProgramID = Programs.ProgramID
INNER JOIN Terms
	ON CourseOfferings.TermID = Terms.TermID
WHERE Semester IN ('Spring')  -- (*) 
AND Year IN ('2021')	-- (*) 
AND Program IN ('Information Science & Technology', 'Computational Science')
GROUP BY Terms.TermID, Year, StudentEnrollments.StudentID, Semester

/* (*): In this query, it is REQUIRED that in order to report the number of Computer Science by "GPA range" in a specific year and semester that
you wanted, you MUST filter the Semester and Year that you wanted in the WHERE clause. For example: you can find the number of Computer Science by 
"GPA Range" from Fall 2023 by inputting 'Fall' in Semester and '2023' in Year. */


-- Query G --
-- To better assist their students, academic departments (such as Computer Science and Mathematics) need to know which of their students are struggling. 
-- Each semester, Dr. Canada has to identify the students who went on academic probabation that semester 
-- (i.e., their GPA fell below 2.0 at the end of the prior semester).  

SELECT 
	Terms.TermID,
	StudentEnrollments.StudentID, 
	AVG(QualityPoint) AS [GPA], 
	Year, 
	Semester, 
	StudentFName, 
	StudentLName
FROM Courses
INNER JOIN CourseOfferings	
	ON Courses.CourseID = CourseOfferings.CourseID 
INNER JOIN StudentEnrollments
	ON CourseOfferings.CourseOfferingID = StudentEnrollments.CourseOfferingID 
INNER JOIN Grades
	ON StudentEnrollments.GradeID = Grades.GradeID
INNER JOIN Students
	ON StudentEnrollments.StudentID = Students.StudentID
INNER JOIN Terms
	ON CourseOfferings.TermID = Terms.TermID
INNER JOIN Programs	
	ON Students.ProgramID = Programs.ProgramID 
INNER JOIN Departments
	ON Programs.DepartmentID = Departments.DepartmentID
WHERE StudentEnrollments.GradeID != 9
AND DepartmentDescription IN ('USC-B Humanities & Social Sci', 'USC-B Math & Comp Sci') 
GROUP BY StudentEnrollments.StudentID, Semester, Year, Semester, StudentFName, StudentLName, Terms.TermID 
HAVING AVG(QualityPoint) >= 0.0 
	   AND AVG(QualityPoint) < 2.0
	   
-- Query H --
-- To better assist their students, academic departments (such as Computer Science and Mathematics) need to know which of their students are struggling. 
-- Each semester, Dr. Canada has to identify the students who successfully exited academic probabation that semester 
-- (i.e., their GPA increased to at least 2.0 at the end of the prior semester).

GO
WITH CalculateGPA AS (
    SELECT DISTINCT
        StudentEnrollments.StudentID AS [StudentID],
        CourseOfferings.TermID AS [TermID],
        Year AS [Probation Year],
        Semester AS [Probation Semester],
        AVG(QualityPoint) AS [GPA],
        LEAD(AVG(QualityPoint)) OVER (PARTITION BY StudentEnrollments.StudentID ORDER BY CourseOfferings.TermID) AS [Exited Probation GPA],
        LEAD(CourseOfferings.TermID) OVER (PARTITION BY StudentEnrollments.StudentID ORDER BY CourseOfferings.TermID) AS [UpdTermID]
    FROM StudentEnrollments
    INNER JOIN Students
        ON StudentEnrollments.StudentID = Students.StudentID
    INNER JOIN CourseOfferings
        ON StudentEnrollments.CourseOfferingID = CourseOfferings.CourseOfferingID
    INNER JOIN Terms
        ON CourseOfferings.TermID = Terms.TermID 
    INNER JOIN Grades
        ON StudentEnrollments.GradeID = Grades.GradeID 
	INNER JOIN Programs
		ON Students.ProgramID = Programs.ProgramID
	INNER JOIN Departments
		ON Programs.DepartmentID = Departments.DepartmentID
	WHERE StudentEnrollments.GradeID != 9
	AND DepartmentDescription IN ('USC-B Humanities & Social Sci', 'USC-B Math & Comp Sci') -- (*)
    GROUP BY 
        StudentEnrollments.StudentID, 
        Year, 
        Semester,
		CourseOfferings.TermID
)
SELECT 
    Students.StudentFName,
    Students.StudentMName,
    Students.StudentLName,
    [Probation Year],
    [Probation Semester],
    Terms.Year AS [Exited Probation Year],
    Terms.Semester AS [Exited Probation Semester],
    [Exited Probation GPA]
FROM CalculateGPA
INNER JOIN Terms
    ON CalculateGPA.[UpdTermID] = Terms.TermID
INNER JOIN Students 
    ON CalculateGPA.StudentID = Students.StudentID
WHERE 
    [GPA] < 2.0
    AND [Exited Probation GPA] >= 2.0
ORDER BY 
    Students.StudentLName, 
    Students.StudentFName,
	Terms.StartDate,
	Terms.EndDate
GO
/* (*): You can adjust the DepartmentDescription to filter students out that are from or not from a specified department */ 

-- Query I -- 
-- Each semester, Dr. Canada has to demonstrate continual improvement of the programs offered by his department. 
-- In doing so, he regularly generates a spreadsheet showing - by semester - the number of students in each program at that time, 
-- the overall GPA of the students enrolled in the program at that time, the number of students on academic probation at that time, 
-- and the number of students graduating at that time.

GO
WITH LatestDate AS ( 
	SELECT
	StudentEnrollments.StudentID as Student,
	MAX(Semester) LatestDate
	FROM StudentEnrollments
	INNER JOIN Students 
		ON StudentEnrollments.StudentID = Students.StudentID
    INNER JOIN CourseOfferings 
		ON StudentEnrollments.CourseOfferingID = CourseOfferings.CourseOfferingID
    INNER JOIN Terms 
		ON CourseOfferings.TermID = Terms.TermID
	GROUP BY StudentEnrollments.StudentID
),
CountGPAandGrads AS (
SELECT DISTINCT Program,
           StudentEnrollments.StudentID as Student,
           AVG(QualityPoint) OVER (PARTITION BY StudentEnrollments.StudentID ORDER BY StartDate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as GPA,
           Year,
		   Semester,
           SUM(ActualCredits) OVER (PARTITION BY StudentEnrollments.StudentID ORDER BY StartDate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as RunningCredits,
		   StartDate as StartDate
    FROM StudentEnrollments
	INNER JOIN Students 
		ON StudentEnrollments.StudentID = Students.StudentID
    INNER JOIN Grades 
		ON StudentEnrollments.GradeID = Grades.GradeID
    INNER JOIN Programs 
		ON Programs.ProgramID = Students.ProgramID
    INNER JOIN CourseOfferings 
		ON StudentEnrollments.CourseOfferingID = CourseOfferings.CourseOfferingID
    INNER JOIN Terms 
		ON CourseOfferings.TermID = Terms.TermID
	WHERE Grades.GradeID != 9
),
CalculateSemester AS (
SELECT DISTINCT 
       Program,
       Student,
       MAX(RunningCredits) OVER (PARTITION BY Student, Year, Semester) as TotalCredits,
	   MAX(GPA) OVER (PARTITION BY Student, Year, Semester) as TotalAvgGPA,
       Year,
       Semester
FROM CountGPAandGrads
GROUP BY Program, Student, GPA, Year, Semester, RunningCredits
)
SELECT Program, 
       COUNT(DISTINCT CalculateSemester.Student) as StudentCount, 
	   AVG(TotalAvgGPA) AS ProgramGPA, 
	   COUNT(CASE WHEN TotalAvgGPA < 2.0 THEN 1 END) AS Probation, 
	   COUNT(CASE WHEN TotalCredits >= 120 and LatestDate.Student IS NOT NULL THEN LatestDate.Student END) AS Graduates,
	   Semester, Year
	FROM CalculateSemester INNER JOIN LatestDate
		ON CalculateSemester.Student = LatestDate.Student
WHERE Program != ('Psychology')
GROUP BY Program, Semester, Year
ORDER BY Semester, Year
GO

-- Query J --
-- To better assist their students, academic departments (such as Computer Science and Mathematics) need to know which of their 
-- students have and/or are repeating courses. At the beginning of each semester, 
-- Dr. Canada needs a list of students that have and/or are currently repeating courses. 
-- The course, the semesters in which it was taken, as well as the two respective grades are important, and need to be included. 
-- You should think of these as the initial attempt and the final attempt at the course. 
-- If the student is currently re-taking the course, instead of a grade for the final attempt display 'in progress'.

GO
WITH RepeatedCourses AS (
    SELECT
        Students.StudentID AS [StudentID],
        Students.StudentFName,
        Students.StudentLName,
        Courses.CourseTitle,
        MIN(Semester) AS [Initial Semester],
        MAX(Semester) AS [Final Semester],
        MIN(EndDate) AS [Initial Year],
        MAX(EndDate) AS [Final Year],
        MIN(CASE WHEN StudentEnrollments.GradeID != 9 THEN Grades.Grade END) AS [Final Grade],
        MAX(CASE WHEN StudentEnrollments.GradeID != 9 THEN Grades.Grade END) AS [Initial Grade]
    FROM StudentEnrollments
    INNER JOIN Students
        ON StudentEnrollments.StudentID = Students.StudentID
    INNER JOIN Grades
        ON StudentEnrollments.GradeID = Grades.GradeID
    INNER JOIN CourseOfferings
        ON StudentEnrollments.CourseOfferingID = CourseOfferings.CourseOfferingID
    INNER JOIN Terms
        ON CourseOfferings.TermID = Terms.TermID
    INNER JOIN Courses
        ON CourseOfferings.CourseID = Courses.CourseID
    GROUP BY
        Students.StudentID,
        Students.StudentFName,
        Students.StudentLName,
        Courses.CourseTitle
    HAVING
        COUNT(*) > 1
)
SELECT
    RepeatedCourses.StudentID,
    RepeatedCourses.StudentFName,
    RepeatedCourses.StudentLName,
    RepeatedCourses.[Initial Semester],
    RepeatedCourses.[Initial Year],
	RepeatedCourses.[Initial Grade],
    RepeatedCourses.[Final Semester],
    RepeatedCourses.[Final Year],
    CASE 
		WHEN RepeatedCourses.[Final Year] IN ('2024-12-16') THEN 'In Progress'
        ELSE RepeatedCourses.[Final Grade]
    END AS [Final Grade],
    RepeatedCourses.CourseTitle
FROM
    RepeatedCourses 
ORDER BY
    RepeatedCourses.StudentFName,
    RepeatedCourses.CourseTitle;
GO
