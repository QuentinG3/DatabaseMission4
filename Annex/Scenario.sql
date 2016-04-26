/************
 * SCENARIO *
 ************/

 /*
  * SCENARIO : 
  * A client acquires a table; he orders a
  * sparkling water, look at the bill, then orders another sparkling water. The client then pays
  * and releases the table.
  */
CREATE OR REPLACE FUNCTION SCENARIO() RETURNS text AS $$
	DECLARE
		--The id of the table scanned
		free_table integer;
		--The id of the client
		client_id integer;
		--The id of the sparkling water
		sparkling_water integer;
		--The total amount due
		total float;
		--The success text
		success text = 'The scenario was a success ! ';
	BEGIN
		/*
		 * Step 1 : Acquire a table
		 */
		--Get the first free table id
		SELECT MIN(EMPLACEMENT.id) INTO free_table FROM EMPLACEMENT WHERE EMPLACEMENT.id NOT IN (SELECT emplacement FROM CLIENT_EMPLACEMENT);

		--Check if there is such a free emplacement
		IF free_table IS NULL THEN
			RAISE EXCEPTION 'there is no free emplacement';
		END IF;
		
		--Acquire table
		SELECT * INTO client_id FROM ACQUIRE_TABLE(free_table);

		/*
		 * Step 2 : Order a sparkling water
		 */
		--Get the id for the sparkling water
		SELECT id INTO sparkling_water FROM DRINK WHERE name='Sparkling Water';

		--Check if there is such an id
		IF sparkling_water IS NULL THEN
			RAISE EXCEPTION 'there is no Sparkling Water';
		END IF;
		
		--He orders a sparkling water
		PERFORM ORDER_DRINK(client_id,ARRAY[ARRAY[sparkling_water,1]]);

		/*
		 * Step 3 : Look at the bill
		 */
		--The client look at the bill
		PERFORM ISSUE_TICKET(client_id);

		/*
		 * Step 4 : Order a sparkling water
		 */
		--He orders a sparkling water
		PERFORM ORDER_DRINK(client_id,ARRAY[ARRAY[sparkling_water,1]]);

		/*
		 * Step 5 : Pays the bill
		 */
		--Get the total to pay
		SELECT * INTO total FROM TOTAL_AMOUNT(client_id);

		--Pay the total
		PERFORM PAY_TABLE(client_id,total);

		RETURN success;
		 

	END;
$$ LANGUAGE plpgsql;

--Launch scenario
SELECT SCENARIO();
