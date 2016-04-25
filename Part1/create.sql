/**************
 * DATA MODEL *
 **************/

/* Represent the table */
CREATE TABLE EMPLACEMENT(
	id SERIAL PRIMARY KEY
);
/* Represent the client */
CREATE TABLE CLIENT(
	id SERIAL PRIMARY KEY
);
/* Represent the relation client_table */
CREATE TABLE CLIENT_EMPLACEMENT(
  client INT NOT NULL UNIQUE REFERENCES CLIENT(id),
  emplacement INT NOT NULL PRIMARY KEY REFERENCES EMPLACEMENT(id)
);
/* Represent the drink */
CREATE TABLE DRINK(
	id SERIAL PRIMARY KEY,
	price FLOAT NOT NULL,
	name TEXT NOT NULL,
	description TEXT NOT NULL
);
/* Represent the order */
CREATE TABLE ORDERS(
	id SERIAL PRIMARY KEY,
	time TIMESTAMP NOT NULL,
	client INT NOT NULL
);
/* Represent the ordered drink */
CREATE TABLE ORDERED_DRINK(
	qty INT NOT NULL,
	drink INT NOT NULL REFERENCES DRINK(id),
	orders INT NOT NULL REFERENCES ORDERS(id),
	PRIMARY KEY(drink,orders)
);
/* Represent the payment */
CREATE TABLE PAYMENT(
	id SERIAL PRIMARY KEY,
	amount FLOAT NOT NULL,
	client INT NOT NULL REFERENCES CLIENT(id)
);

/***********
 * TRIGGER *
 ***********/

/*
 * Check that the client id of the new orders exist
 */
CREATE OR REPLACE FUNCTION check_orders_creation() RETURNS trigger AS $check_orders_creation$
	BEGIN
		--Check that client exist
		IF (SELECT id FROM CLIENT WHERE id=NEW.client) IS NULL THEN
			RAISE EXCEPTION 'the given client does not exists';
		END IF;

		--Check that the client is on a table
		IF (SELECT client FROM CLIENT_EMPLACEMENT WHERE client=NEW.client) IS NULL THEN
			RAISE EXCEPTION 'the given client is not on a table';
		END IF;

		RETURN NEW;
	END;
$check_orders_creation$ LANGUAGE plpgsql;

-- Orders creation trigger
CREATE TRIGGER check_orders_creation
	BEFORE INSERT ON orders
	FOR EACH ROW
	EXECUTE PROCEDURE check_orders_creation();

/*
 * Check that the drink of the new ordered_drink exist
 */
CREATE OR REPLACE FUNCTION check_ordered_drink_creation() RETURNS trigger AS $check_ordered_drink_creation$
	BEGIN
		--Check that drink exist
		IF (SELECT id FROM DRINK WHERE id=NEW.drink) IS NULL THEN
			RAISE EXCEPTION 'the given drink does not exists';
		END IF;

		--Check that qty is positive
		IF (NEW.qty <= 0) THEN
			RAISE EXCEPTION 'you can not order a qty inferior or equal to 0';
		END IF;

		--Check that the order exist
		IF (SELECT id FROM ORDERS WHERE id=NEW.orders) IS NULL THEN
			RAISE EXCEPTION 'the given order does not exists';
		END IF;

		RETURN NEW;
	END;
$check_ordered_drink_creation$ LANGUAGE plpgsql;


-- Ordered Drink creation trigger
CREATE TRIGGER check_ordered_drink_creation
	BEFORE INSERT ON ordered_drink
	FOR EACH ROW
	EXECUTE PROCEDURE check_ordered_drink_creation();

/*
 * Check that the client exist
 * Delete the client that paid from the table client
 */
CREATE OR REPLACE FUNCTION free_table_on_insert_payment() RETURNS trigger AS $free_table_on_insert_payment$
	BEGIN
		--Check that the client exist
		IF (SELECT id FROM CLIENT WHERE id=NEW.client) IS NULL THEN
			RAISE EXCEPTION 'the given client does not exists';
		END IF;

		--Check that amount paid is greater or equal than amount due
		IF NEW.amount < (SELECT TOTAL_AMOUNT(NEW.client)) THEN
			RAISE EXCEPTION 'the amount paid is less than the amout due';
		END IF;

		--Free the table
		DELETE FROM CLIENT_EMPLACEMENT WHERE client=NEW.client;

		RETURN NEW;
		
	END;
$free_table_on_insert_payment$ LANGUAGE plpgsql;

-- Paymenet creation trigger
CREATE TRIGGER free_table_on_insert_payment
	BEFORE INSERT ON payment
	FOR EACH ROW
	EXECUTE PROCEDURE free_table_on_insert_payment();

/******************
 * CORE OPERATION *
 ******************/

/*
 * Function AcquireTable
 * DESC: invoked by the smartphone app when scanning a table code bar
 * IN: a table bar code
 * OUT: a client token
 * PRE: the table is free
 * POST: the table is no longer free
 * POST: issued token can be used for ordering drinks
 */
CREATE OR REPLACE FUNCTION ACQUIRE_TABLE (integer) RETURNS integer AS $$
	DECLARE
		client_id integer;
	BEGIN
		-- Check that table exist
		IF (SELECT id FROM EMPLACEMENT WHERE id=$1) IS NULL THEN
			RAISE EXCEPTION 'The given table does not exists';
		END IF;

		-- Check if the table is free
		IF (SELECT emplacement FROM CLIENT_EMPLACEMENT WHERE emplacement=$1) IS NOT NULL THEN
			RAISE EXCEPTION 'The given table is not free';
		END IF;

		-- Create a new client
		INSERT INTO CLIENT VALUES
			(DEFAULT) RETURNING id INTO client_id;

		-- Create a new relation client table
		INSERT INTO CLIENT_EMPLACEMENT VALUES
			(client_id,$1);
		
		-- Return his token
		RETURN client_id;
	END;
$$ LANGUAGE plpgsql;

/*
 * Function OrderDrinks
 * DESC: invoked when the user presses the “order” button in the ordering screen
 * IN: a client token
 * IN: a list of (drink, qty) taken from the screen form
 * OUT: the unique number of the created order
 * PRE: the client token is valid and corresponds to an occupied table
 * POST: the order is created, its number is the one returned
 */
CREATE OR REPLACE FUNCTION ORDER_DRINK (integer, integer[][]) RETURNS integer AS $$
	DECLARE
		x integer[];
		order_id integer;
	BEGIN
		--Create a new order
		INSERT INTO ORDERS VALUES
			(DEFAULT, localtimestamp, $1) returning id INTO order_id;

		--Create a new ordered drink for each drink
		FOREACH x SLICE 1 IN ARRAY $2
		LOOP
			INSERT INTO ORDERED_DRINK VALUES
				(x[2], x[1], order_id);
		END LOOP;

		
		RETURN order_id;
	END;
$$ LANGUAGE plpgsql;

/*
 * Function TotalAmount
 * DESC: utils function to get the total amount that a client needs to pay
 * IN: a client token
 * OUT: the total amount of all the drink of the table
 * PRE: the client token is valid and corresponds to an occupied table
 * POST: total amount correspond to all (and only) ordered drinks at that table
 */
 CREATE OR REPLACE FUNCTION TOTAL_AMOUNT (integer) RETURNS float AS $$
	DECLARE 
		total float;
 	BEGIN
		--Check that client exist
		IF (SELECT id FROM CLIENT WHERE id=$1) IS NULL THEN
			RAISE EXCEPTION 'the given client does not exists';
		END IF;
		
		--Get total amount
 		SELECT sum(price*T1.quantity) INTO total FROM 
			(SELECT SUM(qty) AS "quantity",drink FROM ORDERED_DRINK,ORDERS WHERE ORDERS.id=ORDERED_DRINK.orders AND ORDERS.client=$1 GROUP BY drink) AS T1, DRINK
			WHERE DRINK.id = T1.drink;

		--Return total amount
		RETURN COALESCE(total, 0.0);
 	END;
 $$ LANGUAGE plpgsql;

/*
 * Function IssueTicket
 * DESC: invoked when the user asks for looking at the table summary and due amount
 * IN: a client token
 * OUT: the ticket to be paid, with a summary of orders (which drinks in which quantities) and total amount to pay.
 * PRE: the client token is valid and corresponds to an occupied table
 * POST: issued ticket corresponds to all (and only) ordered drinks at that table
 */
 CREATE OR REPLACE FUNCTION ISSUE_TICKET (integer) RETURNS TABLE(name text, quantity bigint, price float, total float) AS $$
 	BEGIN
		--Check that client exist
		IF (SELECT id FROM CLIENT WHERE id=$1) IS NULL THEN
			RAISE EXCEPTION 'the given client does not exists';
		END IF;
		
		--Return the ticket
 		RETURN QUERY
 		SELECT DRINK.name,sum AS "quantity" ,DRINK.price AS "unit price",DRINK.price*sum AS "total price" FROM 
			(SELECT SUM(qty),drink FROM ORDERED_DRINK,ORDERS WHERE ORDERS.id=ORDERED_DRINK.orders AND ORDERS.client=$1 GROUP BY drink) AS T1, DRINK
			WHERE DRINK.id = T1.drink;
 	END;
 $$ LANGUAGE plpgsql;

 
/*
 * Function PayTable
 * DESC: invoked by the smartphone on confirmation from the payment gateway .
 * (we ignore security on purpose here; a real app would never expose such an API, of course).
 * IN: a client token
 * IN: an amount paid
 * OUT:
 * PRE: the client token is valid and corresponds to an occupied table
 * PRE: the input amount is greater or equal to the amount due for that table
 * POST: the table is released
 * POST: the client token can no longer be used for ordering
 */
CREATE OR REPLACE FUNCTION PAY_TABLE(integer,float) RETURNS void AS $$
	BEGIN
		-- Insert new payment
		INSERT INTO PAYMENT (amount, client) VALUES
			($2, $1);
	END;
$$ LANGUAGE plpgsql;