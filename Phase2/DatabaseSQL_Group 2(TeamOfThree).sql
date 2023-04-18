-- First Query - Create DB
USE [master]
GO

-- If the database already exists, drop it.
IF DB_ID('TeamOfThree') IS NOT NULL
ALTER DATABASE [TeamOfThree]
SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE [TeamOfThree]
GO

-- Create database
Create database TeamOfThree
GO

Use TeamOfThree;
go

-- Function to check if the account is active. This is used to prohibit user access and action on banned accounts.
IF OBJECT_ID('CheckIfAccountIsActive') IS NOT NULL
DROP function CheckIfAccountIsActive
GO
CREATE FUNCTION CheckIfAccountIsActive(@AccountNumber INT)
RETURNS BIT
	AS BEGIN
		RETURN (SELECT Account.Is_Active FROM Account WHERE Account.Account_Number = @AccountNumber)
	END
GO

-- Function to check if the account is of 'Owner' type. Returns 1 if true, 0 if false.
IF OBJECT_ID('CheckIfIsOwner') IS NOT NULL
DROP function CheckIfIsOwner
GO
Create function CheckIfIsOwner(@AccountNumber INT)
RETURNS BIT
	AS BEGIN
		RETURN (SELECT CASE WHEN EXISTS 
		(SELECT * FROM Account
		WHERE Account_Type = 'Owner'
		AND Account_Number = @AccountNumber)
		THEN CAST(1 as bit)
		ELSE CAST(0 as bit)
		END)
	END
GO

-- Function to check if the account owns the workspace's property. Returns 1 if true, 0 if false.
IF OBJECT_ID('CheckIfOwnsWorkspaceProperty') IS NOT NULL
DROP function CheckIfOwnsWorkspaceProperty
GO
CREATE function CheckIfOwnsWorkspaceProperty(@AccountNumber int, @WorkspaceID INT)
RETURNS BIT
	AS BEGIN
		RETURN (SELECT CASE WHEN EXISTS
		(SELECT w.Workspace_ID, po.Property_ID, po.Account_Number
		FROM Property_Owner po, Workspace w
		WHERE w.Property_ID = po.Property_ID
		GROUP BY po.Account_Number, w.Workspace_ID, po.Property_ID
		HAVING Workspace_ID = @WorkspaceID and Account_Number = @AccountNumber)
		THEN CAST(1 as bit)
		ELSE CAST(0 as bit)
		END)
	END
GO


-- Function to check if the account owns the property. Returns 1 if true, 0 if false.
IF OBJECT_ID('CheckIfOwnsProperty') IS NOT NULL
DROP function CheckIfOwnsProperty
GO
CREATE function CheckIfOwnsProperty(@AccountNumber int, @PropertyID INT)
RETURNS BIT
	AS BEGIN
		RETURN (SELECT CASE WHEN EXISTS
		(SELECT po.Property_ID, po.Account_Number
		FROM Property_Owner po
		WHERE Property_ID = @PropertyID and Account_Number = @AccountNumber)
		THEN CAST(1 as bit)
		ELSE CAST(0 as bit)
		END)
	END
GO

-- Create Tables in Database.
-- USER
CREATE TABLE [User] (
  Email varchar(255) UNIQUE NOT NULL,
  First_Name varchar(50) NOT NULL,
  Last_Name varchar(50) NOT NULL,
  Phone varchar(50),
  Registration_Date smalldatetime NOT NULL,
  PRIMARY KEY (Email)
);
GO

-- ACCOUNT. Uses Email as FK.
CREATE TABLE Account (
  Account_Number int UNIQUE NOT NULL IDENTITY(1,1),
  Account_Type char(10) NOT NULL,
  CONSTRAINT [ac.check_type] CHECK (Account_Type IN ('Coworker', 'Owner')),
  Email varchar(255) UNIQUE NOT NULL,
  Is_Active bit DEFAULT 1 NOT NULL,
  [Password] varchar(255) NOT NULL,
  PRIMARY KEY (Account_Number),
  CONSTRAINT [FK_Account.Email]
  FOREIGN KEY (Email)
  REFERENCES [User](Email)
);
Go

-- PROPERTY. NO FK.
CREATE TABLE Property (
  Property_ID int UNIQUE NOT NULL IDENTITY(1,1) ,
  [Address] varchar(50) NOT NULL,
  Neighborhood varchar(50) NOT NULL,
  Square_Feet int,
  Has_Parking_Garage bit NOT NULL,
  Is_Reachable_By_Public_Transp bit NOT NULL,
  PRIMARY KEY (Property_ID)
);
GO

-- PROPERTY_OWNER. Associative entity. Uses Account_Number and Property_ID as FK.  Checks if the Account_Number is 'Owner'.
CREATE TABLE Property_Owner (
  Account_Number int NOT NULL,
  Property_ID int NOT NULL,
  CONSTRAINT [po.check_if_is_owner] CHECK (dbo.CheckIfIsOwner(Account_Number) = 1),
  PRIMARY KEY (Account_Number, Property_ID),
  CONSTRAINT [FK_Property_Owner.Account_Number]
  FOREIGN KEY (Account_Number)
  REFERENCES Account(Account_Number),
  CONSTRAINT [FK_Property_Owner.Property_ID]
  FOREIGN KEY (Property_ID)
  REFERENCES Property(Property_ID)
  ON DELETE CASCADE
);
GO

-- WORKSPACE. Uses Property_ID as FK.
CREATE TABLE Workspace (
  Workspace_ID int UNIQUE NOT NULL IDENTITY(1,1),
  Property_ID int NOT NULL,
  Seats int NOT NULL,
  Is_Smoking_Allowed bit NOT NULL,
  [Type] varchar(30) NOT NULL,
  CONSTRAINT [ws.check_type] CHECK ([Type] in ('Meeting Room', 'Private Office Room', 'Desk')),
  PRIMARY KEY (Workspace_ID),
  CONSTRAINT [FK_Workspace.Property_ID]
  FOREIGN KEY (Property_ID)
  REFERENCES Property(Property_ID)
  ON DELETE CASCADE
);
GO


-- LISTING. Uses Account_Number and Workspace_ID as FK. Checks if the Account_Number owns the property in question.
CREATE TABLE Listing (
  Listing_ID int UNIQUE NOT NULL IDENTITY (1,1),
  Account_Number int NOT NULL,
  Workspace_ID int NOT NULL,
  Lease_Term varchar(50) NOT NULL,
  Availability_Date varchar(50) NOT NULL,
  Price smallmoney NOT NULL,
  CONSTRAINT [li.check_if_owns_property] CHECK (dbo.CheckIfOwnsWorkspaceProperty(Account_Number, Workspace_ID) = 1),
  PRIMARY KEY (Listing_ID),
  CONSTRAINT [FK_Listing.Workspace_ID]
  FOREIGN KEY (Workspace_ID)
  REFERENCES Workspace(Workspace_ID)
  ON DELETE CASCADE,
  CONSTRAINT [FK_Listing.Account_Number]
  FOREIGN KEY (Account_Number)
  REFERENCES Account(Account_Number)
);
GO

-- BOOKING. Uses Account_Number and Listing_ID as FK.
CREATE TABLE Booking (
  Booking_ID int UNIQUE NOT NULL IDENTITY(1,1),
  Listing_ID int NOT NULL,
  Account_Number int NOT NULL,
  Payment_ID int NULL,
  Order_Date smalldatetime NOT NULL,
  Lease_Term_Quantity int NOT NULL,
  CONSTRAINT [bk.check_if_account_is_active] CHECK (dbo.CheckIfAccountIsActive(Account_Number) = 1),
  PRIMARY KEY (Booking_ID),
  CONSTRAINT [FK_Booking.Account_Number]
  FOREIGN KEY (Account_Number)
  REFERENCES Account(Account_Number),
  CONSTRAINT [FK_Booking.Listing_ID]
  FOREIGN KEY (Listing_ID)
  REFERENCES Listing(Listing_ID)
  ON DELETE CASCADE
);
GO

-- TRANSACTION. Uses Email as FK.
CREATE TABLE [Transaction] (
  Transaction_ID varchar(50) UNIQUE NOT NULL,
  Payment_ID int NOT NULL,
  Transaction_Amount smallmoney NOT NULL,
  Transaction_Type varchar(50),
  Transaction_Date smalldatetime NOT NULL,
  Email varchar(255) NOT NULL,
  CONSTRAINT [tr.check_type] CHECK (Transaction_Type IN ('Cash', 'Credit', 'Debit', 'Bank transfer', 'Interac', 'Cheque')),
  PRIMARY KEY (Transaction_ID),
  CONSTRAINT [FK_Transaction.Email]
  FOREIGN KEY (Email)
  REFERENCES [User](Email),
);
GO

-- PAYMENT. Uses Booking_ID as FK.
CREATE TABLE Payment (
  Payment_ID int UNIQUE NOT NULL IDENTITY(1001,1),
  Amount_Due smallmoney NOT NULL,
  Booking_ID int NOT NULL,
  PRIMARY KEY (Payment_ID),
  CONSTRAINT [FK_Payment.Booking_ID]
  FOREIGN KEY (Booking_ID)
  REFERENCES [Booking](Booking_ID)
  ON DELETE CASCADE
);
GO

-- SHARED_WORKSPACE. Uses Account_Number as FK. Checks if the Account_Number is Active.
CREATE TABLE Shared_Workspace (
  Account_Number int NOT NULL,
  Payment_ID int NOT NULL,
  CONSTRAINT [sw.check_if_account_is_active] CHECK (dbo.CheckIfAccountIsActive(Account_Number) = 1),
  PRIMARY KEY (Account_Number, Payment_ID),
  CONSTRAINT [FK_Shared_Workspace.Account_Number]
  FOREIGN KEY (Account_Number)
  REFERENCES Account(Account_Number),
  CONSTRAINT [FK_Shared_Workspace.Payment_ID]
  FOREIGN KEY (Payment_ID)
  REFERENCES Payment(Payment_ID)
  ON DELETE CASCADE
);
GO

-- ADD EXTRA FOREIGN KEY CONSTRAINTS (These required the other tables to be created first)
ALTER TABLE [Transaction]
ADD FOREIGN KEY (Payment_ID)
REFERENCES Payment(Payment_ID)
ON DELETE CASCADE
GO

ALTER TABLE [Booking]
ADD FOREIGN KEY (Payment_ID)
REFERENCES Payment(Payment_ID)
GO

-- Create function that allows us to perform calculations on the dates, given the listing.Lease_Term as @text.
IF OBJECT_ID('parseTextDateToInt') IS NOT NULL
DROP function parseTextDateToInt
GO
CREATE function parseTextDateToInt(@text varchar(8))
RETURNS INT
AS BEGIN
	RETURN 
		(CASE WHEN @text = 'week'
			THEN 7
		WHEN @text = 'day'
			THEN 1
		ELSE 30
		END)
	END
GO

-- TRIGGER to create a new payment once a booking is created, with that booking's total value. (Uses another support trigger [see below])
CREATE TRIGGER AssignPaymentToBooking ON dbo.Booking
FOR INSERT
AS
	DECLARE @LastBookingID as int
	SELECT @LastBookingID = Booking_ID FROM inserted

	INSERT INTO dbo.Payment	
	(Amount_Due, Booking_ID)
	SELECT
	l.Price*b.Lease_Term_Quantity, b.Booking_ID
	FROM Listing l, Booking b
	WHERE l.Listing_ID = b.Listing_ID and Booking_ID = (@LastBookingID)
	GROUP BY Booking_ID, l.Price*b.Lease_Term_Quantity;
GO  

-- Complimentary TRIGGER to assign that payment's Payment_ID to that booking.
CREATE TRIGGER UpdateBookingPaymentID ON dbo.Payment
FOR INSERT
AS
	UPDATE Booking
	SET Payment_ID = (SELECT Payment_ID FROM inserted)
	WHERE Booking_ID = (SELECT Booking_ID FROM inserted)
GO

--  TRIGGER to update payment's balance due
CREATE TRIGGER UpdateBalanceDue ON dbo.[Transaction]
FOR INSERT
AS
	UPDATE Payment
	SET Amount_Due = (Amount_Due - (SELECT Transaction_Amount FROM inserted))
	WHERE Payment_ID = (SELECT Payment_ID FROM inserted)
GO

-- Populating tables with examples:
USE TeamOfThree
GO

/****** Object:  Table User     ******/
-- Anna, Bob, Joe, Sophia and Arnold
DELETE FROM [User];
INSERT [User]
([Email], [First_Name], [Last_Name], [Phone], [Registration_Date]) 
VALUES 
('xxx@gmail.com', 'Anna', 'Anyhow', '(555)555-5555', CAST (GETDATE() as smalldatetime)),
('yyy@gmail.com', 'Bob', 'Somewhere', '(555)555-5556', CAST (GETDATE() as smalldatetime)),
('www@gmail.com', 'Joe', 'White', '(555)555-5557', CAST (GETDATE() as smalldatetime)),
('zzz@gmail.com', 'Sophia', 'Snow', '(555)555-5558', CAST (GETDATE() as smalldatetime)),
('aaa@gmail.com', 'Arnold', 'Schwarz', '(555)555-5559', CAST (GETDATE() as smalldatetime))
GO

/****** Object:  Table Account     ******/
-- Accounts for all our users. Sophia's account is inactive.
DELETE FROM [Account]
INSERT [Account] 
([Account_Type], [Email], [Is_Active], [Password])
VALUES 
('Owner', 'xxx@gmail.com', 'True', '1234567'),
('Owner', 'yyy@gmail.com', 'True', '1111111'),
('Coworker', 'www@gmail.com', 'True', 'abc1234'),
('Coworker', 'zzz@gmail.com', 'False', '#@123FsD'),
('Coworker', 'aaa@gmail.com', 'True', 'backtothechopa123')
GO

/****** Object:  Table Property     ******/
-- Four new properties.
DELETE FROM [Property]
INSERT [Property]
([Address], [Neighborhood], [Square_Feet], [Has_Parking_Garage], [Is_Reachable_By_Public_Transp])
VALUES 
('Street A', 'Beltline', '10000', 'TRUE', 'TRUE'),
('Street B', 'Beltline', '23000', 'TRUE', 'TRUE'),
('Street A', 'Beltline', '8000', 'FALSE', 'TRUE'),
('Street D', 'Beltline', '3400', 'TRUE', 'TRUE')
GO

/****** Object:  Table Property_Owner     ******/
-- Assign ownership over the last added properties. Property 1 is owned by users Anna and Bob.
DELETE FROM [Property_Owner]
INSERT [Property_Owner]
([Account_Number], [Property_ID])
VALUES 
('1', '1'),
('2', '1'),
('1', '2'),
('2', '3'),
('2', '4')
GO

/****** Object:  Table Workspace     ******/
-- Adds one workspace for each of our properties:
DELETE FROM [Workspace]
INSERT [Workspace]
([Property_ID], [Seats], [Is_Smoking_Allowed], [Type])
VALUES 
('1', '6', 'FALSE', 'Meeting Room'),
('2', '12', 'FALSE', 'Private Office Room'),
('3', '2', 'TRUE', 'Desk'),
('4', '8', 'FALSE', 'Meeting Room')
GO

/****** Object:  Table Listing     ******/
DELETE FROM [Listing]
INSERT [Listing]
([Account_Number], [Workspace_ID], [Lease_Term], [Availability_Date], [Price])
VALUES
('1',  '1', 'Day', Cast('2023-03-20' AS DATE), 100),
('1',  '2', 'Week', Cast('2023-03-20' AS DATE), 700),
('2',  '3', 'Month', Cast('2023-03-20' AS DATE), 1400),
('2',  '4', 'Week', Cast('2023-03-20' AS DATE), 600)
GO

/****** Object:  Table Booking     ******/
DELETE FROM [Booking]
INSERT [Booking]
([Listing_ID], [Account_Number], [Payment_ID], [Order_Date], [Lease_Term_Quantity])
VALUES
('2', '3', NULL, CAST('2023-02-28 11:50:00' AS smalldatetime), 1)
GO

INSERT [Booking]
([Listing_ID], [Account_Number], [Payment_ID], [Order_Date], [Lease_Term_Quantity])
VALUES
('1', '5', NULL, CAST('2023-02-23 14:20:00' AS smalldatetime), 2)
GO

/* THIS IS NO LONGER NECESSARY AS WHE ADDED THE TRIGGER TO BOOKING INSERT QUERY.

/****** Object:  Table Payment     ******/
DELETE FROM [Payment]
SET IDENTITY_INSERT [Payment] ON 
INSERT [Payment] 
([Payment_ID], [Amount_Due], [Booking_ID])
VALUES
('1001', '0', '1'),
('1002', '100', '2')
SET IDENTITY_INSERT [Payment] OFF 
GO*/

/****** Object:  Table Transaction     ******/
DELETE FROM [Transaction]
INSERT [Transaction] 
([Transaction_ID], [Payment_ID], [Transaction_Amount], [Transaction_Type], [Transaction_Date], [Email])
VALUES
('#C0000233', '1001', '700', 'Cash', CAST('2023-02-23 15:58:12' AS smalldatetime), 'www@gmail.com')
GO
INSERT [Transaction] 
([Transaction_ID], [Payment_ID], [Transaction_Amount], [Transaction_Type], [Transaction_Date], [Email])
VALUES
('#D0001121', '1002', '50', 'Debit', CAST('2023-02-28 12:59:12' AS smalldatetime), 'aaa@gmail.com')
GO
INSERT [Transaction] 
([Transaction_ID], [Payment_ID], [Transaction_Amount], [Transaction_Type], [Transaction_Date], [Email])
VALUES
('#C0000234', '1002', '50', 'Cash', CAST('2023-02-28 13:01:00' AS smalldatetime), 'aaa@gmail.com')
GO

/****** Object:  Table Shared_Workspace     ******/
DELETE FROM [Shared_Workspace]
INSERT [Shared_Workspace]
([Account_Number], [Payment_ID])
VALUES
('2', '1001'),
('2', '1002'),
('1', '1002')
GO

/* PHASE TWO: INSERTING MORE CONTENT INTO THE DATABASE */
USE TeamOfThree;

INSERT [Listing]
([Account_Number], [Workspace_ID], [Lease_Term], [Availability_Date], [Price])
VALUES
('1',  '1', 'Day', CAST(GETDATE() as DATE), 100),
('1',  '2', 'Week', CAST(GETDATE() as DATE), 700),
('2',  '3', 'Month', CAST(GETDATE() as DATE), 1400),
('2',  '4', 'Week', CAST(GETDATE() as DATE), 600)
GO

USE TeamOfThree;
GO
-- DML 1
-- Insert into User table
/*
This query inserts 15 new records into the User table.
The values for the Email, First_Name, Last_Name, and Phone columns are provided explicitly,
while the Registration_Date column gets the current date and time.
*/
INSERT INTO 
[User] ([Email],			[First_Name], [Last_Name], [Phone],		[Registration_Date])
VALUES 
('abc@gmail.com',			'Alice',	'Anderson', '(555)555-5555', CAST (GETDATE() as smalldatetime)),
('def@gmail.com',			'David',	'Doe',		'(555)555-5556', CAST (GETDATE() as smalldatetime)),
('ghi@gmail.com',			'Grace',	'Hudson',	'(555)555-5557', CAST (GETDATE() as smalldatetime)),
('jkl@gmail.com',			'John',		'Klein',	'(555)555-5558', CAST (GETDATE() as smalldatetime)),
('Willian@gmail.com',		'Willian',	'PeeeM',	'(555)555-5559', CAST (GETDATE() as smalldatetime)),
('Mohamed@gmail.com',		'Mohamed',	'ElllMee',	'(555)555-5560', CAST (GETDATE() as smalldatetime)),
('Raphael@gmail.com',		'Raphael',	'ScaaaaZ',	'(555)555-5561', CAST (GETDATE() as smalldatetime)),
('Rafael@gmail.com',		'Rafael',	'CoooonC',	'(555)555-5562', CAST (GETDATE() as smalldatetime)),
('Danielll123@gmail.com',	'Daniel',	'OluuuuG',	'(555)555-5563', CAST (GETDATE() as smalldatetime)),
('Amanda@gmail.com',		'Amanda',	'NaaaaaS',	'(555)555-5564', CAST (GETDATE() as smalldatetime)),
('Gabriel@gmail.com',		'Gabriel',	'ZaaaaC',	'(555)555-5565', CAST (GETDATE() as smalldatetime)),
('Emmanuel@gmail.com',		'Emmanuel', 'Paaaaag',	'(555)555-5566', CAST (GETDATE() as smalldatetime)),
('Dick@gmail.com',			'Dick',		'Faaaaab',	'(555)555-5567', CAST (GETDATE() as smalldatetime)),
('Nathaniel@gmail.com',		'Nathaniel', 'GaaaaaT',	'(555)555-5568', CAST (GETDATE() as smalldatetime)),
('Mahbub@gmail.com',		'Mahbub',	'Murrrrr',	'(555)555-5569', CAST (GETDATE() as smalldatetime));
GO

INSERT INTO 
[Account]
([Account_Type],	[Email],				[Password])
VALUES
('Coworker',	'Willian@gmail.com',		'D#193AA_$GPA4'),
('Owner',		'Mohamed@gmail.com',		'#B3ST_T3@TCH3R'),
('Coworker',	'Raphael@gmail.com',		'W1Th_c0v_id'),
('Coworker',	'Rafael@gmail.com',			'GL_newJOb'),
('Coworker',	'Danielll123@gmail.com',	'WhereTheFAmI'),
('Coworker',	'Amanda@gmail.com',			'Q23.14'),
('Coworker',	'Gabriel@gmail.com',		'Prv_Fg123'),
('Coworker',	'Emmanuel@gmail.com',		'Emnn111111@'),
('Coworker',	'Dick@gmail.com',			'SuperAwesome123'),
('Coworker',	'Nathaniel@gmail.com',		'ThisClassIsCool'),
('Owner',		'Mahbub@gmail.com',			'PyramidSusanHarper');
GO

INSERT INTO 
[Property]
([Address],			[Neighborhood], [Square_Feet], [Has_Parking_Garage], [Is_Reachable_By_Public_Transp])
VALUES 
('850 11 Street SW',	'Downtown',		'12000',	'FALSE',			'TRUE'),
('120 10 Street SW ',	'Downtown',		'10000',	'FALSE',			'TRUE'),
('555 5 Street SW ',	'Downtown',		'3000',		'FALSE',			'TRUE'),
('575 5 Street SW  ',	'Downtown',		'5555',		'TRUE',				'TRUE'),
('123 Street SE ',		'Mahogany',		'102000',	'TRUE',				'FALSE'),
('604 Street NW ',		'Rocky County', '120000',	'TRUE',				'FALSE'),
('Street D ',			'Beltline',		'10000',	'TRUE',				'TRUE'),
('12456 89 Street SW ', 'Far Away',		'120000',	'TRUE',				'TRUE'),
('1445 Street 1 ',		'Downtown',		'1000',		'FALSE',			'TRUE'),
('123 Street 2 ',		'Downtown',		'2000',		'FALSE',			'TRUE'),
('15 Street 3 ',		'Downtown',		'3000',		'FALSE',			'TRUE');
GO

INSERT INTO 
[Property_Owner]
([Account_Number], [Property_ID])
VALUES 
('7',	'5'),
('1',	'5'),
('16',	'6'),
('2',	'6'),
('7',	'7'),
('7',	'8'),
('7',	'9'),
('2',	'10'),
('2',	'11'),
('7',	'12'),
('16',	'13'),
('16',	'14'),
('16',	'15')
GO

INSERT INTO
[Workspace]
([Property_ID], [Seats], [Is_Smoking_Allowed], [Type])
VALUES 
--Property 5
('5', '6', 'FALSE', 'Meeting Room'),
('5', '2', 'FALSE', 'Private Office Room'),
('5', '2', 'FALSE', 'Private Office Room'),
('5', '4', 'FALSE', 'Desk'),
('5', '4', 'FALSE', 'Desk'),
--Property 6
('6', '12', 'FALSE', 'Meeting Room'),
('6', '2', 'FALSE', 'Private Office Room'),
('6', '2', 'FALSE', 'Private Office Room'),
('6', '4', 'FALSE', 'Desk'),
('6', '4', 'FALSE', 'Desk'),
('6', '4', 'FALSE', 'Desk'),
--Property 7
('7', '2', 'TRUE', 'Private Office Room'),
('7', '4', 'TRUE', 'Desk'),
--Property 8
('8', '2', 'FALSE', 'Private Office Room'),
('8', '4', 'FALSE', 'Desk'),
--Property 9
('9', '20', 'FALSE', 'Meeting Room'),
('9', '20', 'FALSE', 'Meeting Room'),
('9', '15', 'FALSE', 'Meeting Room'),
('9', '12', 'FALSE', 'Meeting Room'),
('9', '1', 'TRUE', 'Private Office Room'),
('9', '1', 'TRUE', 'Private Office Room'),
('9', '1', 'TRUE', 'Private Office Room'),
('9', '1', 'TRUE', 'Private Office Room'),
('9', '1', 'FALSE', 'Private Office Room'),
('9', '1', 'FALSE', 'Private Office Room'),
('9', '1', 'FALSE', 'Private Office Room'),
('9', '1', 'FALSE', 'Private Office Room'),
('9', '1', 'FALSE', 'Private Office Room'),
('9', '2', 'FALSE', 'Desk'),
('9', '2', 'FALSE', 'Desk'),
('9', '4', 'FALSE', 'Desk'),
('9', '4', 'FALSE', 'Desk'),
('9', '4', 'FALSE', 'Desk'),
--Property 10
('10', '18', 'FALSE', 'Meeting Room'),
('10', '18', 'FALSE', 'Meeting Room'),
('10', '12', 'FALSE', 'Meeting Room'),
('10', '10', 'FALSE', 'Meeting Room'),
('10', '2', 'TRUE', 'Private Office Room'),
('10', '2', 'TRUE', 'Private Office Room'),
('10', '2', 'TRUE', 'Private Office Room'),
('10', '1', 'TRUE', 'Private Office Room'),
('10', '2', 'FALSE', 'Private Office Room'),
('10', '2', 'FALSE', 'Private Office Room'),
('10', '1', 'FALSE', 'Private Office Room'),
('10', '1', 'FALSE', 'Private Office Room'),
('10', '1', 'FALSE', 'Private Office Room'),
('10', '4', 'FALSE', 'Desk'),
('10', '4', 'FALSE', 'Desk'),
('10', '3', 'FALSE', 'Desk'),
('10', '3', 'FALSE', 'Desk'),
('10', '3', 'FALSE', 'Desk'),
--Property 11
('11', '12', 'FALSE', 'Meeting Room'),
('11', '2', 'FALSE', 'Private Office Room'),
('11', '2', 'FALSE', 'Private Office Room'),
('11', '4', 'FALSE', 'Desk'),
('11', '4', 'FALSE', 'Desk'),
('11', '4', 'FALSE', 'Desk'),
--Property 12
('12', '20', 'FALSE', 'Meeting Room'),
('12', '20', 'FALSE', 'Meeting Room'),
('12', '15', 'FALSE', 'Meeting Room'),
('12', '12', 'FALSE', 'Meeting Room'),
('12', '1', 'TRUE', 'Private Office Room'),
('12', '1', 'TRUE', 'Private Office Room'),
('12', '1', 'TRUE', 'Private Office Room'),
('12', '1', 'TRUE', 'Private Office Room'),
('12', '1', 'FALSE', 'Private Office Room'),
('12', '1', 'FALSE', 'Private Office Room'),
('12', '1', 'FALSE', 'Private Office Room'),
('12', '1', 'FALSE', 'Private Office Room'),
('12', '1', 'FALSE', 'Private Office Room'),
('12', '2', 'FALSE', 'Desk'),
('12', '2', 'FALSE', 'Desk'),
('12', '4', 'FALSE', 'Desk'),
('12', '4', 'FALSE', 'Desk'),
('12', '4', 'FALSE', 'Desk'),
--Property 13
('13', '10', 'FALSE', 'Meeting Room'),
--Property 14
('14', '10', 'FALSE', 'Meeting Room'),
('14', '10', 'FALSE', 'Meeting Room'),
--Property 15
('15', '15', 'FALSE', 'Meeting Room'),
('15', '8', 'FALSE', 'Meeting Room'),
('15', '8', 'TRUE', 'Meeting Room')

INSERT INTO
[Listing]
([Account_Number], [Workspace_ID], [Lease_Term], [Availability_Date],		[Price])
VALUES
('1',				 '5',			'Day',		 Cast('2023-04-17' AS DATE), 200),
('1',				 '6',			'Day',		 Cast('2023-04-17' AS DATE), 60),
('1',				 '7',			'Day',		 Cast('2023-04-17' AS DATE), 60),
('1',				 '8',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('1',				 '9',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('2',				 '10',			'Day',		 Cast('2023-04-17' AS DATE), 300),
('2',				 '11',			'Month',	 Cast('2023-04-17' AS DATE), 1000),
('2',				 '12',			'Month',	 Cast('2023-04-17' AS DATE), 1000),
('2',				 '13',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('2',				 '14',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('2',				 '15',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('7',				 '16',			'Week',		 Cast('2023-04-17' AS DATE), 200),
('7',				 '17',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('7',				 '18',			'Week',		 Cast('2023-04-17' AS DATE), 200),
('7',				 '19',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('7',				 '20',			'Day',		 Cast('2023-04-17' AS DATE), 500),
('7',				 '21',			'Day',		 Cast('2023-04-17' AS DATE), 500),
('7',				 '22',			'Day',		 Cast('2023-04-17' AS DATE), 300),
('7',				 '23',			'Day',		 Cast('2023-04-17' AS DATE), 250),
('7',				 '24',			'Month',	 Cast('2023-04-17' AS DATE), 800),
('7',				 '25',			'Month',	 Cast('2023-04-17' AS DATE), 800),
('7',				 '26',			'Month',	 Cast('2023-04-17' AS DATE), 800),
('7',				 '27',			'Month',	 Cast('2023-04-17' AS DATE), 800),
('7',				 '28',			'Month',	 Cast('2023-04-17' AS DATE), 800),
('7',				 '29',			'Month',	 Cast('2023-04-17' AS DATE), 800),
('7',				 '30',			'Month',	 Cast('2023-04-17' AS DATE), 800),
('7',				 '31',			'Month',	 Cast('2023-04-17' AS DATE), 800),
('7',				 '32',			'Month',	 Cast('2023-04-17' AS DATE), 800),
('7',				 '33',			'Week',		 Cast('2023-04-17' AS DATE), 200),
('7',				 '34',			'Week',		 Cast('2023-04-17' AS DATE), 200),
('7',				 '35',			'Week',		 Cast('2023-04-17' AS DATE), 200),
('7',				 '36',			'Week',		 Cast('2023-04-17' AS DATE), 200),
('7',				 '37',			'Week',		 Cast('2023-04-17' AS DATE), 200),
('2',				 '38',			'Day',		 Cast('2023-04-17' AS DATE), 500),
('2',				 '39',			'Day',		 Cast('2023-04-17' AS DATE), 500),
('2',				 '40',			'Week',		 Cast('2023-04-17' AS DATE), 2000),
('2',				 '41',			'Day',		 Cast('2023-04-17' AS DATE), 200),
('2',				 '42',			'Week',		 Cast('2023-04-17' AS DATE), 250),
('2',				 '43',			'Week',		 Cast('2023-04-17' AS DATE), 250),
('2',				 '44',			'Week',		 Cast('2023-04-17' AS DATE), 250),
('2',				 '45',			'Week',		 Cast('2023-04-17' AS DATE), 200),
('2',				 '46',			'Week',		 Cast('2023-04-17' AS DATE), 250),
('2',				 '47',			'Week',		 Cast('2023-04-17' AS DATE), 250),
('2',				 '48',			'Week',		 Cast('2023-04-17' AS DATE), 250),
('2',				 '49',			'Week',		 Cast('2023-04-17' AS DATE), 250),
('2',				 '50',			'Week',		 Cast('2023-04-17' AS DATE), 250),
('2',				 '51',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('2',				 '52',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('2',				 '53',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('2',				 '54',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('2',				 '55',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('2',				 '56',			'Day',		 Cast('2023-04-17' AS DATE), 300),
('2',				 '57',			'Month',	 Cast('2023-04-17' AS DATE), 1000),
('2',				 '58',			'Month',	 Cast('2023-04-17' AS DATE), 1000),
('2',				 '59',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('2',				 '60',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('2',				 '61',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('7',				 '62',			'Day',		 Cast('2023-04-17' AS DATE), 1000),
('7',				 '63',			'Day',		 Cast('2023-04-17' AS DATE), 1000),
('7',				 '64',			'Day',		 Cast('2023-04-17' AS DATE), 600),
('7',				 '65',			'Day',		 Cast('2023-04-17' AS DATE), 500),
('7',				 '66',			'Month',	 Cast('2023-04-17' AS DATE), 750),
('7',				 '67',			'Month',	 Cast('2023-04-17' AS DATE), 750),
('7',				 '68',			'Month',	 Cast('2023-04-17' AS DATE), 750),
('7',				 '69',			'Month',	 Cast('2023-04-17' AS DATE), 750),
('7',				 '70',			'Month',	 Cast('2023-04-17' AS DATE), 750),
('7',				 '71',			'Month',	 Cast('2023-04-17' AS DATE), 750),
('7',				 '72',			'Month',	 Cast('2023-04-17' AS DATE), 750),
('7',				 '73',			'Month',	 Cast('2023-04-17' AS DATE), 750),
('7',				 '74',			'Month',	 Cast('2023-04-17' AS DATE), 750),
('7',				 '75',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('7',				 '76',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('7',				 '77',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('7',				 '78',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('7',				 '79',			'Day',		 Cast('2023-04-17' AS DATE), 100),
('16',				 '80',			'Day',		 Cast('2023-04-17' AS DATE), 200),
('16',				 '81',			'Day',		 Cast('2023-04-17' AS DATE), 200),
('16',				 '82',			'Day',		 Cast('2023-04-17' AS DATE), 200),
('16',				 '83',			'Day',		 Cast('2023-04-17' AS DATE), 200),
('16',				 '84',			'Day',		 Cast('2023-04-17' AS DATE), 200),
('16',				 '85',			'Day',		 Cast('2023-04-17' AS DATE), 200)
GO

-- Bookings have to be inserted one at a time due to our triggers
INSERT INTO
[Booking]
VALUES 
('10', '3', NULL, CAST(GETDATE() AS smalldatetime), 7)
GO
INSERT INTO
[Booking]
VALUES 
('15', '5', NULL, CAST(GETDATE() AS smalldatetime), 6)
GO
INSERT INTO
[Booking]
VALUES 
('21', '6', NULL, CAST(GETDATE() AS smalldatetime), 10)
GO
INSERT INTO
[Booking]
VALUES 
('22', '7', NULL, CAST(GETDATE() AS smalldatetime), 2)
GO
INSERT INTO
[Booking]
VALUES 
('36', '8', NULL, CAST(GETDATE() AS smalldatetime), 1)
GO
INSERT INTO
[Booking]
VALUES 
('37', '9', NULL, CAST(GETDATE() AS smalldatetime), 1)
GO
INSERT INTO
[Booking]
VALUES 
('38', '10', NULL, CAST(GETDATE() AS smalldatetime), 10)
GO
INSERT INTO
[Booking]
VALUES 
('39', '12', NULL, CAST(GETDATE() AS smalldatetime), 1)
GO
INSERT INTO
[Booking]
VALUES 
('47', '13', NULL, CAST(GETDATE() AS smalldatetime), 1)
GO
INSERT INTO
[Booking]
VALUES 
('44', '14', NULL, CAST(GETDATE() AS smalldatetime), 1)
GO
INSERT INTO
[Booking]
VALUES 
('45', '15', NULL, CAST(GETDATE() AS smalldatetime), 2)
GO

/* VIEWS */

-- Views

-- Display All Properties with Owners' Information
-- This view displays all properties along with their owners' first name, last name, and email.
IF OBJECT_ID('All_Properties_With_Owners') IS NOT NULL
DROP VIEW All_Properties_With_Owners
GO
CREATE VIEW All_Properties_With_Owners AS
SELECT p.Property_ID, [Address], Neighborhood, Square_Feet, Has_Parking_Garage, Is_Reachable_By_Public_Transp, Account.Account_Number, Account.Email
FROM Property p
INNER JOIN Property_Owner ON p.Property_ID = Property_Owner.Property_ID
INNER JOIN Account ON Property_Owner.Account_Number = Account.Account_Number
GO

-- Create a VIEW to display all bookings that haven't been fully paid for.
IF OBJECT_ID('Bookings_With_Balance_Due') IS NOT NULL
DROP VIEW [Bookings_With_Balance_Due]
GO
CREATE VIEW Bookings_With_Balance_Due AS
SELECT
	b.Booking_ID,
	u.First_Name + ' ' + u.Last_Name as 'Name',
	a.Email as 'Contact',
	p.Amount_Due as 'Balance Due',
	p.Payment_ID,
	w.Workspace_ID
FROM Booking b
	INNER JOIN Account a ON a.Account_Number = b.Account_Number
	INNER JOIN Payment p ON p.Payment_ID = b.Payment_ID
	INNER JOIN Listing l ON b.Listing_ID = l.Listing_ID
	INNER JOIN Workspace w ON w.Workspace_ID = l.Workspace_ID
	INNER JOIN [User] u ON a.Email = u.Email

WHERE p.Amount_Due > 0
GO

-- Create a View to display all bookings with contact information. Shows Start and End date.
IF OBJECT_ID('Bookings_Pay_Email_Date') IS NOT NULL
DROP VIEW [Bookings_Pay_Email_Date]
GO
CREATE VIEW Bookings_Pay_Email_Date AS
SELECT
	b.Booking_ID,
	a.Email,
	p.Payment_ID,
	w.Workspace_ID,
	CAST(b.Order_Date AS DATE) as 'Start Date',
	CAST(b.Order_Date + dbo.parseTextDateToInt(l.Lease_Term)*b.Lease_Term_Quantity AS DATE) as 'End Date'
FROM Booking b
	INNER JOIN Account a ON a.Account_Number = b.Account_Number
	INNER JOIN Payment p ON p.Payment_ID = b.Payment_ID
	INNER JOIN Listing l ON b.Listing_ID = l.Listing_ID
	INNER JOIN Workspace w ON w.Workspace_ID = l.Workspace_ID
GO

-- Create a View to display all active [Booking] with contact information and Property ID. Shows Start and End date.
IF OBJECT_ID('Bookings_Active') IS NOT NULL
DROP VIEW Bookings_Active
GO
CREATE VIEW Bookings_Active AS
SELECT
	b.Booking_ID,
	a.Email,
	p.Payment_ID,
	w.Workspace_ID,
	w.Property_ID,
	CAST(b.Order_Date AS DATE) as 'Start Date',
	CAST(b.Order_Date + dbo.parseTextDateToInt(l.Lease_Term)*b.Lease_Term_Quantity AS DATE) as 'End Date'
FROM Booking b
	INNER JOIN Account a ON a.Account_Number = b.Account_Number
	INNER JOIN Payment p ON p.Payment_ID = b.Payment_ID
	INNER JOIN Listing l ON b.Listing_ID = l.Listing_ID
	INNER JOIN Workspace w ON w.Workspace_ID = l.Workspace_ID
	WHERE b.Order_Date + dbo.parseTextDateToInt(l.Lease_Term)*b.Lease_Term_Quantity > GETDATE()
GO

-- Create a View to display all inactive [Booking] with contact information and Property ID. End date.
IF OBJECT_ID('Bookings_Not_Active') IS NOT NULL
DROP VIEW Bookings_Not_Active
GO
CREATE VIEW Bookings_Not_Active AS
SELECT
	b.Booking_ID,
	a.Email,
	p.Payment_ID,
	w.Workspace_ID,
	w.Property_ID,
	CAST(b.Order_Date + dbo.parseTextDateToInt(l.Lease_Term)*b.Lease_Term_Quantity AS DATE) as 'End Date'
FROM Booking b
	INNER JOIN Account a ON a.Account_Number = b.Account_Number
	INNER JOIN Payment p ON p.Payment_ID = b.Payment_ID
	INNER JOIN Listing l ON b.Listing_ID = l.Listing_ID
	INNER JOIN Workspace w ON w.Workspace_ID = l.Workspace_ID
	WHERE b.Order_Date + dbo.parseTextDateToInt(l.Lease_Term)*b.Lease_Term_Quantity < GETDATE()
GO

-- Create a View to display workspaces that generated the highest total revenue. Order by Total Revenue DESC.
IF OBJECT_ID('Woskpaces_Highest_Revenue') IS NOT NULL
DROP VIEW Woskpaces_Highest_Revenue
GO
CREATE VIEW Woskpaces_Highest_Revenue AS
SELECT TOP 100 PERCENT
	w.Workspace_ID,
	SUM(l.price*b.Lease_Term_Quantity - p.Amount_Due) as 'Total Revenue'
FROM Workspace w
	INNER JOIN Listing l ON w.Workspace_ID = l.Workspace_ID
	INNER JOIN Booking b ON b.Listing_ID = l.Listing_ID
	INNER JOIN Payment p ON p.Booking_ID = b.Booking_ID
	GROUP BY w.Workspace_ID
	ORDER BY 'Total Revenue' DESC
GO

-- Create a View to display users that don't have a registered account.
IF OBJECT_ID('Users_With_No_Account') IS NOT NULL
DROP VIEW Users_With_No_Account
GO
CREATE VIEW Users_With_No_Account AS
SELECT
	u.First_Name + ' ' + u.Last_Name as 'Full Name',
	u.Email,
	u.Phone
FROM [User] u WHERE NOT EXISTS (Select * FROM Account a WHERE u.Email = a.Email)
GO

-- Create a View to display all Owners
IF OBJECT_ID('Owners') IS NOT NULL
DROP VIEW Owners
GO
CREATE VIEW Owners AS
SELECT
	u.First_Name + ' ' + u.Last_Name as 'Full Name',
	u.Email,
	u.Phone,
	a.Account_Number
FROM [User] u INNER JOIN Account a ON u.Email = a.Email AND Account_Type = 'Owner'
GO

-- Create a View to display all Workspaces with Owners
IF OBJECT_ID('Workspaces_Owners') IS NOT NULL
DROP VIEW Workspaces_Owners
GO
CREATE VIEW Workspaces_Owners AS
SELECT
	w.Workspace_ID,
	u.First_Name + ' ' + u.Last_Name as 'Full Name',
	u.Email,
	u.Phone,
	a.Account_Number
FROM [User] u INNER JOIN Account a ON u.Email = a.Email AND Account_Type = 'Owner'
INNER JOIN Property_Owner po on a.Account_Number = po.Account_Number
INNER JOIN Property p on p.Property_ID = po.Property_ID
INNER JOIN Workspace w on w.Property_ID = p.Property_ID
GO


-- Create a View to display all Workspaces with Price Per Day Per Seat
IF OBJECT_ID('Workspaces_Price_Per_Seat') IS NOT NULL
DROP VIEW Workspaces_Price_Per_Seat
GO
CREATE VIEW Workspaces_Price_Per_Seat AS
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
GO