/******************
 * CORE OPERATION *
 ******************/

DROP FUNCTION ACQUIRE_TABLE(integer);
DROP FUNCTION ORDER_DRINK(integer, integer[]);

CREATE FUNCTION ACQUIRE_TABLE (integer) RETURNS integer AS $$
	DECLARE
		_t integer := (SELECT id FROM EMPLACEMENT WHERE id=$1);
		_taken integer := (SELECT id FROM CLIENT WHERE emplacement = $1);
	BEGIN
		-- Check that the emplacement exist
		IF _t IS NULL THEN
			RAISE EXCEPTION 'This table does not exist.';
		END IF;

		-- Check that the emplacement is free
		IF _taken IS NOT NULL THEN
			RAISE EXCEPTION 'This table is not free at the moment.';
		END IF;

	
		-- Create a new client
		INSERT INTO CLIENT VALUES
			(DEFAULT, $1);
		
		-- Return his token
		RETURN (SELECT id FROM CLIENT WHERE emplacement=$1);
	END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION ORDER_DRINK (integer, integer[][]) RETURNS integer AS $$
	DECLARE
		_c integer := (SELECT id FROM CLIENT WHERE id = $1);
		_t integer := (SELECT id FROM EMPLACEMENT WHERE id = (SELECT emplacement FROM CLIENT WHERE id = $1));
		
	BEGIN
		RETURN 0;
	END;
$$ LANGUAGE plpgsql;
	