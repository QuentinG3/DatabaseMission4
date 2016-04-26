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

 