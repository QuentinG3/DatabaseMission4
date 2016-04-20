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