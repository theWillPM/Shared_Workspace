/*
@Author: Willian P. Munhoz, Rafael M. Conceição. 
@Course: DATA1201 - Introduction to relational databases
@Instructor: Mohamed Elmenshawy
@Date: April 18th, 2023
*/

--1.
/* As a user, I can sign up for an account and provide my information
(name, phone, and email). I can give my role as an owner or a
coworker as option. */
DECLARE @first_name varchar(50) = 'New'
DECLARE @last_name varchar(50) = 'User'
DECLARE @phone varchar(50) = '+1(587)0123-4567'
DECLARE @email varchar(255) = 'NewUser123@bvc.ca'
DECLARE @role varchar(10) = 'Coworker'
DECLARE @pass varchar(10) = 'Password'

Insert Into
[User]
VALUES
(@email, @first_name, @last_name, @phone, GETDATE())
Insert Into
[Account]
VALUES
(@role, @email, '1', @pass)
GO

--2.
/*As an owner, I can list a property with its address, neighborhood,
square feet, whether it has a parking garage, and whether it is
reachable by public transportation.*/
DECLARE @my_account_id int = 7
DECLARE @address varchar(50) = '345 6 Ave SE, Calgary, AB T2G 4V1'
DECLARE @neighborhood varchar(50) = 'Downtown'
DECLARE @sqft int = 10000
DECLARE @has_garage bit = 1
DECLARE @is_reachable_by_p_transport bit = 1

Insert Into
[Property]
VALUES
(@address, @neighborhood, @sqft, @has_garage, @is_reachable_by_p_transport)
GO

--3.
/*As an owner, I can select one of my properties and list workspaces for
rent. Workspaces could be meeting rooms, private office rooms, or
desks in an open work area. For each workspace, I can specify how
many individuals it can seat, whether smoking is allowed or not,
availability date, lease term (day, week, or month), and price.*/
DECLARE @my_account_id int = 7
DECLARE @property_id int = 12
DECLARE @seats int = 10
DECLARE @smoking bit = 1 
DECLARE @type varchar(15) = 'Desk' 

IF dbo.CheckIfOwnsProperty(@my_account_id, @property_id) = 1
BEGIN
	INSERT INTO
	[Workspace]
	VALUES (
	@property_id, @seats, @smoking, @type
	)
END
else Select [ERROR] = ('Account ' + CAST(@my_account_id as varchar(2)) + ' does not own property ' + CAST(@property_id as varchar(9)) + '!')
GO

--4.
/*As an owner, I can modify the data for any of my properties or any of
my workspaces.*/

--As an owner, I can edit Details of my Workspaces
DECLARE @Account_that_is_performing_the_action int = 2
DECLARE @Workspace_ID int = 55

if dbo.CheckIfOwnsWorkspaceProperty(@Account_that_is_performing_the_action, @Workspace_ID) = 1
BEGIN
	UPDATE Workspace
	SET  Is_Smoking_Allowed = 'TRUE'
	WHERE Workspace_ID = @Workspace_ID
END
else Select [ERROR] = ('Account ' + CAST(@Account_that_is_performing_the_action as varchar(2)) + ' does not own Workspace ' + CAST(@Workspace_ID as varchar(10)) + '!')
GO

--As an owner, I can edit Details of my Property
DECLARE @Account_that_is_performing_the_action int = 7
DECLARE @Property_ID int = 9

if dbo.CheckIfOwnsWorkspaceProperty(@Account_that_is_performing_the_action, @Property_ID) = 1
BEGIN
	UPDATE Property
	SET Address = '345 6 Ave SE'
	WHERE Property_ID = @Property_ID
END
else Select [ERROR] = ('Account ' + CAST(@Account_that_is_performing_the_action as varchar(2)) + ' does not own Workspace ' + CAST(@Property_ID as varchar(10)) + '!')
GO

--5.
/*As an owner, I can delist or remove any of my properties or any of my
workspaces from the database*/

-- Delete record from Property table PRESERVING DATA FROM [Listing, Booking, Payment, Transactions and Shared Workspaces]

DECLARE @Account_Performing_Action INT = 1
DECLARE @Property_To_Delete INT = 2
if dbo.CheckIfOwnsWorkspaceProperty(@Account_Performing_Action, @Property_To_Delete) = 1
BEGIN
	IF NOT EXISTS (SELECT Property_ID
	FROM Bookings_Active
	WHERE Property_ID = @Property_To_Delete)
	BEGIN
		WITH
		TempTable as
		(SELECT l.Listing_ID, w.Property_ID, l.Workspace_ID
		from Listing l Join Workspace w On l.workspace_id = w.workspace_id
		WHERE w.Property_ID = @Property_To_Delete)

		UPDATE TempTable
		SET Workspace_ID = NULL
		WHERE Property_ID = @Property_To_Delete
	END
	DELETE FROM Property
	WHERE Property_ID = @Property_To_Delete
END
ELSE Select [ERROR] = ('Account ' + CAST(@Account_Performing_Action as varchar(2)) + ' does not own property ' + CAST(@Property_To_Delete as varchar(9)) + '!')
GO

-- DELETE A WORKSPACE, PRESERVING DATA FROM OLD [Listing, Booking] and deleting all current Listing from that workspace.

DECLARE @Account_Performing_Action INT = 2
DECLARE @Workspace_To_Delete INT = 10
if dbo.CheckIfOwnsWorkspaceProperty(@Account_Performing_Action, @Workspace_To_Delete) = 1
BEGIN
	IF NOT EXISTS (SELECT Workspace_ID
	FROM Bookings_Active
	WHERE Workspace_ID = @Workspace_To_Delete)
	BEGIN
		UPDATE Listing
		SET Workspace_ID = NULL
		WHERE Workspace_ID = @Workspace_To_Delete
	END
	DELETE FROM Workspace
	WHERE Workspace_ID = @Workspace_To_Delete;

	DELETE FROM LISTING
	WHERE Workspace_ID IS NULL AND
	listing_ID not in (SELECT l.Listing_ID from Listing l join Booking b ON l.Listing_ID = b.Booking_ID)
END
ELSE Select [ERROR] = ('Account ' + CAST(@Account_Performing_Action as varchar(2)) + ' does not own workspace ' + CAST(@Workspace_To_Delete as varchar(9)) + '!')
GO

--6.
/*As a coworker, I can search for workspaces by address, neighborhood,
square feet, with/without parking, with/without public transportation,
number of individuals it can seat, with/without smoking, availability
date, lease term, or price*/

-- Workspaces by address
SELECT * 
FROM Workspace w JOIN Property p
ON w.Property_ID = p.Property_ID
WHERE p.address like '%1__Street%'
and Neighborhood = 'downtown'
GO

-- Workspaces with public transp, no garage and price < $100 per day
SELECT 
	w.Workspace_ID,
	p.Property_ID,
	Address,
	Neighborhood,
	type,
	w.Seats,
	l.Listing_ID,
	FORMAT(l.Price / dbo.parseTextDateToInt(l.Lease_Term), 'c') as '$ per day',
	FORMAT(l.Price / dbo.parseTextDateToInt(l.Lease_Term)/Seats, 'c') as '$ per day per seat'
FROM 
	Workspace w 
	JOIN Property p ON w.Property_ID = p.Property_ID
	JOIN Listing l on l.Workspace_ID = w.Workspace_ID
WHERE 
	Is_Reachable_By_Public_Transp = 1
	and Has_Parking_Garage = 0
	and l.Price / FORMAT(dbo.parseTextDateToInt(l.Lease_Term), 'c') < 100
	order by '$ per day'
GO

-- Workspaces with more than 6 seats and smoking allowed
SELECT * 
FROM Workspace w join Property p
ON w.Property_ID = p.Property_ID
WHERE seats > 6
AND Is_Smoking_Allowed = 1
Order by seats DESC
GO

-- Workspaces that became available today
SELECT * 
FROM Workspace w JOIN Listing l
ON w.Workspace_ID = l.Workspace_ID
WHERE Availability_Date = CAST(GETDATE() as DATE);
GO

--7. As a coworker, I can select a workspace and view its details.
SELECT * 
FROM Workspace
WHERE Workspace_ID = 10
GO

--8. As a coworker, I can get the contact information of a workspace’s owner
SELECT * 
FROM Workspaces_Owners
WHERE Workspace_ID = 10
GO