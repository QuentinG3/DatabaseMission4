/***************
 * DROP TABLES *
 ***************/

DROP TABLE PAYMENT;
DROP TABLE ORDERED_DRINK;
DROP TABLE ORDERS;
DROP TABLE DRINK;
DROP TABLE CLIENT;
DROP TABLE EMPLACEMENT;

/**************
 * DATA MODEL *
 **************/
 
/* Represent the table */
CREATE TABLE EMPLACEMENT(
	id SERIAL PRIMARY KEY
);
/* Represent the client */
CREATE TABLE CLIENT(
	id SERIAL PRIMARY KEY,
	emplacement INT NOT NULL UNIQUE REFERENCES EMPLACEMENT(id)
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
	client INT NOT NULL REFERENCES CLIENT(id)
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

/************
 * POPULATE *
 ************/
DELETE FROM DRINK;
DELETE FROM EMPLACEMENT;

INSERT INTO DRINK (price, name, description) VALUES
	(1.50, 'Water', 'A 25cl drink of still water'),
	(1.50, 'Sparkling Water', 'A 25cl drink of sparkling water'),
	(2.00, 'Lemonade', 'A 33cl drink of lemonade'),
	(2.50, 'Beer', 'A 50cl drink of white beer'),
	(3.00, 'Wine', 'A 20cl drink of red wine');

INSERT INTO EMPLACEMENT (id) VALUES
	(DEFAULT),
	(DEFAULT),
	(DEFAULT),
	(DEFAULT);