USE TeamOfThree
GO
-- Query 1
--Find all active accounts of co-workers
SELECT *
FROM Account
WHERE Is_Active = 1 AND Account_Type = 'Coworker';

-- Query 2
--Find the workspace with the highest number of seats
SELECT TOP 1 *
FROM Workspace
ORDER BY Seats DESC;

-- Query 3
--Find all listings for workspaces that allow smoking and are located in a neighborhood that is reachable by public transportation
SELECT *
FROM Listing
WHERE Workspace_ID IN
(SELECT Workspace_ID
FROM Workspace
JOIN Property ON Workspace.Property_ID = Property.Property_ID
WHERE Is_Smoking_Allowed = 1 AND Is_Reachable_By_Public_Transp = 1);

-- Query 4
--Find the number of bookings made by a specific account
SELECT COUNT(*) AS 'Number of Bookings'
FROM Booking
WHERE Account_Number = (SELECT Account_Number FROM Account WHERE Email = 'aaa@gmail.com');

-- Query 5
--Find the total amount paid by an account in transactions
SELECT SUM(Transaction_Amount) AS 'Total Amount Paid'
FROM [Transaction]
WHERE Email = 'aaa@gmail.com';

-- Query 6
--Find the total amount due from payments that have a daily lease term
SELECT SUM(Amount_Due) AS 'Total Due'
FROM Payment
WHERE Booking_ID IN
(SELECT Booking_ID
FROM Booking JOIN Listing ON booking.Listing_ID = Listing.Listing_ID
WHERE Lease_Term = 'DAY');

-- Query 7
--Select all the workspaces that belong to a property located in the neighborhood 'Downtown'
SELECT *
FROM Workspace
WHERE Property_ID IN
(SELECT Property_ID
FROM Property
WHERE Neighborhood = 'Downtown');

-- Query 8
--Select all the bookings made by the user with email 'aaa@gmail.com'
SELECT *
FROM Booking
WHERE Account_Number =
(SELECT Account_Number
FROM Account
WHERE Email = 'aaa@gmail.com');

-- Query 9
--Select all the transactions made by users who own properties with public transportation accessibility
--Result should be empty 
SELECT *
FROM [Transaction]
WHERE Email IN
(SELECT Email
FROM Account
WHERE Account_Number IN
(SELECT Account_Number
FROM Property_Owner
WHERE Property_ID IN
(SELECT Property_ID
FROM Property
WHERE Is_Reachable_By_Public_Transp = 1)));
Go

-- Query 10
-- Select all the workspaces available for booking on a certain date with a price less than $50 per day.
SELECT l.Workspace_ID, l.Price / FORMAT(dbo.parseTextDateToInt(l.Lease_Term), 'c') as '$ per day'
FROM Listing l
WHERE l.Availability_Date <= '2023-04-18'
AND NOT EXISTS (
	SELECT * from Booking WHERE
	Booking.Listing_ID = l.Listing_ID)
AND l.Price / dbo.parseTextDateToInt(l.Lease_Term) <= 50
ORDER BY '$ per day' ASC
GO

-- Query 11
-- Select the total number of workspaces by Neighborhood, only for properties located in neighborhoods with an average of more than 500 square feet per property.
SELECT p.Neighborhood, COUNT(w.Workspace_ID) AS Total_Workspaces
FROM Property p
JOIN Workspace w ON p.Property_ID = w.Property_ID
WHERE p.Square_Feet > 0
GROUP BY p.Neighborhood
HAVING AVG(p.Square_Feet) > 500;

-- Query 12
-- Select the top 5 most active users based on the number of transactions they have made.
SELECT TOP 5 u.First_Name, u.Last_Name, COUNT(t.Transaction_ID) AS Total_Transactions
FROM [User] u
JOIN [Transaction] t ON u.Email = t.Email
GROUP BY u.First_Name, u.Last_Name
ORDER BY Total_Transactions DESC;

-- Query 13
-- Select the average price for each workspace type (desk, meeting room, private office) in each property neighborhood, only for properties that have at least one active booking.
SELECT p.Neighborhood, w.Type, AVG(l.price) as 'Average Price'
FROM Property p
JOIN Workspace w ON p.Property_ID = w.Property_ID
JOIN Listing l ON w.Workspace_ID = l.Workspace_ID
JOIN Booking b ON b.Listing_ID = l.Listing_ID
WHERE b.Payment_ID IS NOT NULL AND w.Type IN ('Desk', 'Meeting Room', 'Private Office Room')
GROUP BY p.Neighborhood, w.Type;

-- Query 14
-- Select the properties that have workspaces with a total number of seats greater than 10.
SELECT p.*
FROM Property p
JOIN Workspace w ON p.Property_ID = w.Property_ID
GROUP BY p.Property_ID, p.Neighborhood, p.Address, p.Has_Parking_Garage, p.Is_Reachable_By_Public_Transp, p.Square_Feet
HAVING SUM(w.Seats) > 10;

-- Query 15
-- Select the workspaces that have never been booked.
SELECT w.Workspace_ID, w.Property_ID, w.Seats, w.[Type], w.Is_Smoking_Allowed
FROM Workspace w
EXCEPT
	(SELECT w.Workspace_ID, w.Property_ID, w.Seats, w.[Type], w.Is_Smoking_Allowed
	FROM WORKSPACE w
	INNER JOIN Listing l
	ON w.Workspace_ID = l.Workspace_ID
	INNER JOIN Booking b
	ON b.Listing_ID = l.Listing_ID);

-- Query 16
-- Select all inactive accounts
SELECT u.First_Name + ' ' + u.Last_Name as 'Name', a.Account_Number as 'Acc #', a.Email, CAST(u.Registration_Date AS DATE) as 'Registration Date'
FROM Account a, [User] u 
WHERE Is_Active = 0 AND a.Email = u.Email;

-- Query 17
-- Select all all records from the Property table where the Has_Parking_Garage column is set to 1.
SELECT *
FROM Property
WHERE Has_Parking_Garage = 1;

-- Query 18
-- Update Is_Active column in Account table
UPDATE Account
SET Is_Active = 0
WHERE Email = 'yyy@gmail.com';
GO