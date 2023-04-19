/*
@Author: Willian P. Munhoz, Rafael M. Conceição. 
@Course: DATA1201 - Introduction to relational databases
@Instructor: Mohamed Elmenshawy
@Date: April 18th, 2023
*/

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
CREATE function CheckIfOwnsWorkspaceProperty(@AccountNumber int, @WorkspaceID INT NULL)
RETURNS BIT
	AS BEGIN
		RETURN (SELECT CASE
			WHEN @WorkspaceID IS NULL THEN CAST(1 as bit)
			WHEN EXISTS
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
CREATE function CheckIfOwnsProperty(@AccountNumber int, @PropertyID INT NULL)
RETURNS BIT
	AS BEGIN
		RETURN (SELECT CASE 
			WHEN @PropertyID IS NULL THEN CAST(1 as bit)
			WHEN EXISTS
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
  Email							varchar(255)	PRIMARY KEY,
  First_Name					varchar(50)		NOT NULL,
  Last_Name						varchar(50)		NOT NULL,
  Phone							varchar(50),
  Registration_Date				smalldatetime	NOT NULL
);
GO

-- ACCOUNT. Uses Email as FK.
CREATE TABLE Account (
  Account_Number				int				PRIMARY KEY IDENTITY(1,1),
  Account_Type					char(10)		NOT NULL,
  Email							varchar(255)	FOREIGN KEY REFERENCES [User](Email),
  Is_Active						bit				DEFAULT 1 NOT NULL,
  [Password]					varchar(255)	NOT NULL,

  CONSTRAINT [ac.check_type] CHECK (Account_Type IN ('Coworker', 'Owner'))  
);
Go

-- PROPERTY. NO FK.
CREATE TABLE Property (
  Property_ID					int				PRIMARY KEY IDENTITY(1,1) ,
  [Address]						varchar(50)		NOT NULL,
  Neighborhood					varchar(50),			
  Square_Feet					int,
  Has_Parking_Garage			bit NOT NULL,
  Is_Reachable_By_Public_Transp bit NOT NULL,
);
GO

-- PROPERTY_OWNER. Associative entity. Uses Account_Number and Property_ID as FK.  Checks if the Account_Number is 'Owner'.
CREATE TABLE Property_Owner (
  Account_Number				int NOT NULL	FOREIGN KEY REFERENCES Account(Account_Number),
  Property_ID					int				FOREIGN KEY REFERENCES Property(Property_ID) ON DELETE CASCADE,
  PRIMARY KEY (Account_Number, Property_ID),

  -- constraint that checks if the account is in fact of the 'owner' type
  CONSTRAINT [po.check_if_is_owner] CHECK (dbo.CheckIfIsOwner(Account_Number) = 1)
);
GO

-- WORKSPACE. Uses Property_ID as FK.
CREATE TABLE Workspace (
  Workspace_ID					int				PRIMARY KEY	IDENTITY(1,1),
  Property_ID					int				NOT NULL FOREIGN KEY REFERENCES Property(Property_ID) ON DELETE CASCADE,
  Seats							int				NOT NULL,
  Is_Smoking_Allowed			bit				NOT NULL,
  [Type]						varchar(30)		NOT NULL,

  --constraint to check if the entered type is accepted: 
  CONSTRAINT [ws.check_type] CHECK ([Type] in ('Meeting Room', 'Private Office Room', 'Desk'))
);
GO


-- LISTING. Uses Account_Number and Workspace_ID as FK. Checks if the Account_Number owns the property in question.
CREATE TABLE Listing (
  Listing_ID					int				PRIMARY KEY IDENTITY (1,1),
  Account_Number				int				NOT NULL FOREIGN KEY REFERENCES Account(Account_Number),
  Workspace_ID					int				FOREIGN KEY REFERENCES Workspace(Workspace_ID) ON DELETE CASCADE,
  Lease_Term					varchar(50)		NOT NULL,
  Availability_Date				varchar(50)		NOT NULL,
  Price							smallmoney		NOT NULL,

  --constraint to check if the account is listed as an owner of the property where the workspace is.
  CONSTRAINT [li.check_if_owns_property] CHECK (dbo.CheckIfOwnsWorkspaceProperty(Account_Number, Workspace_ID) = 1),  
);
GO

-- BOOKING. Uses Account_Number and Listing_ID as FK.
CREATE TABLE Booking (
  Booking_ID					int				PRIMARY KEY IDENTITY(1,1),
  Listing_ID					int				NOT NULL FOREIGN KEY REFERENCES Listing(Listing_ID),
  Account_Number				int				NOT NULL FOREIGN KEY REFERENCES Account(Account_Number),
  Payment_ID					int				NULL,
  Order_Date					smalldatetime	NOT NULL,
  Lease_Term_Quantity			int				NOT NULL,

  --constraint to check if the account that is trying to perform a booking is active in the system
  CONSTRAINT [bk.check_if_account_is_active] CHECK (dbo.CheckIfAccountIsActive(Account_Number) = 1)
);
GO

-- TRANSACTION. Uses Email and Payment_ID as FK.
CREATE TABLE [Transaction] (
  Transaction_ID				varchar(50)		PRIMARY KEY,
  Payment_ID					int				NOT NULL, -- this FK will be added after we create the table [Payment]
  Transaction_Amount			smallmoney		NOT NULL,
  Transaction_Type				varchar(50),
  Transaction_Date				smalldatetime	NOT NULL,
  Email							varchar(255)	NOT NULL FOREIGN KEY REFERENCES [User](Email),

  --constraint to check if the transaction type is one of the following:
  CONSTRAINT [tr.check_type] CHECK (Transaction_Type IN ('Cash', 'Credit', 'Debit', 'Bank transfer', 'Interac', 'Cheque')),
);
GO

-- PAYMENT. Uses Booking_ID as FK.
CREATE TABLE Payment (
  Payment_ID					int				PRIMARY KEY IDENTITY(1001,1),
  Amount_Due					smallmoney		NOT NULL,
  Booking_ID					int				NOT NULL FOREIGN KEY REFERENCES [Booking](Booking_ID)
);
GO

-- SHARED_WORKSPACE. Uses Account_Number as FK. Checks if the Account_Number is Active.
CREATE TABLE Shared_Workspace (
  Account_Number				int				NOT NULL FOREIGN KEY REFERENCES Account(Account_Number),
  Payment_ID					int				NOT NULL FOREIGN KEY REFERENCES Payment(Payment_ID),
  PRIMARY KEY (Account_Number, Payment_ID),

  --constraint to check if the account that is being added to a shared workspace is active in the system
  CONSTRAINT [sw.check_if_account_is_active] CHECK (dbo.CheckIfAccountIsActive(Account_Number) = 1),
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
	--Price * Quantity
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