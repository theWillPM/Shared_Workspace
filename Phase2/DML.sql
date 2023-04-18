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
-- Since we are using foreign key constraints in chain, we can only delete if we use ON DELETE CASCADE.
-- This means that if we delete a property with the DELETE query, we will delete: All Workspaces from that property,
-- all listings from all of those workspaces, all bookings from all of those listings, all payments from all of those bookings,
-- all transactions from all of those payments and all shared workspaces from all of those payments.

--INSTEAD OF:
/*
DELETE FROM Property
WHERE Property_ID = 12
GO
*/

--Do this:
DECLARE @Account_that_is_performing_the_action int = 7
DECLARE @PROPERTY_TO_DELETE int = 12 -- Set the property_id to delete here
DECLARE @NEW_PROPERTY_ID int = 9000000+@PROPERTY_TO_DELETE
DECLARE @woskpace_count INT = (SELECT COUNT(WORKSPACE_ID) FROM Workspace WHERE Property_ID = @PROPERTY_TO_DELETE)

if dbo.CheckIfOwnsProperty(@Account_that_is_performing_the_action, @PROPERTY_TO_DELETE) = 1
BEGIN
	IF EXISTS (SELECT * from Property where Property_ID = @PROPERTY_TO_DELETE)
	BEGIN
		--Check the active bookings view to see if there's an active booking in that property 
		IF NOT EXISTS (
			SELECT * from Bookings_ACTIVE
			WHERE [Bookings_ACTIVE].Property_ID = @PROPERTY_TO_DELETE)
		BEGIN
			SET IDENTITY_INSERT [Property] ON

			INSERT Property(Property_ID, Address, Neighborhood, Square_Feet, Is_Reachable_By_Public_Transp, Has_Parking_Garage)
			VALUES (@NEW_PROPERTY_ID, 'Deleted', 'Deleted',  null, 0, 0)

			SET IDENTITY_INSERT [Property] OFF

			UPDATE Property_Owner
			SET Property_ID = @NEW_PROPERTY_ID
			WHERE Property_ID = @PROPERTY_TO_DELETE

			UPDATE Workspace
			SET Property_ID = @NEW_PROPERTY_ID
			WHERE Property_ID = @PROPERTY_TO_DELETE

			SET IDENTITY_INSERT [Workspace] ON

			-- A While loop to iterate through all workspaces that belonged to our soon-to-be-deleted property
			DECLARE @count int = 1
			WHILE (@count <= @woskpace_count)
			BEGIN	
				INSERT Workspace(Workspace_ID, Property_ID, Seats, Is_Smoking_Allowed, Type)
				VALUES (CAST(CAST(@NEW_PROPERTY_ID as varchar(10)) + CAST(@count as varchar(10)) as int), @NEW_PROPERTY_ID, 0, 0, 'Desk');

				-- Supporting table that allows us to iterate through the results of the query based on row number and our variable @count
				WITH OrderedWoskpaceID AS
				(
				SELECT Workspace_ID, ROW_NUMBER() OVER(order by Workspace_ID) AS RowNumber
				FROM Workspace
				WHERE Property_ID = @NEW_PROPERTY_ID AND Workspace_ID < 9000000
				)

				-- Update Listing to replace the Workspace_ID of the to-be-deleted workspace with our internal code for deleted
				UPDATE Listing
				SET Workspace_ID = CAST(CAST(@NEW_PROPERTY_ID as varchar(10)) + CAST(@count as varchar(10)) as int)
				WHERE Workspace_ID = (	
					SELECT Workspace_ID
					FROM OrderedWoskpaceID
					WHERE RowNumber = @count);
	
				-- One more time calling our supporting table OrderedWoskpaceID:
				WITH OrderedWoskpaceID AS
				(
				SELECT Workspace_ID, ROW_NUMBER() OVER(order by Workspace_ID) AS RowNumber
				FROM Workspace
				WHERE Property_ID = @NEW_PROPERTY_ID AND Workspace_ID < 9000000
				)
			
				-- Delete the original Workspace (Always row number = 1 because our table loses one entry every iteraction)
				DELETE FROM Workspace
				WHERE Workspace_ID = (	SELECT Workspace_ID
				FROM OrderedWoskpaceID
				WHERE RowNumber = 1)

				SET @count = @count + 1
			END

			SET IDENTITY_INSERT [Workspace] OFF

				-- Delete all Listings that belong to a Deleted Workspace and have no existing Booking
			DELETE FROM Listing
			WHERE Workspace_ID > 9000000 and Listing_ID NOT IN (Select Listing_ID from Booking)

			-- Finally, delete our original property from the database
			DELETE FROM Property
			Where Property_ID = @PROPERTY_TO_DELETE
		END
	END
END
else Select [ERROR] = ('Account ' + CAST(@Account_that_is_performing_the_action as varchar(2)) + ' does not own property ' + CAST(@PROPERTY_TO_DELETE as varchar(9)) + '!')
GO

-- DELETE A WORKSPACE, PRESERVING DATA

--INSTEAD OF:
/*
DELETE FROM Workspace
WHERE Workspace_ID = 2
GO
*/

--Do this:
DECLARE @Account_that_is_performing_the_action int = 2 -- REPLACE WITH '1' TO MAKE THIS WORK!
DECLARE @Workspace_TO_DELETE int = 2 -- Set the workspace id to delete here
DECLARE @NEW_WORKSPACE_ID int = 800000+@Workspace_TO_DELETE

if dbo.CheckIfOwnsWorkspaceProperty(@Account_that_is_performing_the_action, @Workspace_TO_DELETE) = 1
BEGIN
	IF EXISTS (SELECT * from Workspace where Workspace_ID = @Workspace_TO_DELETE)
	BEGIN
	--Check the active bookings view to see if there's an active booking in that workspace 
		IF NOT EXISTS (
			SELECT * from Bookings_ACTIVE
			WHERE [Bookings_ACTIVE].Workspace_ID = @Workspace_TO_DELETE)
		BEGIN
			SET IDENTITY_INSERT [Workspace] ON

			INSERT Workspace(Workspace_ID, Property_ID, Seats, Is_Smoking_Allowed, Type)
			VALUES (@NEW_WORKSPACE_ID, (select Property_id from Workspace Where Workspace_ID = @Workspace_TO_DELETE), 0, 0, 'Desk');

			-- Update Listing to replace the Workspace_ID of the to-be-deleted workspace with our internal code for deleted
			UPDATE Listing
			SET Workspace_ID = @NEW_WORKSPACE_ID
			WHERE Workspace_ID = @Workspace_TO_DELETE;
			
			-- Delete the original Workspace
			DELETE FROM Workspace
			WHERE Workspace_ID = @Workspace_TO_DELETE

			SET IDENTITY_INSERT [Workspace] OFF

			-- Delete all Listings that belong to a Deleted Workspace and have no existing Booking
			DELETE FROM Listing
			WHERE Workspace_ID BETWEEN 800000 and 9000000 and Listing_ID NOT IN (Select Listing_ID from Booking)
		END
	END
END
else Select [ERROR] = ('Account ' + CAST(@Account_that_is_performing_the_action as varchar(2)) + ' does not own Workspace ' + CAST(@Workspace_TO_DELETE as varchar(10)) + '!')
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