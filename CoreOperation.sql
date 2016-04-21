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
	BEGIN
		-- Create a new client
		INSERT INTO CLIENT VALUES
			(DEFAULT, $1);
		
		-- Return his token
		RETURN (SELECT id FROM CLIENT WHERE emplacement=$1);
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
			(DEFAULT, CURRENT_DATE, $1) returning id INTO order_id;

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
 * Function IssueTicket
 * DESC: invoked when the user asks for looking at the table summary and due amount
 * IN: a client token
 * OUT: the ticket to be paid, with a summary of orders (which drinks in which quantities) and total amount to pay.
 * PRE: the client token is valid and corresponds to an occupied table
 * POST: issued ticket corresponds to all (and only) ordered drinks at that table
 */
 CREATE OR REPLACE FUNCTION ISSUE_TICKET (c integer) RETURNS TABLE(name text, quantity bigint, price float, total float) AS $$
 	BEGIN
 		RETURN QUERY
 		SELECT DRINK.name,sum AS "quantity" ,DRINK.price AS "unit price",DRINK.price*sum AS "total price" FROM 
			(SELECT SUM(qty),drink FROM ORDERED_DRINK,ORDERS WHERE ORDERS.id=ORDERED_DRINK.orders AND ORDERS.client=c GROUP BY drink) AS T1, DRINK
			WHERE DRINK.id = T1.drink;
 	END;
 $$ LANGUAGE plpgsql;

 