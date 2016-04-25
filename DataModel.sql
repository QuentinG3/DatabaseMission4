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
  client INT NOT NULL REFERENCES CLIENT(id),
  emplacement INT NOT NULL REFERENCES EMPLACEMENT(id)
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
