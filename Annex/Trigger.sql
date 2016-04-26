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

