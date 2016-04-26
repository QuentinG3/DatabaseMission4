/****************
 * DROP TRIGGER *
 ****************/


DROP TRIGGER check_client_creation ON client;
DROP TRIGGER check_orders_creation ON orders;
DROP TRIGGER check_ordered_drink_creation ON ordered_drink;
DROP TRIGGER delete_client_on_insert_payment ON payment;